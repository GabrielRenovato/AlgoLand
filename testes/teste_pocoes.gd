extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_pocoes.gd
# Pocoes e sementes na arena: o sorteio do drop de sementes (chance, estacao, chefe), os saquinhos na cena (pulo, ima,
# fim da onda), o cinto do HUD (Q/E trocam, R bebe), cada efeito no Jogador (forca, pedra, velocidade, folego, vampiro,
# cura), o tempo dos efeitos e a morte (os efeitos acabam, o estoque da fazenda fica).
# Usa arquivos de teste para Fazenda, Calendario e Progresso. ATENCAO: o reset da morte grava user://inventario.json
# (como o teste_morte): faça backup do user:// antes.

const CAMINHO_FAZENDA := "user://teste_pocoes_fazenda.json"
const CAMINHO_CALENDARIO := "user://teste_pocoes_calendario.json"
const CAMINHO_PROGRESSO := "user://teste_pocoes_progresso.json"

var _falhas: int = 0
var _f: Node
var _cal: Node
var _progresso: Node
var _cena: Node
var _jogador: Node
var _hud: Node
# Carregado depois do 1o quadro: semente_drop.gd usa autoloads (Fazenda) que ainda nao existem ao compilar o teste
var SementeDrop: GDScript

# Alvo de golpe: só anota o dano recebido
class Alvo extends Node2D:
	var esta_morto := false
	var danos: Array[int] = []
	func receber_dano(dano: int, _kb: Vector2 = Vector2.ZERO) -> void:
		danos.append(dano)

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _fisica(n: int) -> void:
	for i in n:
		await physics_frame

func _rodar() -> void:
	await process_frame
	_f = root.get_node("Fazenda")
	SementeDrop = load("res://Codigos/Logicas/semente_drop.gd")
	_cal = root.get_node("Calendario")
	_progresso = root.get_node("Progresso")
	_f.caminho_save = CAMINHO_FAZENDA
	_cal.caminho_save = CAMINHO_CALENDARIO
	_progresso.caminho_save = CAMINHO_PROGRESSO
	_f.apagar()
	_cal.apagar()
	_progresso.apagar()
	_cal.dia = 1
	var inventario = root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()

	_testar_sorteio()

	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.2).timeout
	_jogador = _cena.get_node("Jogador")
	_hud = get_nodes_in_group("hud")[0]
	_jogador.invulneravel = false

	await _testar_cinto()
	await _testar_efeitos()
	await _testar_saquinhos()
	await _testar_ligacao_no_spawner()
	await _testar_morte()

	_cena.queue_free()
	await _quadros(3)
	_f.apagar()
	_cal.apagar()
	_progresso.apagar()
	for caminho in [CAMINHO_FAZENDA, CAMINHO_CALENDARIO, CAMINHO_PROGRESSO]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("FALHAS: ", _falhas)
	quit(_falhas)

# --- Sorteio do drop (sem cena) ------------------------------------------------------------------------------

