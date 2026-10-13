extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_eventos_chefes.gd
# Cobre os eventos de onda (sorteio, modificadores, ouro, neblina) e os chefes em rodízio
# (tornar_chefe, habilidades, lacaios fora da contagem da onda, onda de chefe de ponta a ponta).
# ATENCAO: abre a cena de jogo; faça backup do user:// antes (o Progresso grava num arquivo de teste e é apagado ao final)

const CAMINHO_PROGRESSO := "user://teste_eventos_chefes_progresso.json"
const PONTO_ABERTO_INVESTIDA := Vector2(300, 170)
const HabilidadeChefe := preload("res://Codigos/Inimigos/habilidade_chefe.gd")
const CoroaMutante := preload("res://Codigos/Efeitos/coroa_mutante.gd")
const IndicadorAtaqueScript := preload("res://Codigos/Efeitos/indicador_ataque.gd")

# Carregado em _rodar: o script do gerenciador depende dos autoloads, que só existem depois do primeiro quadro
var Gerenciador: GDScript
var _falhas: int = 0
var _cena: Node
var _jogador: Node
var _progresso: Node
var _gerenciador: Node
var _spawner: Node
var _dados_jogo: Node
var _hud: Node
var _luz: Node

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

# As habilidades andam pelo tempo da física (60 por segundo): para medir segundos, conta ticks
func _fisica(segundos: float) -> void:
	for i in int(segundos * 60.0):
		await physics_frame

func _curar() -> void:
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo

func _evento(id: String) -> Dictionary:
	for e in Gerenciador.EVENTOS:
		if e["id"] == id:
			return e
	return {}

func _rodar() -> void:
	# O _ready dos autoloads (Progresso.carregar) roda no primeiro quadro; espera para não sobrescrever o que o teste define
	await process_frame
	Gerenciador = load("res://Codigos/Logicas/Gerenciador-de-ondas.gd")
	_progresso = root.get_node("Progresso")
	_progresso.caminho_save = CAMINHO_PROGRESSO
	# O clima do mundo fica no autoload Fazenda (as ondas o mudam): arquivo de teste, sem o save real
	var fazenda_isolada = root.get_node("Fazenda")
	fazenda_isolada.caminho_save = "user://teste_eventos_chefes_fazenda.json"
	fazenda_isolada.apagar()
	_progresso.melhorias = {}
	_dados_jogo = root.get_node("DadosJogo")

	_testar_sorteio_puro()

	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.3).timeout
	_jogador = _cena.get_node("Jogador")
	_gerenciador = _cena.get_node("enemySpawner/GerenciadorOndas")
	_spawner = _cena.get_node("enemySpawner")
	_hud = get_first_node_in_group("hud")
	_luz = _cena.get_node("Iluminacao")
	_gerenciador.chance_onda_bonus = 0.0

	await _testar_modificadores()
	await _testar_ouro_do_evento()
	await _testar_neblina_e_hud()
	_testar_rodizio()
	await _testar_tornar_chefe()
	await _testar_rei_slime()
	await _testar_caranguejo()
	await _testar_cogumelo()
	await _testar_parar_ondas()
	await _testar_ondas_de_evento()
	await _testar_ondas_de_chefe()

	if FileAccess.file_exists(CAMINHO_PROGRESSO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	print("FALHAS: ", _falhas)
	if FileAccess.file_exists("user://teste_eventos_chefes_fazenda.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_eventos_chefes_fazenda.json"))
	quit(_falhas)

# -----------------------------------------------------------------
# Sorteio (função pura)
# -----------------------------------------------------------------
func _testar_sorteio_puro() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_verificar("6 eventos na tabela", Gerenciador.EVENTOS.size() == 6, str(Gerenciador.EVENTOS.size()))
	var nomes: Array = Gerenciador.EVENTOS.map(func(e): return e["nome"])
	_verificar("nomes dos eventos", nomes == ["LUA DE SANGUE", "CHUVA DE OURO", "HORDA", "ELITE", "NEBLINA", "TEMPESTADE"], str(nomes))

	var antes := 0
	var em_chefe := 0
	var em_bonus := 0
	for i in 2000:
		for onda in [1, 2, 3]:
			if not Gerenciador.sortear_evento(onda, false, false, "", rng, 1.0).is_empty():
				antes += 1
		if not Gerenciador.sortear_evento(10 + i, true, false, "", rng, 1.0).is_empty():
			em_chefe += 1
		if not Gerenciador.sortear_evento(5 + i, false, true, "", rng, 1.0).is_empty():
			em_bonus += 1
	_verificar("nunca antes da onda 4 (mesmo com chance 100%)", antes == 0, "antes=%d" % antes)
	_verificar("nunca em onda de chefe", em_chefe == 0, "chefe=%d" % em_chefe)
	_verificar("nunca em onda bonus", em_bonus == 0, "bonus=%d" % em_bonus)
	_verificar("onda 4 ja pode ter evento", not Gerenciador.sortear_evento(4, false, false, "", rng, 1.0).is_empty(), "")

	# Frequência com a chance padrão (25%) numa amostra grande
	var amostras := 40000
	var com_evento := 0
	var por_id := {}
	for i in amostras:
		var e: Dictionary = Gerenciador.sortear_evento(7, false, false, "", rng)
		if not e.is_empty():
			com_evento += 1
			por_id[e["id"]] = por_id.get(e["id"], 0) + 1
	var freq := float(com_evento) / amostras
	_verificar("frequencia ~25%% (%.3f)" % freq, absf(freq - 0.25) < 0.015, "freq=%f" % freq)
	var todos_aparecem := por_id.size() == 6
	var parelho := true
	for id in por_id:
		if absf(float(por_id[id]) / com_evento - 1.0 / 6.0) > 0.03:
			parelho = false
	_verificar("os 6 eventos aparecem de forma parelha", todos_aparecem and parelho, str(por_id))

	# Nunca repete o evento da onda anterior (encadeando os sorteios como o gerenciador faz)
	var anterior := ""
	var repeticoes := 0
	var seguidos := 0
	for i in 20000:
		var e: Dictionary = Gerenciador.sortear_evento(8, false, false, anterior, rng, 1.0)
		if e["id"] == anterior:
			repeticoes += 1
		seguidos += 1
		anterior = e["id"]
	_verificar("nao repete o mesmo evento duas ondas seguidas (%d ondas)" % seguidos, repeticoes == 0, "repeticoes=%d" % repeticoes)
	anterior = ""
	repeticoes = 0
	var consecutivos := 0
	for i in 40000:
		var e: Dictionary = Gerenciador.sortear_evento(8, false, false, anterior, rng)
		if not e.is_empty() and e["id"] == anterior:
			repeticoes += 1
		if not e.is_empty() and anterior != "":
			consecutivos += 1
		anterior = e.get("id", "")
	_verificar("com chance 25%% tambem nao repete (%d pares seguidos vistos)" % consecutivos, repeticoes == 0 and consecutivos > 100, "repeticoes=%d pares=%d" % [repeticoes, consecutivos])

	# Tabela de efeitos
	var lua := _evento("lua_sangue")
	_verificar("lua de sangue: +25%% velocidade e dano, ouro x1,5", lua["velocidade"] == 1.25 and lua["dano"] == 1.25 and lua["ouro"] == 1.5, str(lua))
	_verificar("chuva de ouro: so ouro x2", _evento("chuva_ouro")["ouro"] == 2.0 and not _evento("chuva_ouro").has("vida"), "")
	var horda := _evento("horda")
	_verificar("horda: +60%% inimigos, -35%% vida", horda["qtde"] == 1.6 and is_equal_approx(horda["vida"], 0.65) and not horda.has("ouro"), str(horda))
	_verificar("elite: mutante x3, ouro x1,25", _evento("elite")["mutante"] == 3.0 and _evento("elite")["ouro"] == 1.25, "")
	_verificar("neblina: escurece a tela, ouro x1,3", _evento("neblina")["ouro"] == 1.3 and _evento("neblina").has("tom"), "")