func _testar_sorteio() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# raridades: as plantas das melhores pocoes (forca e vampirica) sao raras/epicas; as das outras, comuns/incomuns
	var pocoes: GDScript = load("res://Codigos/DadosLocais/pocoes.gd")
	var ordem_rar := {"comum": 0, "incomum": 1, "raro": 2, "epico": 3}
	var melhor_das_boas := 0
	var pior_das_melhores := 3
	for id in pocoes.ORDEM:
		for planta in pocoes.POCOES[id]["receita"]:
			var r: int = ordem_rar[SementeDrop.raridade(planta)]
			if id in ["forca", "vampiro"]:
				pior_das_melhores = mini(pior_das_melhores, r)
			else:
				melhor_das_boas = maxi(melhor_das_boas, r)
	_verificar("forca e vampirica so com sementes raras/epicas; as outras pocoes com comuns/incomuns", pior_das_melhores >= 2 and melhor_das_boas <= 1, "%d %d" % [pior_das_melhores, melhor_das_boas])
	_verificar("toda planta tem raridade valida", _f.PLANTAS.keys().all(func(id): return String(_f.PLANTAS[id].get("raridade", "")) in ordem_rar), "")
	# mob normal: cada semente com a sua chance (muito raro), sorteadas separadamente
	var n := 100000
	var contagem := {}
	var com_drop := 0
	var mais_de_um := 0
	for i in n:
		var a: Array = SementeDrop.sortear(1, false, false, rng)   # verao: girassol comum, milho incomum, tomate raro, melancia epica
		com_drop += 1 if not a.is_empty() else 0
		mais_de_um += 1 if a.size() > 1 else 0
		for id in a:
			contagem[id] = int(contagem.get(id, 0)) + 1
	var taxa := func(id: String) -> float: return float(contagem.get(id, 0)) / n
	_verificar("mob normal: comum ~1% por abate (girassol)", absf(taxa.call("girassol") - 0.01) < 0.0015, "%.4f" % taxa.call("girassol"))
	_verificar("mob normal: incomum ~0,4% (milho)", absf(taxa.call("milho") - 0.004) < 0.001, "%.4f" % taxa.call("milho"))
	_verificar("mob normal: raro ~0,12% (tomate)", absf(taxa.call("tomate") - 0.0012) < 0.0005, "%.4f" % taxa.call("tomate"))
	_verificar("mob normal: epico ~0,04% (melancia), bem mais raro que o raro", taxa.call("melancia") < 0.0008 and taxa.call("melancia") < taxa.call("tomate") / 1.5, "%.5f" % taxa.call("melancia"))
	_verificar("mob normal: quase sempre nada (mais de 98% dos abates sem semente)", float(com_drop) / n < 0.02, "%.4f" % (float(com_drop) / n))
	_verificar("so sementes de verao no verao", contagem.keys().all(func(id): return int(_f.PLANTAS[id]["estacao"]) == 1), str(contagem))
	# mutante: x3
	var cenouras := 0
	for i in 40000:
		cenouras += SementeDrop.sortear(0, true, false, rng).count("cenoura")
	_verificar("mutante: chance x3 (cenoura ~3%)", absf(float(cenouras) / 40000.0 - 0.03) < 0.005, "%.4f" % (float(cenouras) / 40000.0))
	# chefe: sempre pelo menos 2; comuns mais que épicas
	var minimo := 99
	var total_chefe := {}
	for i in 4000:
		var a: Array = SementeDrop.sortear(2, false, true, rng)
		minimo = mini(minimo, a.size())
		for id in a:
			total_chefe[id] = int(total_chefe.get(id, 0)) + 1
	_verificar("chefe: sempre solta pelo menos 2 sementes", minimo >= SementeDrop.QTD_GARANTIDA_CHEFE, "minimo=%d" % minimo)
	_verificar("chefe: a comum cai mais que a epica (beterraba > berinjela), mas a epica cai", int(total_chefe.get("beterraba", 0)) > 4 * int(total_chefe.get("berinjela", 0))
			and int(total_chefe.get("berinjela", 0)) > 0, str(total_chefe))
	var estacoes_ok := true
	for i in 200:
		# inverno não tem plantio: cai semente de primavera para guardar
		estacoes_ok = estacoes_ok and int(_f.PLANTAS[SementeDrop.sortear_planta(3, rng)]["estacao"]) == 0
		estacoes_ok = estacoes_ok and int(_f.PLANTAS[SementeDrop.sortear_planta(2, rng)]["estacao"]) == 2
	_verificar("inverno da semente de primavera; outono, do outono", estacoes_ok, "")
	# quem conta como chefe: o slime comum NAO (o bug antigo fazia todo inimigo soltar 3); o golem e o tornar_chefe SIM
	var slime: Node = load("res://cenas/inimigos/slime.tscn").instantiate()
	var golem: Node = load("res://cenas/inimigos/golem.tscn").instantiate()
	_verificar("slime comum nao e chefe para o drop", not SementeDrop.eh_chefe(slime), "")
	_verificar("o golem e chefe (nasce chefe)", SementeDrop.eh_chefe(golem), "")
	slime.set("eh_chefe", true)
	_verificar("inimigo que virou chefe (tornar_chefe) conta como chefe", SementeDrop.eh_chefe(slime), "")
	slime.free()
	golem.free()

# --- Cinto ----------------------------------------------------------------------------------------------------