# -----------------------------------------------------------------
# Modificadores lidos pelo spawner e pelo gerenciador
# -----------------------------------------------------------------
func _novo_slime() -> Node:
	return load("res://cenas/inimigos/slime.tscn").instantiate()

func _testar_modificadores() -> void:
	_gerenciador.onda_atual = 5
	var base := _novo_slime()
	var vida_base: int = base.vida
	var dano_base: float = base.dano
	var vel_base: int = base.velocidade
	base.free()

	_gerenciador.evento_atual = {}
	var s0 := _novo_slime()
	_spawner.aplicar_atributos(s0, 2.0, 1.5)
	var vel_sem: int = s0.velocidade
	_verificar("sem evento: vida e dano so pelos multiplicadores da onda", s0.vida == roundi(vida_base * 2.0) and is_equal_approx(s0.dano, dano_base * 1.5), "vida=%d dano=%f" % [s0.vida, s0.dano])
	s0.free()

	_gerenciador.evento_atual = _evento("lua_sangue")
	var s1 := _novo_slime()
	_spawner.aplicar_atributos(s1, 2.0, 1.5)
	_verificar("lua de sangue: dano +25%%", is_equal_approx(s1.dano, dano_base * 1.5 * 1.25), "dano=%f" % s1.dano)
	_verificar("lua de sangue: velocidade +25%%", s1.velocidade == roundi(vel_sem * 1.25) and s1.velocidade > vel_sem, "vel=%d base=%d" % [s1.velocidade, vel_sem])
	_verificar("lua de sangue: vida inalterada", s1.vida == roundi(vida_base * 2.0), "vida=%d" % s1.vida)
	s1.free()

	_gerenciador.evento_atual = _evento("horda")
	var s2 := _novo_slime()
	_spawner.aplicar_atributos(s2, 2.0, 1.5)
	_verificar("horda: vida -35%%", s2.vida == roundi(vida_base * 2.0 * 0.65), "vida=%d esperado=%d" % [s2.vida, roundi(vida_base * 2.0 * 0.65)])
	s2.free()
	_verificar("horda: +60%% inimigos na onda 4 (10 -> 16)", _gerenciador.quantidade_inimigos_onda(4) == 16, "qtde=%d" % _gerenciador.quantidade_inimigos_onda(4))
	_verificar("horda respeita MAX_INIMIGOS_POR_ONDA", _gerenciador.quantidade_inimigos_onda(30) == _gerenciador.MAX_INIMIGOS_POR_ONDA and _gerenciador.quantidade_inimigos_onda(11) == roundi(24 * 1.6), "q30=%d q11=%d" % [_gerenciador.quantidade_inimigos_onda(30), _gerenciador.quantidade_inimigos_onda(11)])
	_gerenciador.evento_atual = {}
	_verificar("sem evento a quantidade e a de sempre", _gerenciador.quantidade_inimigos_onda(4) == 10 and _gerenciador.quantidade_inimigos_onda(30) == 60, "")

	# Elite: chance x3, valendo também antes da onda 6
	_verificar("sem elite nao ha mutante antes da onda 6", _spawner.chance_mutante(4, 1.0) == 0.0 and _spawner.chance_mutante(5, 1.0) == 0.0, "")
	_verificar("chance de mutante normal na onda 6 e 10", is_equal_approx(_spawner.chance_mutante(6, 1.0), 0.05) and is_equal_approx(_spawner.chance_mutante(10, 1.0), 0.05 + 0.015 * 4), "")
	_verificar("elite triplica a chance", is_equal_approx(_spawner.chance_mutante(10, 3.0), 3.0 * (0.05 + 0.015 * 4)) and is_equal_approx(_spawner.chance_mutante(6, 3.0), 0.15), "c10=%f c6=%f" % [_spawner.chance_mutante(10, 3.0), _spawner.chance_mutante(6, 3.0)])
	_verificar("elite vale tambem na onda 4", is_equal_approx(_spawner.chance_mutante(4, 3.0), 0.15), "")
	_verificar("elite tem teto", _spawner.chance_mutante(60, 3.0) <= _spawner.CHANCE_MUTANTE_MAXIMA_ELITE + 0.0001, "")
	_gerenciador.evento_atual = _evento("elite")
	_gerenciador.onda_atual = 8
	var mutantes := 0
	for i in 4000:
		if _spawner._deve_ser_mutante(8):
			mutantes += 1
	var chance_esperada: float = _spawner.chance_mutante(8, 3.0)
	_verificar("_deve_ser_mutante usa o evento (%.3f esperado)" % chance_esperada, absf(float(mutantes) / 4000.0 - chance_esperada) < 0.03, "mutantes=%d/4000" % mutantes)
	_gerenciador.evento_atual = {}
	_gerenciador.onda_atual = 1

func _testar_ouro_do_evento() -> void:
	_gerenciador.onda_atual = 4
	_gerenciador.onda_bonus = false
	# onda 4: 3 + 4/4 = 4 moedas por abate; recompensa final 25 + 13*4 = 77 (ver ouro_fim_onda)
	var casos := [["", 1.0], ["lua_sangue", 1.5], ["chuva_ouro", 2.0], ["horda", 1.0], ["elite", 1.25], ["neblina", 1.3]]
	for caso in casos:
		_gerenciador.evento_atual = _evento(caso[0]) if caso[0] != "" else {}
		_gerenciador._resto_saque = 0.0
		_dados_jogo.moedas = 0
		_gerenciador.inimigos_vivos = 50
		_gerenciador.inimigo_morreu()
		var esperado_abate := int(4 * caso[1])
		_verificar("ouro por abate com %s (x%s)" % [caso[0] if caso[0] != "" else "sem evento", caso[1]], _dados_jogo.moedas == esperado_abate, "moedas=%d esperado=%d" % [_dados_jogo.moedas, esperado_abate])
		# Recompensa final: o último inimigo da onda
		_gerenciador.evento_atual = _evento(caso[0]) if caso[0] != "" else {}
		_gerenciador._resto_saque = 0.0
		_dados_jogo.moedas = 0
		_gerenciador.inimigos_vivos = 1
		_gerenciador.onda_atual = 4
		_gerenciador.inimigo_morreu()
		var esperado_final := int(4 * caso[1]) + roundi(_gerenciador.ouro_fim_onda(4) * caso[1])
		_verificar("recompensa final com %s" % (caso[0] if caso[0] != "" else "sem evento"), _dados_jogo.moedas == esperado_final, "moedas=%d esperado=%d" % [_dados_jogo.moedas, esperado_final])
		_verificar("evento limpo ao fim da onda", _gerenciador.evento_atual.is_empty() and not _gerenciador.onda_em_andamento, "")
		_gerenciador.onda_atual = 4
	# Com o saque: o multiplicador do evento entra antes do bônus de Brasas/saque
	_progresso.melhorias = {"saque": 5}
	_gerenciador.evento_atual = _evento("chuva_ouro")
	_gerenciador._resto_saque = 0.0
	_dados_jogo.moedas = 0
	_gerenciador.inimigos_vivos = 50
	_gerenciador.inimigo_morreu()
	_verificar("saque nivel 5 + chuva de ouro: 4 x 2 x 1,5 = 12", _dados_jogo.moedas == 12, "moedas=%d" % _dados_jogo.moedas)
	_progresso.melhorias = {}
	_gerenciador.evento_atual = {}
	_gerenciador.inimigos_vivos = 0
	_gerenciador.onda_atual = 1
	_gerenciador._resto_saque = 0.0
	_dados_jogo.moedas = 0

# -----------------------------------------------------------------
# Neblina (CanvasModulate) e HUD
# -----------------------------------------------------------------
func _testar_neblina_e_hud() -> void:
	var modulador: CanvasModulate = _luz.get_node("CanvasModulate")
	_luz.set_process(false)
	_luz.tom_estacao = Color(1.0, 0.95, 0.9)
	_luz.tom_evento = Color.WHITE
	_luz._aplicar()
	var cor_normal: Color = modulador.color
	var neblina := _evento("neblina")
	_gerenciador._definir_evento(neblina)
	await create_timer(1.8).timeout
	_luz._aplicar()
	_verificar("neblina escurece a tela", modulador.color.get_luminance() < cor_normal.get_luminance() - 0.05, "%s vs %s" % [modulador.color, cor_normal])
	_verificar("neblina multiplica por cima do tom da estacao e do ciclo", modulador.color.is_equal_approx(cor_normal * neblina["tom"]) and _luz.tom_estacao == Color(1.0, 0.95, 0.9), "%s" % modulador.color)
	_verificar("HUD mostra o indicador do evento", _hud.rotulo_evento.visible and _hud.rotulo_evento.text == "NEBLINA", "visivel=%s" % _hud.rotulo_evento.visible)
	_gerenciador._encerrar_evento()
	await create_timer(1.8).timeout
	_luz._aplicar()
	_verificar("fim do evento restaura a tela", modulador.color.is_equal_approx(cor_normal) and _luz.tom_estacao == Color(1.0, 0.95, 0.9), "%s vs %s" % [modulador.color, cor_normal])
	_verificar("indicador some ao fim do evento", not _hud.rotulo_evento.visible, "")
	# parar_ondas também restaura
	_gerenciador._definir_evento(neblina)
	await create_timer(0.2).timeout
	_gerenciador.parar_ondas()
	await create_timer(1.8).timeout
	_luz._aplicar()
	# parar_ondas também volta a estação para a primavera: compara com o ciclo atual vezes o tom da estação, sem o evento
	var cor_ciclo: Color = _luz._gradiente.sample(_luz.hora / 24.0)
	_verificar("parar_ondas restaura a neblina e limpa o evento", modulador.color.is_equal_approx(cor_ciclo * _luz.tom_estacao) and _luz.tom_evento.is_equal_approx(Color.WHITE) and _gerenciador.evento_atual.is_empty(), "%s tom_evento=%s" % [modulador.color, _luz.tom_evento])
	_luz.tom_estacao = Color.WHITE
	_luz.set_process(true)
	_gerenciador.ondas_paradas = false