func _testar_cinto() -> void:
	var efeitos: Node = _jogador.efeitos_pocao
	_verificar("o jogador tem o no de efeitos e o HUD da arena tem o cinto", efeitos != null and _hud.cinto_pocoes != null and _hud.cinto_pocoes.efeitos == efeitos, "")
	var cinto: Control = _hud.cinto_pocoes
	_verificar("sem pocoes: o cinto fica escondido", not cinto._linha_cinto.visible and efeitos.selecionada == "", "")
	_f.pocoes = {"cura": 1, "forca": 2, "vampiro": 1}
	_f.bolsas_alteradas.emit()
	await _quadros(1)
	_verificar("com pocoes: escolhe a primeira do cinto e mostra icone e quantidade", efeitos.selecionada == "cura" and cinto._linha_cinto.visible
			and cinto._icone.texture != null and cinto._quantidade.text == "1", "%s %s" % [efeitos.selecionada, cinto._quantidade.text])
	_verificar("tecla de beber no teclado: R", cinto._tecla_beber.text == "R BEBER" and cinto._tecla_anterior.text == "Q", cinto._tecla_beber.text)
	var controle := root.get_node("Controle")
	controle._definir(true)
	_verificar("no controle: X bebe, LB/RB trocam", cinto._tecla_beber.text == "X BEBER" and cinto._tecla_anterior.text == "LB" and cinto._tecla_proxima.text == "RB", "")
	controle._definir(false)
	# troca pelas ações de verdade (E/Q), passando pelo _unhandled_input do jogador
	_verificar("na arena o cinto esta ativo (fora do modo fazenda)", _jogador._cinto_de_pocoes_ativo(), "")
	_acao("ferramenta_proxima")
	await _quadros(1)
	_verificar("E: proxima pocao (forca)", efeitos.selecionada == "forca" and cinto._quantidade.text == "2" and cinto._nome.text == "POCAO DE FORCA", "%s %s" % [efeitos.selecionada, cinto._nome.text])
	_acao("ferramenta_proxima")
	_acao("ferramenta_proxima")
	await _quadros(1)
	_verificar("E duas vezes: da a volta (vampiro -> cura)", efeitos.selecionada == "cura", efeitos.selecionada)
	_acao("ferramenta_anterior")
	await _quadros(1)
	_verificar("Q: anterior da a volta para tras (vampiro)", efeitos.selecionada == "vampiro", efeitos.selecionada)
	efeitos.trocar(-1)
	_verificar("Q de novo: forca", efeitos.selecionada == "forca", efeitos.selecionada)

func _acao(nome: String) -> void:
	var evento := InputEventAction.new()
	evento.action = nome
	evento.pressed = true
	root.push_input(evento)
	var solta := InputEventAction.new()
	solta.action = nome
	solta.pressed = false
	root.push_input(solta)

# --- Efeitos --------------------------------------------------------------------------------------------------