# -----------------------------------------------------------------
# Rodízio de chefes
# -----------------------------------------------------------------
func _testar_rodizio() -> void:
	var esperado := {10: "minotauro", 20: "rei_slime", 30: "caranguejo", 40: "cogumelo", 50: "dragao_vermelho", 60: "minotauro", 70: "rei_slime", 80: "caranguejo", 90: "cogumelo", 100: "dragao_vermelho"}
	var ok := true
	var detalhe := ""
	for onda in esperado:
		var id: String = _gerenciador.chefe_da_onda(onda)["id"]
		if id != esperado[onda]:
			ok = false
			detalhe += " onda %d=%s" % [onda, id]
	_verificar("rodizio 10 minotauro, 20 rei slime, 30 caranguejo, 40 cogumelo, 50 dragao...", ok, detalhe)
	var nomes: Array = _gerenciador.CHEFES.map(func(c): return c["nome"])
	_verificar("nomes dos chefes", nomes == ["MINOTAURO", "REI SLIME", "CARANGUEJO COLOSSAL", "COGUMELO ANCIAO", "DRAGAO VERMELHO"], str(nomes))
	_verificar("chefe fica mais forte a cada ciclo (multiplicador por onda)", _gerenciador.mult_vida_onda(50) > _gerenciador.mult_vida_onda(10) and _gerenciador.mult_dano_onda(60) > _gerenciador.mult_dano_onda(20), "")

# -----------------------------------------------------------------
# tornar_chefe
# -----------------------------------------------------------------
func _chefe_manual(cena: String, nome: String, escala: float, mult_vida: float, habilidade: String, onde: Vector2) -> Node:
	var inimigo: Node = load(cena).instantiate()
	inimigo.tornar_chefe(nome, escala, mult_vida, 1.4, habilidade)
	inimigo.position = onde
	_cena.add_child(inimigo)
	return inimigo

func _limpar_inimigos() -> void:
	for inimigo in get_nodes_in_group("enemy"):
		if is_instance_valid(inimigo):
			inimigo.free()

func _testar_tornar_chefe() -> void:
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	_progresso.iniciar_partida()
	var base := _novo_slime()
	var vida_base: int = base.vida
	var dano_base: float = base.dano
	var pes_base: float = base.altura_pes
	base.free()
	var longe: Vector2 = _jogador.global_position + Vector2(90, 0)
	var chefe: Node = _chefe_manual("res://cenas/inimigos/slime.tscn", "REI SLIME", 2.8, 11.0, "", longe)
	await _quadros(3)
	_verificar("vida multiplicada", chefe.vida == vida_base * 11 and chefe.vida_maxima == vida_base * 11, "vida=%d max=%d" % [chefe.vida, chefe.vida_maxima])
	_verificar("dano multiplicado", is_equal_approx(chefe.dano, dano_base * 1.4), "")
	_verificar("escala visual e da colisao", chefe.scale.is_equal_approx(Vector2(2.8, 2.8)), str(chefe.scale))
	_verificar("altura dos pes acompanha a escala (ordem de desenho)", is_equal_approx(chefe.altura_pes, pes_base * 2.8), "pes=%f" % chefe.altura_pes)
	var coroa: Node = chefe.get_node_or_null("CoroaMutante")
	_verificar("coroa dourada", coroa != null and coroa.paleta == CoroaMutante.PALETA_DOURADA and coroa.paleta["c"].r > 0.9 and coroa.paleta["c"].b < 0.3, "")
	_verificar("coroa nao fica gigante nem minuscula na tela", coroa != null and absf(coroa.scale.x * chefe.scale.x - 1.4) < 0.01, "")
	_verificar("sem barra de vida pequena", not chefe.has_node("HPBar") and not chefe.usar_barra_vida, "")
	_verificar("barra de chefe do HUD aparece com o nome", _hud.painel_chefe.visible and _hud.nome_chefe.text == "REI SLIME", "visivel=%s nome=%s" % [_hud.painel_chefe.visible, _hud.nome_chefe.text])
	chefe.tornar_mutante()
	_verificar("chefe nao vira mutante", not chefe.eh_mutante and chefe.scale.is_equal_approx(Vector2(2.8, 2.8)) and chefe.get_children().filter(func(c): return c.name.begins_with("CoroaMutante")).size() == 1, "")
	# Mutante comum continua com a coroa cinza
	var mutante := _novo_slime()
	mutante.tornar_mutante()
	_cena.add_child(mutante)
	var coroa_m: Node = mutante.get_node("CoroaMutante")
	_verificar("mutante continua com coroa cinza e escala 1,55", coroa_m.paleta == CoroaMutante.PALETA_CINZA and mutante.scale.is_equal_approx(Vector2(1.55, 1.55)) and is_equal_approx(coroa_m.scale.x, 1.0), "")
	mutante.free()

	# Dano atualiza a barra do HUD; knockback é quase nulo
	var vida_antes: int = chefe.vida
	chefe.receber_dano(vida_base * 2, Vector2(300, 0))
	await _quadros(2)
	_verificar("dano reduz a vida e a barra do HUD", chefe.vida == vida_antes - vida_base * 2 and is_equal_approx(_hud.barra_chefe._fracao, float(chefe.vida) / chefe.vida_maxima), "vida=%d barra=%f" % [chefe.vida, _hud.barra_chefe._fracao])
	_verificar("resistencia a knockback", chefe.velocity.length() <= 300.0 * 0.08 + 1.0, "vel=%f" % chefe.velocity.length())
	chefe.receber_dano_efeito(vida_base, Color.ORANGE)
	_verificar("dano de efeito tambem atualiza a barra", is_equal_approx(_hud.barra_chefe._fracao, float(chefe.vida) / chefe.vida_maxima), "")

	# Morte: ouro, Brasas/progresso, HUD
	var chefes_antes: int = _progresso.chefes
	_gerenciador.onda_atual = 20
	_dados_jogo.moedas = 0
	var ouro_antes: int = _dados_jogo.moedas
	var recompensa: int = chefe.recompensa_chefe
	chefe.receber_dano(999999)
	await create_timer(0.5).timeout
	_verificar("recompensa de ouro do chefe", _dados_jogo.moedas - ouro_antes == recompensa and recompensa == 250, "ouro=%d" % (_dados_jogo.moedas - ouro_antes))
	_verificar("Progresso.registrar_chefe", _progresso.chefes == chefes_antes + 1 and _progresso.checkpoint_max >= 20, "chefes=%d" % _progresso.chefes)
	await create_timer(1.5).timeout
	_verificar("barra de chefe some ao morrer", not _hud.painel_chefe.visible, "")
	_verificar("chefe removido da cena", not is_instance_valid(chefe), "")
	_gerenciador.onda_atual = 1
	_progresso.iniciar_partida()
	_dados_jogo.moedas = 0

# -----------------------------------------------------------------
# Habilidades
# -----------------------------------------------------------------
func _lacaios_vivos() -> Array:
	return get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and n.eh_lacaio and not n.esta_morto)

func _testar_rei_slime() -> void:
	_limpar_inimigos()
	_gerenciador.onda_atual = 20
	_gerenciador.inimigos_vivos = 3
	_gerenciador.total_inimigos_onda = 3
	_progresso.iniciar_partida()
	var abates_antes: int = _progresso.abates
	_dados_jogo.moedas = 0
	var chefe: Node = _chefe_manual("res://cenas/inimigos/slime.tscn", "REI SLIME", 2.8, 11.0, "rei_slime", _jogador.global_position + Vector2(90, 0))
	await _quadros(3)
	var maximo: int = chefe.vida_maxima
	_verificar("rei slime tem a habilidade", chefe.habilidade_chefe != null and chefe.habilidade_chefe.tipo == "rei_slime", "")
	chefe.receber_dano(int(maximo * 0.20))
	await _quadros(3)
	_verificar("com 20%% perdidos nada acontece", _lacaios_vivos().size() == 0, "lacaios=%d" % _lacaios_vivos().size())
	chefe.receber_dano(int(maximo * 0.07) + 1)
	await _quadros(3)
	_verificar("perdeu 25%%: solta 3 slimes", _lacaios_vivos().size() == 3, "lacaios=%d" % _lacaios_vivos().size())
	chefe.receber_dano(int(maximo * 0.10))
	await _quadros(3)
	_verificar("sem novo limiar nao solta mais", _lacaios_vivos().size() == 3, "lacaios=%d" % _lacaios_vivos().size())
	chefe.receber_dano(int(maximo * 0.16))
	await _quadros(3)
	_verificar("perdeu 50%%: mais 3 slimes", _lacaios_vivos().size() == 6, "lacaios=%d" % _lacaios_vivos().size())
	chefe.receber_dano(int(maximo * 0.30))
	await _quadros(3)
	_verificar("perdeu 75%%: mais 3 slimes", _lacaios_vivos().size() == 9 and chefe.habilidade_chefe.levas_soltas == 3, "lacaios=%d" % _lacaios_vivos().size())
	_verificar("lacaios sao slimes pequenos (escala 1) fora da contagem", _lacaios_vivos().all(func(l): return l.scale.is_equal_approx(Vector2.ONE) and l.eh_lacaio and not l.eh_chefe), "")
	_verificar("lacaios nao mexem em inimigos_vivos", _gerenciador.inimigos_vivos == 3 and _gerenciador.total_inimigos_onda == 3, "vivos=%d" % _gerenciador.inimigos_vivos)
	# Matar lacaios: sem ouro, sem Brasas/abates, sem contar na onda
	var lacaios := _lacaios_vivos()
	for l in lacaios.slice(0, 4):
		l.receber_dano(999999)
	await create_timer(0.6).timeout
	_verificar("lacaios mortos nao contam na onda, nao dao ouro nem abate", _gerenciador.inimigos_vivos == 3 and _dados_jogo.moedas == 0 and _progresso.abates == abates_antes, "vivos=%d moedas=%d abates=%d" % [_gerenciador.inimigos_vivos, _dados_jogo.moedas, _progresso.abates - abates_antes])
	_verificar("mortos saem da lista da habilidade", chefe.habilidade_chefe.quantidade_lacaios() == 5, "n=%d" % chefe.habilidade_chefe.quantidade_lacaios())
	# O chefe morre: os lacaios restantes somem
	chefe.receber_dano(999999)
	await create_timer(1.0).timeout
	_verificar("lacaios somem com a morte do chefe", _lacaios_vivos().size() == 0 and get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and n.eh_lacaio).size() == 0, "restam=%d" % get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and n.eh_lacaio).size())
	_verificar("so o chefe ligado ao gerenciador mexe na contagem (nada aqui)", _gerenciador.inimigos_vivos == 3, "vivos=%d" % _gerenciador.inimigos_vivos)
	_limpar_inimigos()
	_gerenciador.inimigos_vivos = 0
	_gerenciador.onda_atual = 1
	_dados_jogo.moedas = 0