func _testar_efeitos() -> void:
	var efeitos: Node = _jogador.efeitos_pocao
	var cinto: Control = _hud.cinto_pocoes
	var est = _jogador.estatisticas
	est.chance_critico = 0.0
	# Dano base alto: com o 5 do kit inicial o arredondamento de cada golpe esconde os 30%
	est.dano_ataque = 100
	# força: dano médio x1,3
	var alvo := Alvo.new()
	_cena.add_child(alvo)
	var sem := _media_dano(alvo, 120)
	_acao("usar_pocao")   # R: bebe a escolhida (forca)
	await _quadros(1)
	_verificar("R bebe a pocao escolhida: gasta 1 e liga o efeito por 30 s", _f.quantidade_pocoes("forca") == 1 and efeitos.esta_ativo("forca")
			and is_equal_approx(efeitos.bonus("forca"), 0.3) and efeitos.restante("forca") > 29.0, "%s" % efeitos.ativos)
	_verificar("o cinto mostra o efeito ativo com o tempo", cinto._linha_efeitos.visible and cinto._rotulos_efeitos.has("forca")
			and int(cinto._rotulos_efeitos["forca"]["tempo"].text) in [29, 30], str(cinto._rotulos_efeitos.keys()))
	_verificar("o nome e o efeito aparecem ao beber", cinto._nome.text == "POCAO DE FORCA: +30% DE DANO (30S)", cinto._nome.text)
	var com := _media_dano(alvo, 120)
	_verificar("forca: dano medio x1,3", absf(com / sem - 1.3) < 0.06, "%.2f / %.2f = %.3f" % [com, sem, com / sem])
	_verificar("logo em seguida: ESPERE (sem gastar outra)", _jogador.usar_pocao() == efeitos.MSG_ESPERE and _f.quantidade_pocoes("forca") == 1, "")
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.1).timeout
	efeitos.ativos["forca"]["restante"] = 3.0
	_verificar("beber de novo renova o tempo (nao soma o efeito)", efeitos.beber("forca") == "" and efeitos.restante("forca") > 29.0
			and is_equal_approx(efeitos.bonus("forca"), 0.3) and _f.quantidade_pocoes("forca") == 0, "")
	_verificar("acabou a forca: o cinto passa para a proxima que tem", efeitos.selecionada == "cura", efeitos.selecionada)
	# efeito acaba sozinho
	efeitos.ativos["forca"]["restante"] = 0.05
	await create_timer(0.15).timeout
	_verificar("o efeito acaba no tempo e some do cinto", not efeitos.esta_ativo("forca") and efeitos.bonus("forca") == 0.0
			and not cinto._rotulos_efeitos.has("forca") and not cinto._linha_efeitos.visible, "")
	# cura: com a vida cheia não gasta; ferido cura 40%
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	_verificar("cura com a vida cheia: VIDA CHEIA e nao gasta", _jogador.usar_pocao() == efeitos.MSG_VIDA_CHEIA and _f.quantidade_pocoes("cura") == 1
			and cinto._aviso.text == efeitos.MSG_VIDA_CHEIA, cinto._aviso.text)
	_jogador.hp_atual = 10
	_verificar("cura ferido: +40% da vida maxima na hora", _jogador.usar_pocao() == "" and _jogador.hp_atual == 10 + roundi(_jogador.estatisticas.hp_maximo * 0.4)
			and not efeitos.esta_ativo("cura") and _f.quantidade_pocoes("cura") == 0, "hp=%d" % _jogador.hp_atual)
	# pedra: -25% de dano recebido (somado à defesa)
	_f.pocoes = {"pedra": 1, "velocidade": 1, "folego": 1, "vampiro": 1}
	_f.bolsas_alteradas.emit()
	var reducao: float = est.reducao_dano()
	_jogador.hp_atual = 900
	_jogador.estatisticas.hp_maximo = 1000
	_jogador.invulneravel = false
	_jogador.receber_dano(100)
	var sem_pedra: int = 900 - _jogador.hp_atual
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	efeitos.beber("pedra")
	_jogador.invulneravel = false
	var antes: int = _jogador.hp_atual
	_jogador.receber_dano(100)
	var com_pedra: int = antes - _jogador.hp_atual
	_verificar("pedra: o dano recebido cai 25 pontos de reducao", sem_pedra == roundi(100 * (1.0 - reducao)) and com_pedra == roundi(100 * (1.0 - minf(reducao + 0.25, _jogador.REDUCAO_MAXIMA_COM_POCAO))),
			"sem=%d com=%d reducao=%.2f" % [sem_pedra, com_pedra, reducao])
	_jogador.invulneravel = true
	_jogador.temporizador_invul = 9999.0
	# fôlego: sem a espera e 3x mais rápido
	_jogador.stamina = 0.0
	_jogador._espera_regeneracao = 1.0
	_jogador._regenerar_stamina(0.1)
	var sem_folego: float = _jogador.stamina
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	efeitos.beber("folego")
	_jogador.stamina = 0.0
	_jogador._espera_regeneracao = 1.0
	_jogador._regenerar_stamina(0.1)
	_verificar("folego: regenera mesmo na espera, 3x mais rapido", sem_folego == 0.0 and is_equal_approx(_jogador.stamina, _jogador.regeneracao_stamina * 3.0 * 0.1), "%.2f" % _jogador.stamina)
	# vampiro: o golpe cura
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	efeitos.beber("vampiro")
	_jogador.hp_atual = 50
	alvo.danos.clear()
	_jogador.aplicar_golpe(alvo, Vector2.RIGHT)
	var esperado := 50 + maxi(1, roundi(alvo.danos[0] * 0.12)) + (maxi(1, roundi(alvo.danos[0] * minf(est.roubo_vida, est.ROUBO_VIDA_MAXIMO) / 100.0)) if est.roubo_vida > 0 else 0)
	_verificar("vampiro: 12% do dano do golpe volta como vida", _jogador.hp_atual == esperado, "hp=%d esperado=%d dano=%d" % [_jogador.hp_atual, esperado, alvo.danos[0]])
	# velocidade: andando para a direita
	var v_sem := await _velocidade_andando()
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	efeitos.beber("velocidade")
	var v_com := await _velocidade_andando()
	_verificar("velocidade: anda 25% mais rapido", absf(v_com / v_sem - 1.25) < 0.03, "%.1f / %.1f" % [v_com, v_sem])
	_verificar("varios efeitos ao mesmo tempo no cinto", cinto._rotulos_efeitos.size() == 4, str(cinto._rotulos_efeitos.keys()))
	_verificar("sem pocoes: o cinto some, os efeitos continuam", not cinto._linha_cinto.visible and cinto._linha_efeitos.visible and efeitos.selecionada == "", "")
	_verificar("sem pocoes: R avisa SEM POCOES", _jogador.usar_pocao() == efeitos.MSG_SEM_POCAO, "")
	alvo.queue_free()