func _testar_caranguejo() -> void:
	_limpar_inimigos()
	_curar()
	_jogador.invulneravel = true
	# Campo aberto no meio da arena: perto do acampamento a investida bate na fogueira/barraca, e a posição
	# em que o jogador termina os testes anteriores muda conforme os eventos sorteados
	var posicao_original: Vector2 = _jogador.global_position
	_jogador.global_position = PONTO_ABERTO_INVESTIDA
	await _fisica(0.05)
	var inicio: Vector2 = _jogador.global_position + Vector2(-70, 0)
	var chefe: Node = _chefe_manual("res://cenas/inimigos/caranguejo.tscn", "CARANGUEJO COLOSSAL", 2.4, 6.0, "caranguejo", inicio)
	chefe.velocidade = 0
	await _quadros(3)
	var hab = chefe.habilidade_chefe
	_verificar("caranguejo tem a habilidade e comeca livre", hab != null and hab.tipo == "caranguejo" and hab.estado == HabilidadeChefe.Estado.LIVRE and not hab.assumiu_movimento(), "")
	var antes: Vector2 = chefe.global_position
	hab.iniciar_investida(Vector2.RIGHT)
	await _fisica(0.05)
	_verificar("aviso antes da investida: parado e assumindo o corpo", hab.estado == HabilidadeChefe.Estado.AVISO and hab.assumiu_movimento(), "estado=%d" % hab.estado)
	var piscou := false
	var tremeu := false
	for i in 20:
		await physics_frame
		if chefe.modulate != Color.WHITE:
			piscou = true
		if chefe.sprite.offset != Vector2.ZERO:
			tremeu = true
	_verificar("aviso pisca e treme", piscou and tremeu, "piscou=%s tremeu=%s" % [piscou, tremeu])
	_verificar("durante o aviso nao sai do lugar", chefe.global_position.distance_to(antes) < 3.0, "d=%f" % chefe.global_position.distance_to(antes))
	await _fisica(0.4)
	_verificar("depois do aviso (0,6 s) vem a investida", hab.estado == HabilidadeChefe.Estado.AGINDO, "estado=%d" % hab.estado)
	_verificar("tom e tremor voltam ao normal ao disparar", chefe.modulate == Color.WHITE and chefe.sprite.offset == Vector2.ZERO, "")
	await _fisica(0.65)
	var deslocamento: Vector2 = chefe.global_position - antes
	_verificar("investida rapida na direcao do jogador (+x)", deslocamento.x > 90.0 and absf(deslocamento.y) < 5.0, "desloc=%s" % deslocamento)
	await _fisica(0.8)
	_verificar("depois da recuperacao volta ao normal com recarga ~5 s", hab.estado == HabilidadeChefe.Estado.LIVRE and hab._tempo_restante > 3.5 and hab._tempo_restante <= 5.0, "estado=%d recarga=%f" % [hab.estado, hab._tempo_restante])
	# Respeita a colisão do mundo: investida contra uma parede para ali
	var parede := StaticBody2D.new()
	parede.collision_layer = 64
	var forma := CollisionShape2D.new()
	var ret := RectangleShape2D.new()
	ret.size = Vector2(8, 200)
	forma.shape = ret
	parede.add_child(forma)
	_cena.add_child(parede)
	parede.global_position = chefe.global_position + Vector2(50, 0)
	await _fisica(0.05)
	var x0: float = chefe.global_position.x
	hab.iniciar_investida(Vector2.RIGHT)
	await _fisica(1.8)
	_verificar("investida respeita a colisao com o mundo", chefe.global_position.x < parede.global_position.x - 2.0 and chefe.global_position.x > x0 + 5.0, "x=%f x0=%f parede=%f" % [chefe.global_position.x, x0, parede.global_position.x])
	_verificar("investida acabou ao bater (menos de 0,5 s)", hab.estado != HabilidadeChefe.Estado.AGINDO, "")
	parede.free()
	# Sem disparo manual o ciclo dispara sozinho quando o jogador esta perto
	hab._tempo_restante = 0.0
	hab.estado = HabilidadeChefe.Estado.LIVRE
	chefe.global_position = _jogador.global_position + Vector2(-100, 0)
	await _fisica(0.1)
	_verificar("dispara sozinha quando a recarga acaba", hab.estado == HabilidadeChefe.Estado.AVISO, "estado=%d" % hab.estado)
	chefe.receber_dano(999999)
	await _fisica(0.1)
	_verificar("morte do caranguejo cancela a habilidade", hab.estado == HabilidadeChefe.Estado.LIVRE and hab._encerrada and chefe.modulate == Color.WHITE, "")
	await create_timer(0.8).timeout
	_limpar_inimigos()
	# O ponto aberto fica ao lado de um spawn: os testes seguintes esperam o jogador onde estava
	_jogador.global_position = posicao_original
	_jogador.invulneravel = false

func _testar_cogumelo() -> void:
	_limpar_inimigos()
	_curar()
	_jogador.invulneravel = false
	_gerenciador.onda_atual = 40
	_gerenciador.inimigos_vivos = 3
	var chefe: Node = _chefe_manual("res://cenas/inimigos/cogumelo.tscn", "COGUMELO ANCIAO", 2.4, 6.5, "cogumelo", _jogador.global_position + Vector2(30, 0))
	chefe.velocidade = 0
	await _quadros(3)
	var hab = chefe.habilidade_chefe
	_verificar("cogumelo tem a habilidade", hab != null and hab.tipo == "cogumelo", "")
	hab._tempo_invocacao = 999.0
	hab._tempo_restante = 999.0
	# Esporos com aviso
	var hp0: int = _jogador.hp_atual
	hab.iniciar_esporos()
	await _quadros(5)
	var indicador: Node = hab._indicador
	_verificar("explosao de esporos mostra o indicador de ataque", is_instance_valid(indicador) and indicador.get_script() == IndicadorAtaqueScript and indicador.raio == HabilidadeChefe.RAIO_ESPOROS, "")
	_verificar("durante o aviso o chefe fica parado no lugar", hab.assumiu_movimento() and _jogador.hp_atual == hp0, "")
	var progresso0: float = indicador.progresso
	await create_timer(0.5).timeout
	_verificar("indicador enche com o tempo", is_instance_valid(indicador) and indicador.progresso > progresso0 + 0.2, "")
	await create_timer(0.8).timeout
	_verificar("esporos causam dano a quem ficou na area", _jogador.hp_atual < hp0, "hp=%d/%d" % [_jogador.hp_atual, hp0])
	_verificar("indicador detonado e liberado", hab._indicador == null, "")
	await create_timer(0.8).timeout
	_verificar("recarga dos esporos", hab.estado == HabilidadeChefe.Estado.LIVRE and hab._tempo_restante > 4.0, "estado=%d" % hab.estado)
	# Quem sai da area nao leva dano
	_curar()
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	var pos_jogador: Vector2 = _jogador.global_position
	chefe.global_position = pos_jogador + Vector2(HabilidadeChefe.RAIO_ESPOROS + 40.0, 0)
	hab.iniciar_esporos()
	await create_timer(1.3).timeout
	_verificar("fora da area nao leva dano", _jogador.hp_atual == _jogador.estatisticas.hp_maximo, "hp=%d" % _jogador.hp_atual)
	hab.estado = HabilidadeChefe.Estado.LIVRE
	# Invocação com limite
	var vivos_antes: int = _gerenciador.inimigos_vivos
	hab.invocar_cogumelos()
	await _quadros(3)
	_verificar("invoca 3 cogumelos", _lacaios_vivos().size() == 3, "n=%d" % _lacaios_vivos().size())
	hab.invocar_cogumelos()
	await _quadros(3)
	_verificar("6 lacaios no maximo", _lacaios_vivos().size() == HabilidadeChefe.MAX_LACAIOS, "n=%d" % _lacaios_vivos().size())
	hab.invocar_cogumelos()
	await _quadros(3)
	_verificar("respeita o limite de lacaios vivos", _lacaios_vivos().size() == HabilidadeChefe.MAX_LACAIOS, "n=%d" % _lacaios_vivos().size())
	_verificar("lacaios do cogumelo sao cogumelos fora da contagem da onda", _lacaios_vivos().all(func(l): return l.scene_file_path.ends_with("cogumelo.tscn") and not l.eh_chefe) and _gerenciador.inimigos_vivos == vivos_antes, "")
	# A invocação periódica acontece sozinha
	hab._tempo_invocacao = 0.0
	_lacaios_vivos()[0].receber_dano(999999)
	await create_timer(0.6).timeout
	await _quadros(2)
	_verificar("invocacao periodica reabastece apos mortes (vagas livres)", _lacaios_vivos().size() > 5 and hab._tempo_invocacao > 7.0, "n=%d t=%f" % [_lacaios_vivos().size(), hab._tempo_invocacao])
	chefe.receber_dano(999999)
	await create_timer(1.0).timeout
	_verificar("lacaios do cogumelo somem com o chefe", _lacaios_vivos().size() == 0, "n=%d" % _lacaios_vivos().size())
	_limpar_inimigos()
	_gerenciador.inimigos_vivos = 0
	_gerenciador.onda_atual = 1
	_curar()

func _contar_indicadores() -> int:
	var n := 0
	for filho in _cena.get_children():
		if filho.get_script() == IndicadorAtaqueScript:
			n += 1
	return n

func _testar_parar_ondas() -> void:
	_limpar_inimigos()
	_curar()
	await _quadros(60)
	var chefe: Node = _chefe_manual("res://cenas/inimigos/cogumelo.tscn", "COGUMELO ANCIAO", 2.4, 6.5, "cogumelo", _jogador.global_position + Vector2(200, 0))
	await _quadros(3)
	chefe.habilidade_chefe.invocar_cogumelos()
	chefe.habilidade_chefe.iniciar_esporos()
	await _quadros(5)
	_verificar("antes de parar: lacaios e indicador existem", _lacaios_vivos().size() == 3 and _contar_indicadores() == 1, "lac=%d ind=%d" % [_lacaios_vivos().size(), _contar_indicadores()])
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	await _quadros(3)
	_verificar("parar_ondas remove chefe e lacaios", get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size() == 0 and not is_instance_valid(chefe), "")
	await create_timer(0.4).timeout
	_verificar("parar_ondas limpa os indicadores de ataque", _contar_indicadores() == 0, "ind=%d" % _contar_indicadores())
	_verificar("parar_ondas limpa o evento", _gerenciador.evento_atual.is_empty(), "")

# -----------------------------------------------------------------
# Ondas de verdade
# -----------------------------------------------------------------
# Derruba tudo o que estiver vivo até a onda acabar; devolve o maior numero de lacaios visto
func _derrubar_ate_acabar(limite_s: float) -> int:
	var maior_lacaios := 0
	var t := 0.0
	while _gerenciador.onda_em_andamento and t < limite_s:
		_curar()
		maior_lacaios = maxi(maior_lacaios, _lacaios_vivos().size())
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and not inimigo.esta_morto:
				inimigo.receber_dano(99999, Vector2.ZERO)
		await create_timer(0.25).timeout
		t += 0.25
	return maior_lacaios

func _testar_ondas_de_evento() -> void:
	_limpar_inimigos()
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	_progresso.iniciar_partida()
	_gerenciador.chance_evento = 1.0
	_gerenciador.onda_atual = 5
	_dados_jogo.moedas = 0
	var vistos := []
	var ok_qtde := true
	var ok_ouro := true
	var detalhe := ""
	for i in 3:
		_gerenciador.iniciar_onda()
		var evento: Dictionary = _gerenciador.evento_atual
		var onda: int = _gerenciador.onda_atual
		vistos.append(evento.get("id", ""))
		_verificar("onda %d tem evento sorteado (chance 100%%)" % onda, not evento.is_empty(), "")
		var esperado_qtde: int = mini(roundi(mini(_gerenciador.max_inimigos + _gerenciador.inimigos_extra_por_onda * (onda - 1), 60) * float(evento.get("qtde", 1.0))), 60)
		if _gerenciador.total_inimigos_onda != esperado_qtde:
			ok_qtde = false
			detalhe += " onda%d total=%d esperado=%d" % [onda, _gerenciador.total_inimigos_onda, esperado_qtde]
		await _quadros(3)
		_verificar("HUD mostra evento da onda %d" % onda, _hud.rotulo_evento.visible and _hud.rotulo_evento.text == evento["nome"], "")
		var moedas0: int = _dados_jogo.moedas
		_gerenciador._resto_saque = 0.0
		var total: int = _gerenciador.total_inimigos_onda
		await _derrubar_ate_acabar(60.0)
		var ganho: int = _dados_jogo.moedas - moedas0
		var por_abate: float = (3.0 + int(onda / 4.0)) * float(evento.get("ouro", 1.0))
		var esperado_ouro: int = int(total * por_abate) + roundi(_gerenciador.ouro_fim_onda(onda) * float(evento.get("ouro", 1.0)))
		if absi(ganho - esperado_ouro) > 1:
			ok_ouro = false
			detalhe += " onda%d ganho=%d esperado=%d" % [onda, ganho, esperado_ouro]
		_verificar("onda %d terminou e avancou" % onda, not _gerenciador.onda_em_andamento and _gerenciador.onda_atual == onda + 1, "onda=%d" % _gerenciador.onda_atual)
		_verificar("evento limpo e indicador escondido apos a onda %d" % onda, _gerenciador.evento_atual.is_empty() and not _hud.rotulo_evento.visible, "")
		await create_timer(0.2).timeout
	_verificar("quantidade de inimigos segue o evento", ok_qtde, detalhe)
	_verificar("ouro da onda segue o multiplicador do evento", ok_ouro, detalhe)
	var repetiu := false
	for i in range(1, vistos.size()):
		if vistos[i] == vistos[i - 1]:
			repetiu = true
	_verificar("eventos sorteados em sequencia: %s" % str(vistos), not repetiu, "")
	_gerenciador.chance_evento = Gerenciador.CHANCE_EVENTO
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false