func _media_dano(alvo: Alvo, golpes: int) -> float:
	alvo.danos.clear()
	for i in golpes:
		_jogador.aplicar_golpe(alvo, Vector2.RIGHT)
	var soma := 0
	for d in alvo.danos:
		soma += d
	return float(soma) / maxf(alvo.danos.size(), 1.0)

func _velocidade_andando() -> float:
	_jogador.global_position = Vector2(300, 170)
	Input.action_press("move_right")
	await _fisica(20)
	var v: float = absf(_jogador.velocity.x)
	Input.action_release("move_right")
	await _fisica(20)
	return v

# --- Saquinhos de semente --------------------------------------------------------------------------------------

func _testar_saquinhos() -> void:
	_f.sementes = {}
	_cal.dia = 1
	# um "chefe" de mentira: eh_chefe vem por propriedade
	var falso := NoComChefe.new()
	_cena.add_child(falso)
	falso.global_position = _jogador.global_position + Vector2(120, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var criados: Array = SementeDrop.soltar_de(falso, _cena, rng)
	await _quadros(2)
	var qtd := criados.size()
	_verificar("chefe solta os saquinhos na cena (pelo menos 2, no grupo semente_drop)", qtd >= 2 and get_nodes_in_group("semente_drop").size() == qtd, "%d" % qtd)
	await create_timer(SementeDrop.DURACAO_PULO + 0.1).timeout
	var espalhados := true
	for d in criados:
		espalhados = espalhados and is_instance_valid(d) and (d as Node2D).global_position.distance_to(falso.global_position) >= 9.0
	_verificar("os saquinhos pulam e se espalham em volta", espalhados, "")
	_verificar("longe do jogador: ficam no chao", _f.sementes.is_empty() and get_nodes_in_group("semente_drop").size() == qtd, str(_f.sementes))
	# o jogador chega perto: o ímã puxa e recolhe
	_jogador.global_position = falso.global_position - Vector2(0, 11)
	await create_timer(0.8).timeout
	var total := 0
	for id in _f.sementes:
		total += int(_f.sementes[id])
	_verificar("perto: o ima puxa e todas as sementes vao para a fazenda", total == qtd and get_nodes_in_group("semente_drop").is_empty(), str(_f.sementes))
	_verificar("o cinto avisa a semente recolhida", _hud.cinto_pocoes._aviso_semente.text.begins_with("+") and "SEMENTE:" in _hud.cinto_pocoes._aviso_semente.text, _hud.cinto_pocoes._aviso_semente.text)
	# fim da onda: os que ficaram voam até o jogador, de qualquer distância
	var longe: Node2D = SementeDrop.new()
	longe.semente = "batata"
	_cena.add_child(longe)
	longe.global_position = _jogador.global_position + Vector2(250, 60)
	await create_timer(SementeDrop.DURACAO_PULO + 0.2).timeout
	_verificar("saquinho longe nao se mexe sozinho", is_instance_valid(longe) and not longe._atraido, "")
	call_group("semente_drop", "atrair")
	await create_timer(2.0).timeout
	_verificar("atrair (fim da onda): voa ate o jogador e e recolhido", not is_instance_valid(longe) and _f.quantidade_sementes("batata") >= 1, str(_f.sementes))
	# raridade: o saquinho raro/epico brilha na cor da raridade; o aviso diz a raridade
	var epico: Node2D = SementeDrop.new()
	epico.semente = "melancia"
	var comum: Node2D = SementeDrop.new()
	comum.semente = "girassol"
	_cena.add_child(epico)
	_cena.add_child(comum)
	epico.global_position = _jogador.global_position + Vector2(300, 0)
	comum.global_position = _jogador.global_position + Vector2(-300, 0)
	await _quadros(2)
	_verificar("semente epica brilha no chao (roxo); a comum nao", epico._brilho != null and comum._brilho == null
			and Color(epico._brilho.modulate, 1.0) == Color(_f.COR_RARIDADE["epico"], 1.0), "")
	epico.queue_free()
	comum.queue_free()
	_hud.avisar_semente("tomate")
	var aviso: Label = _hud.cinto_pocoes._aviso_semente
	_verificar("aviso de semente rara: '(RARA)' na cor azul", aviso.text == "+1 SEMENTE: TOMATE (RARA)" and aviso.get_theme_color("font_color") == _f.COR_RARIDADE["raro"], aviso.text)
	falso.queue_free()

class NoComChefe extends Node2D:
	var eh_chefe := true
	var eh_mutante := false

func _testar_ligacao_no_spawner() -> void:
	var spawner: Node = _cena.get_node("enemySpawner")
	var gerenciador: Node = _cena.get_node("enemySpawner/GerenciadorOndas")
	var ponto: Marker2D = null
	for filho in spawner.find_children("*", "Marker2D", true, false):
		ponto = filho
		break
	if ponto == null:
		_verificar("spawner tem pontos de spawn", false, "")
		return
	var antes := get_nodes_in_group("enemy").size()
	await spawner.spawnar_inimigo_em(ponto, 1.0, 1.0)
	var inimigos := get_nodes_in_group("enemy")
	_verificar("spawner criou um inimigo", inimigos.size() == antes + 1, "")
	if inimigos.size() <= antes:
		return
	var inimigo: Node = inimigos[inimigos.size() - 1]
	var conexoes: Array = inimigo.get_signal_connection_list("inimigo_morreu")
	var i_semente := -1
	var i_gerenciador := -1
	for i in conexoes.size():
		var c: Callable = conexoes[i]["callable"]
		if c.get_method() == "_soltar_sementes":
			i_semente = i
		elif c.get_object() == gerenciador:
			i_gerenciador = i
	_verificar("a morte do inimigo solta sementes, antes de o gerenciador fechar a onda", i_semente >= 0 and i_gerenciador > i_semente, "%d %d" % [i_semente, i_gerenciador])
	inimigo.queue_free()
	await _quadros(2)

# --- Morte ----------------------------------------------------------------------------------------------------

func _testar_morte() -> void:
	var efeitos: Node = _jogador.efeitos_pocao
	_f.pocoes = {"forca": 2, "cura": 1}
	_f.sementes = {"tomate": 4}
	_f.colheita = {"uva": 3}
	_f.bolsas_alteradas.emit()
	await create_timer(efeitos.ESPERA_ENTRE_GOLES + 0.05).timeout
	efeitos.beber("forca")
	_verificar("antes de morrer: forca ativa", efeitos.esta_ativo("forca"), "")
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	_jogador.hp_atual = 1
	_jogador.receber_dano(9999)
	await _quadros(3)
	_verificar("morrer acaba com os efeitos", _jogador.estaMorto and efeitos.ativos.is_empty(), "")
	_verificar("morto: o cinto nao funciona", not _jogador._cinto_de_pocoes_ativo(), "")
	_jogador.reiniciar_para_nova_partida()
	root.get_node("EventosJogo").fechar_tela.emit("fim_partida")
	await _quadros(3)
	_verificar("reset roguelite: pocoes, sementes e colheita da fazenda ficam", _f.pocoes == {"forca": 1, "cura": 1} and _f.sementes == {"tomate": 4} and _f.colheita == {"uva": 3},
			"%s %s %s" % [_f.pocoes, _f.sementes, _f.colheita])