func _testar_ondas_de_chefe() -> void:
	_gerenciador.chance_evento = 0.0
	var casos := [[10, "MINOTAURO", false], [20, "REI SLIME", true], [30, "CARANGUEJO COLOSSAL", true], [40, "COGUMELO ANCIAO", true]]
	for caso in casos:
		_limpar_inimigos()
		_gerenciador.parar_ondas()
		_gerenciador.ondas_paradas = false
		_progresso.iniciar_partida()
		_progresso.checkpoint_max = 0
		var onda: int = caso[0]
		_gerenciador.onda_atual = onda
		_dados_jogo.moedas = 0
		_gerenciador.iniciar_onda()
		_verificar("onda %d: sem evento na onda de chefe" % onda, _gerenciador.evento_atual.is_empty(), "")
		_verificar("onda %d conta chefe + escolta" % onda, _gerenciador.inimigos_vivos == 1 + _gerenciador.escolta_chefe and _gerenciador.total_inimigos_onda == 1 + _gerenciador.escolta_chefe, "vivos=%d" % _gerenciador.inimigos_vivos)
		await create_timer(2.5).timeout
		var inimigos := get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and not n.esta_morto)
		var chefes := inimigos.filter(func(n): return n.eh_chefe or n.has_method("_impacto"))
		_verificar("onda %d: 1 chefe + %d na escolta" % [onda, _gerenciador.escolta_chefe], chefes.size() == 1 and inimigos.size() == 1 + _gerenciador.escolta_chefe, "chefes=%d inimigos=%d" % [chefes.size(), inimigos.size()])
		if chefes.size() == 1:
			var chefe: Node = chefes[0]
			if caso[2]:
				_verificar("onda %d: %s, escala %.1f, coroa dourada e barra no HUD" % [onda, caso[1], chefe.scale.x],
						chefe.eh_chefe and chefe.nome_chefe == caso[1] and chefe.get_node_or_null("CoroaMutante") != null and chefe.get_node("CoroaMutante").paleta == CoroaMutante.PALETA_DOURADA
						and _hud.painel_chefe.visible and _hud.nome_chefe.text == caso[1] and chefe.scale.x > 2.0, "")
				var mult_vida: float = _gerenciador.mult_vida_onda(onda)
				_verificar("onda %d: vida do chefe com multiplicadores da onda" % onda, chefe.vida_maxima == chefe.vida and chefe.vida_maxima > 200 * 1 and chefe.vida_maxima >= roundi(mult_vida * 30), "vida=%d" % chefe.vida_maxima)
			else:
				_verificar("onda 10: minotauro com comportamento proprio e barra de chefe", _hud.painel_chefe.visible and _hud.nome_chefe.text == "MINOTAURO" and chefe.eh_chefe, "")
			if caso[1] == "COGUMELO ANCIAO":
				chefe.habilidade_chefe.invocar_cogumelos()
				chefe.habilidade_chefe.iniciar_esporos()
				await _quadros(3)
		var vivos_inicio: int = _gerenciador.inimigos_vivos
		var maior_lacaios := await _derrubar_ate_acabar(60.0)
		_verificar("onda %d de chefe terminou (inimigos_vivos=0)" % onda, not _gerenciador.onda_em_andamento and _gerenciador.inimigos_vivos == 0, "vivos=%d" % _gerenciador.inimigos_vivos)
		_verificar("onda %d avancou para %d" % [onda, onda + 1], _gerenciador.onda_atual == onda + 1, "onda=%d" % _gerenciador.onda_atual)
		_verificar("onda %d: chefe registrado no Progresso" % onda, _progresso.chefes == 1 and _progresso.checkpoint_max == onda, "chefes=%d checkpoint=%d" % [_progresso.chefes, _progresso.checkpoint_max])
		await create_timer(1.5).timeout
		_verificar("onda %d: nao sobrou nenhum inimigo, lacaio ou indicador" % onda, get_nodes_in_group("enemy").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size() == 0 and _contar_indicadores() == 0, "")
		_verificar("onda %d: barra de chefe escondida" % onda, not _hud.painel_chefe.visible, "")
		if caso[1] == "COGUMELO ANCIAO":
			_verificar("onda 40: lacaios apareceram durante a luta sem afetar a conta", maior_lacaios >= 3, "maior=%d" % maior_lacaios)
		# A recompensa: 3 abates + 250 do chefe (nos que usam tornar_chefe e no golem) + final
		_verificar("onda %d: ouro do chefe recebido" % onda, _dados_jogo.moedas >= 250 + _gerenciador.ouro_fim_onda(onda), "moedas=%d" % _dados_jogo.moedas)
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false

	# Estagio bonus nao quebra
	_limpar_inimigos()
	_progresso.iniciar_partida()
	_gerenciador.onda_atual = 6
	_gerenciador.chance_onda_bonus = 1.0
	_gerenciador.chance_evento = 1.0
	_gerenciador._bonus_na_onda_anterior = false
	_gerenciador.iniciar_onda()
	_verificar("bonus: sem evento e so mimicos", _gerenciador.onda_bonus and _gerenciador.evento_atual.is_empty(), "")
	await create_timer(1.0).timeout
	await _derrubar_ate_acabar(90.0)
	_verificar("bonus terminou sem avancar a onda", not _gerenciador.onda_em_andamento and _gerenciador.onda_atual == 6 and _gerenciador.inimigos_vivos == 0, "onda=%d vivos=%d" % [_gerenciador.onda_atual, _gerenciador.inimigos_vivos])
	_gerenciador.parar_ondas()
