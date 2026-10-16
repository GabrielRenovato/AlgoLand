extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_clima.gd
# Cobre o clima (codigo/cenario/clima.gd), o evento TEMPESTADE e os raios (codigo/efeitos/raio.gd): sorteio por estação,
# camadas de chuva/neve/nuvens, tom da luz, respingos fora da água, raios com dano em área (inimigos e jogador),
# limpeza em parar_ondas / fim do evento, som da chuva e a tela de título fixa em NEVE_LEVE.
# ATENCAO: abre a cena de jogo; faça backup do user:// antes (o Progresso grava num arquivo de teste e é apagado ao final)

const CAMINHO_PROGRESSO := "user://teste_clima_progresso.json"

# Carregados em _rodar: dependem dos autoloads, que só existem depois do primeiro quadro
var Clima: GDScript
var Gerenciador: GDScript
var Raio: GDScript
var IndicadorAtaqueScript: GDScript
var _falhas: int = 0
var _cena: Node
var _jogador: Node
var _progresso: Node
var _gerenciador: Node
var _est: Node
var _meteoro: Node
var _luz: Node
var _hud: Node

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

func _evento(id: String) -> Dictionary:
	for e in Gerenciador.EVENTOS:
		if e["id"] == id:
			return e
	return {}

func _rodar() -> void:
	await process_frame
	Clima = load("res://codigo/cenario/clima.gd")
	Gerenciador = load("res://codigo/logica/gerenciador_de_ondas.gd")
	Raio = load("res://codigo/efeitos/raio.gd")
	IndicadorAtaqueScript = load("res://codigo/efeitos/indicador_ataque.gd")
	_progresso = root.get_node("Progresso")
	_progresso.caminho_save = CAMINHO_PROGRESSO
	# O clima do mundo fica no autoload Fazenda (as ondas o mudam): arquivo de teste, sem o save real
	var fazenda_isolada = root.get_node("Fazenda")
	fazenda_isolada.caminho_save = "user://teste_clima_fazenda.json"
	fazenda_isolada.apagar()
	_progresso.melhorias = {}

	_testar_sorteio_de_clima()
	_testar_sorteio_do_evento()

	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.3).timeout
	_jogador = _cena.get_node("Jogador")
	_gerenciador = _cena.get_node("enemySpawner/GerenciadorOndas")
	_est = _cena.get_node("Terrains/Estacoes")
	_meteoro = _est.meteorologia
	_luz = _cena.get_node("Iluminacao")
	_hud = get_first_node_in_group("hud")
	_gerenciador.chance_onda_bonus = 0.0
	_gerenciador.chance_evento = 0.0

	await _testar_estados_e_camadas()
	await _testar_fade_e_tom()
	_testar_estacoes_e_vagalumes()
	await _testar_sorteio_por_onda()
	await _testar_impactos()
	await _testar_som_da_chuva()
	await _testar_evento_tempestade()
	await _testar_dano_do_raio()
	await _testar_alinhamento_do_raio()
	await _testar_cadencia_dos_raios()
	await _testar_limpeza()
	await _testar_tempestade_em_onda_de_verdade()
	_cena.queue_free()
	await _quadros(3)
	await _testar_tela_de_titulo()

	if FileAccess.file_exists(CAMINHO_PROGRESSO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	print("FALHAS: ", _falhas)
	if FileAccess.file_exists("user://teste_clima_fazenda.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_clima_fazenda.json"))
	quit(_falhas)

# -----------------------------------------------------------------
# Sorteio do clima (função pura)
# -----------------------------------------------------------------
func _testar_sorteio_de_clima() -> void:
	var E: Dictionary = Clima.Estado
	var esperado := [
		{E.LIMPO: 0.60, E.CHUVA_LEVE: 0.40},
		{E.LIMPO: 0.75, E.NUBLADO: 0.25},
		{E.NUBLADO: 0.30, E.CHUVA_LEVE: 0.40, E.CHUVA_FORTE: 0.30},
		{E.NEVE_LEVE: 0.60, E.NEVE_FORTE: 0.40},
	]
	var nomes := ["primavera", "verao", "outono", "inverno"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260711
	var amostras := 60000
	for est in 4:
		var contagem := {}
		for i in amostras:
			var c: int = Clima.sortear_clima(est, rng)
			contagem[c] = contagem.get(c, 0) + 1
		var so_permitidos := true
		var freq_ok := true
		var texto := ""
		for c in contagem:
			if not esperado[est].has(c):
				so_permitidos = false
		for c in esperado[est]:
			var f := float(contagem.get(c, 0)) / amostras
			texto += " %d=%.3f" % [c, f]
			if absf(f - float(esperado[est][c])) > 0.01:
				freq_ok = false
		_verificar("%s: so sorteia os climas da estacao" % nomes[est], so_permitidos, str(contagem))
		_verificar("%s: frequencias batem com a tabela (%s )" % [nomes[est], texto], freq_ok, str(contagem))
	_verificar("clima padrao: primavera e verao limpo, outono nublado, inverno neve leve",
			Clima.clima_padrao(0) == E.LIMPO and Clima.clima_padrao(1) == E.LIMPO and Clima.clima_padrao(2) == E.NUBLADO and Clima.clima_padrao(3) == E.NEVE_LEVE, "")
	_verificar("neve so no inverno e chuva nunca no inverno (nem no padrao)", Clima.eh_neve(Clima.clima_padrao(3)) and not Clima.eh_chuva(Clima.clima_padrao(3)), "")
	_verificar("7 estados", Clima.Estado.size() == 7, str(Clima.Estado))

# -----------------------------------------------------------------
# Evento TEMPESTADE no sorteio (função pura)
# -----------------------------------------------------------------
func _testar_sorteio_do_evento() -> void:
	var tempestade := _evento("tempestade")
	_verificar("tempestade na tabela: ouro x1,4", not tempestade.is_empty() and is_equal_approx(tempestade["ouro"], 1.4) and tempestade["nome"] == "TEMPESTADE", str(tempestade))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var no_inverno := 0
	var em_chefe := 0
	var em_bonus := 0
	var fora_do_inverno := 0
	for i in 6000:
		var onda := 4 + i % 40
		if Gerenciador.sortear_evento(onda, false, false, "", rng, 1.0, 3).get("id", "") == "tempestade":
			no_inverno += 1
		for est in 4:
			if Gerenciador.sortear_evento(onda, true, false, "", rng, 1.0, est).get("id", "") == "tempestade":
				em_chefe += 1
			if Gerenciador.sortear_evento(onda, false, true, "", rng, 1.0, est).get("id", "") == "tempestade":
				em_bonus += 1
		for est in 3:
			if Gerenciador.sortear_evento(onda, false, false, "", rng, 1.0, est).get("id", "") == "tempestade":
				fora_do_inverno += 1
	_verificar("tempestade nunca sorteia no inverno", no_inverno == 0, "n=%d" % no_inverno)
	_verificar("tempestade nunca em onda de chefe", em_chefe == 0, "n=%d" % em_chefe)
	_verificar("tempestade nunca em onda bonus", em_bonus == 0, "n=%d" % em_bonus)
	_verificar("tempestade sorteia na primavera, verao e outono", fora_do_inverno > 1000, "n=%d" % fora_do_inverno)
	# No inverno os outros eventos continuam saindo
	var outros_no_inverno := {}
	for i in 3000:
		var e: Dictionary = Gerenciador.sortear_evento(8, false, false, "", rng, 1.0, 3)
		outros_no_inverno[e["id"]] = true
	_verificar("inverno ainda sorteia os outros 5 eventos", outros_no_inverno.size() == 5 and not outros_no_inverno.has("tempestade"), str(outros_no_inverno.keys()))
	# O gerenciador usa a estação do calendário (dias 22..28 = inverno)
	_gerenciador_estacao_da_onda()

# A estação passada ao sorteio pelo gerenciador (iniciar_onda) vem do Calendario: dias 22 a 28 = inverno
func _gerenciador_estacao_da_onda() -> void:
	var calendario = root.get_node("Calendario")
	var inverno_ok := true
	for dia in range(22, 29):
		if calendario.estacao(dia) != Gerenciador.ESTACAO_INVERNO:
			inverno_ok = false
	_verificar("dias 22 a 28 sao o inverno do sorteio", inverno_ok, "")

# -----------------------------------------------------------------
# Estados: camadas, ordem, velocidades
# -----------------------------------------------------------------
func _alfas() -> Array:
	return _meteoro._camadas.map(func(c): return snappedf(c.alfa, 0.01))

func _testar_estados_e_camadas() -> void:
	var E: Dictionary = Clima.Estado
	_verificar("clima agora e o padrao da primavera: limpo", _meteoro.clima_atual == E.LIMPO, "clima=%d" % _meteoro.clima_atual)
	# camadas: [chuva forte, chuva leve, neve forte, neve leve]
	var c: Array = _meteoro._camadas
	_verificar("4 camadas de queda: chuva forte, chuva leve, neve forte, neve leve", c.size() == 4, "n=%d" % c.size())
	_verificar("tempos do readme: chuva leve 50ms, forte 100ms, neve leve 175ms, forte 100ms",
			is_equal_approx(c[1].duracao, 0.05) and is_equal_approx(c[0].duracao, 0.1) and is_equal_approx(c[3].duracao, 0.175) and is_equal_approx(c[2].duracao, 0.1),
			str(c.map(func(x): return x.duracao)))
	_verificar("8 quadros de 32x128 por camada", c.all(func(x): return x.quadros.size() == 8 and x.quadros[0].get_size() == Vector2(32, 128)), "")
	_verificar("forte fica atras da leve (ordem na arvore)", c[0].no.get_index() < c[1].no.get_index() and c[2].no.get_index() < c[3].no.get_index(), "")
	_verificar("limpo: nenhuma camada, nenhuma nuvem", _alfas() == [0.0, 0.0, 0.0, 0.0] and _meteoro._nuvens.all(func(n): return not n.visible), str(_alfas()))

	var casos := [
		["CHUVA_LEVE", true, false, false, false],
		["CHUVA_FORTE", true, true, false, false],
		["TEMPESTADE", true, true, false, false],
		["NEVE_LEVE", false, false, false, true],
		["NEVE_FORTE", false, false, true, true],
		["NUBLADO", false, false, false, false],
		["LIMPO", false, false, false, false],
	]
	for caso in casos:
		_meteoro.definir_clima(E[caso[0]], true)
		# a ordem das camadas e [forte, leve, ...]: confere forte/leve da chuva e da neve
		var esperado := [caso[2], caso[1], caso[3], caso[4]]
		var obtido := c.map(func(x): return x.alfa > 0.0)
		_verificar("%s: camadas de queda %s" % [caso[0], str(esperado)], obtido == esperado, str(_alfas()))
		var nuvens: bool = _meteoro._nuvens[0].modulate.a > 0.0
		_verificar("%s: sombras de nuvem %s" % [caso[0], "sim" if caso[0] in ["NUBLADO", "CHUVA_FORTE", "TEMPESTADE"] else "nao"],
				nuvens == (caso[0] in ["NUBLADO", "CHUVA_FORTE", "TEMPESTADE"]), "a=%f" % _meteoro._nuvens[0].modulate.a)
	# Cobertura da tela: o ladrilho acompanha o retângulo visível e passa dele (sem lacunas)
	_meteoro.definir_clima(E.CHUVA_FORTE, true)
	await _quadros(4)
	var visivel: Rect2 = _meteoro.retangulo_visivel()
	var cobre := true
	for camada in c.slice(0, 2):
		var r: TextureRect = camada.no
		var rect := Rect2(r.global_position, r.size)
		if not (rect.position.x <= visivel.position.x + 1.0 and rect.position.y <= visivel.position.y + 1.0 and rect.end.x >= visivel.end.x and rect.end.y >= visivel.end.y):
			cobre = false
		if r.stretch_mode != TextureRect.STRETCH_TILE:
			cobre = false
	_verificar("chuva cobre a tela inteira (ladrilho TILE)", cobre, "visivel=%s" % visivel)
	# Presa ao mundo: a câmera anda um valor quebrado e o desenho continua alinhado à grade do ladrilho
	# (se seguisse a câmera, a chuva "andaria junto" com o jogador)
	var jogador: Node2D = _cena.get_node("Jogador")
	var posicao_jogador := jogador.global_position
	jogador.global_position += Vector2(37, 23)
	await _quadros(6)
	visivel = _meteoro.retangulo_visivel()
	var presa_ao_mundo := true
	for camada in c.slice(0, 2):
		var r: TextureRect = camada.no
		var rect := Rect2(r.global_position, r.size)
		if not is_zero_approx(fposmod(rect.position.x, 32.0)) or not is_zero_approx(fposmod(rect.position.y, 128.0)):
			presa_ao_mundo = false
		if not (rect.position.x <= visivel.position.x and rect.position.y <= visivel.position.y and rect.end.x >= visivel.end.x and rect.end.y >= visivel.end.y):
			presa_ao_mundo = false
	_verificar("chuva presa ao mundo (grade do ladrilho) e ainda cobrindo a tela apos a camera andar", presa_ao_mundo, "visivel=%s" % visivel)
	jogador.global_position = posicao_jogador
	await _quadros(4)
	# Cobertura de nuvens: máscara sem formas que a folha não desenha, ~62% do mapa, e andando com o vento
	var mascara: Array = _meteoro.mascara_nuvens(48, 32, 0.62, 7)
	var cobertas := 0
	var formas_ok := true
	for y in 32:
		for x in 48:
			if not mascara[y][x]:
				continue
			cobertas += 1
			var n: bool = _meteoro._celula(mascara, x, y - 1)
			var s: bool = _meteoro._celula(mascara, x, y + 1)
			var o: bool = _meteoro._celula(mascara, x - 1, y)
			var l: bool = _meteoro._celula(mascara, x + 1, y)
			if (not n and not s) or (not o and not l):
				formas_ok = false
	var fracao := cobertas / float(48 * 32)
	_verificar("nuvens: sem faixa de 1 celula e cobrindo ~62%% (%.2f)" % fracao, formas_ok and fracao > 0.5 and fracao < 0.8, "")
	_meteoro.definir_clima(E.NUBLADO, true)
	await _quadros(2)
	var cobertura: TextureRect = _meteoro._nuvens[0]
	var antes_vento: Vector2 = _meteoro._deslocamento_nuvens
	await create_timer(1.0).timeout
	var andou: float = (_meteoro._deslocamento_nuvens - antes_vento).length()
	_verificar("nuvens andam com o vento (%.1f px em 1 s)" % andou, andou > 8.0 and cobertura.visible and cobertura.stretch_mode == TextureRect.STRETCH_TILE, "")
	# volta para a chuva forte: as checagens seguintes olham a animação da chuva
	_meteoro.definir_clima(E.CHUVA_FORTE, true)
	await _quadros(2)
	# a camada anda: o quadro da animacao troca com o tempo
	var antes: int = c[1].indice
	await create_timer(0.12).timeout
	_verificar("a animacao troca de quadro (%d -> %d)" % [antes, c[1].indice], c[1].indice != antes and c[1].no.texture == c[1].quadros[c[1].indice], "")
	# abaixo do HUD: o clima fica no mundo (nao e CanvasLayer) e o clarao na camada 1, antes do HUD na arvore
	var em_canvas_layer := false
	var no: Node = _meteoro._mundo
	while no != null:
		if no is CanvasLayer:
			em_canvas_layer = true
		no = no.get_parent()
	_verificar("chuva/neve no mundo (abaixo dos CanvasLayers, HUD por cima)", not em_canvas_layer and _meteoro._mundo.z_index == 1000, "")
	_verificar("clarao dos raios na camada do HUD, mas desenhado antes dele", _meteoro._flash_camada.layer <= _hud.layer and _hud.is_greater_than(_meteoro._flash_camada), "flash=%d hud=%d" % [_meteoro._flash_camada.layer, _hud.layer])
	_meteoro.definir_clima(E.LIMPO, true)

# -----------------------------------------------------------------
# Fade e tom da luz (por cima do ciclo, da estação e do evento)
# -----------------------------------------------------------------
func _testar_fade_e_tom() -> void:
	var E: Dictionary = Clima.Estado
	var modulador: CanvasModulate = _luz.get_node("CanvasModulate")
	_luz.set_process(false)
	_luz.tom_evento = Color.WHITE
	_meteoro.definir_clima(E.LIMPO, true)
	_luz._aplicar()
	var cor_limpo: Color = modulador.color
	_verificar("limpo: tom do clima branco", _luz.tom_clima.is_equal_approx(Color.WHITE), "%s" % _luz.tom_clima)
	# fade de entrada: nao pula de 0 para o alvo
	_meteoro.definir_clima(E.CHUVA_FORTE)
	await create_timer(0.35).timeout
	var meio: float = _meteoro._camadas[0].alfa
	_verificar("fade de entrada em andamento (alfa %.2f entre 0 e 0.9)" % meio, meio > 0.05 and meio < 0.85, "")
	await create_timer(1.6).timeout
	_luz._aplicar()
	_verificar("fade de entrada termina no alvo", is_equal_approx(_meteoro._camadas[0].alfa, 0.9) and is_equal_approx(_meteoro._camadas[1].alfa, 0.85), str(_alfas()))
	_verificar("chuva forte escurece a tela via Iluminacao", modulador.color.get_luminance() < cor_limpo.get_luminance() - 0.05 and _luz.tom_clima.is_equal_approx(Clima.TONS[E.CHUVA_FORTE]), "%s vs %s" % [modulador.color, cor_limpo])
	_verificar("o tom do clima multiplica por cima do ciclo, da estacao e do evento", modulador.color.is_equal_approx(_luz._gradiente.sample(_luz.hora / 24.0) * _luz.tom_estacao * _luz.tom_evento * _luz.tom_clima), "")
	# o evento (neblina) continua funcionando junto com o clima
	_luz.definir_tom_evento(Color(0.5, 0.6, 0.7), 0.0)
	_luz._aplicar()
	_verificar("evento e clima se multiplicam", modulador.color.is_equal_approx(_luz._gradiente.sample(_luz.hora / 24.0) * _luz.tom_estacao * Color(0.5, 0.6, 0.7) * _luz.tom_clima), "")
	_luz.definir_tom_evento(Color.WHITE, 0.0)
	# fade de saida
	_meteoro.definir_clima(E.LIMPO)
	await create_timer(0.35).timeout
	var saindo: float = _meteoro._camadas[0].alfa
	_verificar("fade de saida em andamento (alfa %.2f)" % saindo, saindo > 0.05 and saindo < 0.85, "")
	await create_timer(1.6).timeout
	_luz._aplicar()
	_verificar("fade de saida termina em zero e devolve a tela", _alfas() == [0.0, 0.0, 0.0, 0.0] and _luz.tom_clima.is_equal_approx(Color.WHITE) and modulador.color.is_equal_approx(cor_limpo), "%s" % modulador.color)
	_luz.set_process(true)

# -----------------------------------------------------------------
# Estação define o clima padrão; vaga-lumes se escondem na chuva
# -----------------------------------------------------------------
func _testar_estacoes_e_vagalumes() -> void:
	var E: Dictionary = Clima.Estado
	var padrao := [E.LIMPO, E.LIMPO, E.NUBLADO, E.NEVE_LEVE]
	for i in 4:
		_est.definir_estacao(i, true)
		_verificar("estacao %d: clima padrao %d" % [i, padrao[i]], _meteoro.clima_atual == padrao[i], "clima=%d" % _meteoro.clima_atual)
	_est.definir_estacao(1, true)
	var vagalumes: CPUParticles2D = _est.get_node("CamadaVagalumes").get_child(0)
	_verificar("verao limpo: vaga-lumes acesos", vagalumes.emitting, "")
	_meteoro.definir_clima(E.CHUVA_LEVE, true)
	_verificar("verao na chuva: vaga-lumes escondidos", not vagalumes.emitting, "")
	_meteoro.definir_clima(E.NUBLADO, true)
	_verificar("verao nublado: vaga-lumes voltam", vagalumes.emitting, "")
	_est.definir_estacao(0, true)
	var petalas: CPUParticles2D = _est.get_node("Clima").get_child(0)
	_meteoro.definir_clima(E.CHUVA_LEVE, true)
	_verificar("primavera na chuva: petalas continuam", petalas.emitting, "")
	_meteoro.definir_clima(E.LIMPO, true)

# -----------------------------------------------------------------
# Sorteio a cada onda e volta ao padrão
# -----------------------------------------------------------------
func _testar_sorteio_por_onda() -> void:
	var E: Dictionary = Clima.Estado
	var permitidos := [
		[E.LIMPO, E.CHUVA_LEVE],
		[E.LIMPO, E.NUBLADO],
		[E.NUBLADO, E.CHUVA_LEVE, E.CHUVA_FORTE],
		[E.NEVE_LEVE, E.NEVE_FORTE],
	]
	_meteoro._rng.seed = 99
	var tudo_ok := true
	var vistos := {}
	# A estacao vem do calendario (aqui trocada na mao): 5 ondas em cada uma das 4 estacoes
	for est in 4:
		_est.definir_estacao(est, true)
		for onda in range(1, 6):
			_gerenciador.onda_iniciada.emit(onda)
			vistos[_meteoro.clima_atual] = true
			if not (_meteoro.clima_atual in permitidos[est]) or _meteoro.clima_base != _meteoro.clima_atual:
				tudo_ok = false
				print("  onda ", onda, " estacao ", est, " clima ", _meteoro.clima_atual)
	_verificar("onda iniciada sorteia o clima da estacao atual (20 ondas, %d climas vistos)" % vistos.size(), tudo_ok and vistos.size() >= 5, str(vistos.keys()))
	# O clima é do mundo (Fazenda.clima_hoje): o sorteio da onda muda o tempo da fazenda também
	var fazenda = root.get_node("Fazenda")
	_est.definir_estacao(1, true)
	_gerenciador.onda_iniciada.emit(12)
	var sorteado: int = _meteoro.clima_atual
	_verificar("onda sorteia o clima do mundo (o mesmo da fazenda)", fazenda.clima_hoje == sorteado, "fazenda=%d arena=%d" % [fazenda.clima_hoje, sorteado])
	# Parar as ondas (morrer) não muda o tempo do mundo; a estacao em si nao muda (e do calendario)
	_meteoro.definir_clima(E.CHUVA_FORTE, true)
	_gerenciador.sinal_ondas_paradas.emit()
	_verificar("ondas paradas: volta ao clima do mundo", _meteoro.clima_atual == sorteado and _meteoro.clima_base == _meteoro.clima_atual and not _meteoro.tempestade_ativa, "clima=%d mundo=%d" % [_meteoro.clima_atual, sorteado])
	# O tempo mudou em outro lugar (ex.: dormir na fazenda): a arena segue
	fazenda.definir_clima_hoje(E.NUBLADO)
	_verificar("arena segue o clima do mundo quando ele muda", _meteoro.clima_atual == E.NUBLADO, "clima=%d" % _meteoro.clima_atual)
	# Chuva no mundo molha o solo arado da fazenda
	fazenda.solo[Vector2i(2, 2)] = {"planta": "", "dias": 0, "molhado": false, "murcha": false}
	fazenda.definir_clima_hoje(E.CHUVA_LEVE)
	_verificar("chuva no mundo rega o solo da fazenda", bool(fazenda.solo[Vector2i(2, 2)]["molhado"]), str(fazenda.solo[Vector2i(2, 2)]))
	fazenda.solo.erase(Vector2i(2, 2))
	_verificar("ondas paradas: a estacao nao muda", _est.estacao_atual == 1, "est=%d" % _est.estacao_atual)
	# Troca de estacao zera o clima para o padrao da nova
	_est.definir_estacao(2, true)
	_meteoro.definir_clima(E.CHUVA_FORTE, true)
	_est.definir_estacao(3, true)
	_verificar("troca para o inverno: chuva vira neve leve", _meteoro.clima_atual == E.NEVE_LEVE, "clima=%d" % _meteoro.clima_atual)
	_est.definir_estacao(0, true)
	_gerenciador.sinal_ondas_paradas.emit()

# -----------------------------------------------------------------
# Respingos e flocos no chão
# -----------------------------------------------------------------
func _testar_impactos() -> void:
	var E: Dictionary = Clima.Estado
	var agua: TileMapLayer = _cena.get_node("Terrains/Agua")
	var penhasco: TileMapLayer = _cena.get_node("Terrains/Penhasco")
	var terra: TileMapLayer = _cena.get_node("Terrains/Terra")
	var celulas_agua := agua.get_used_cells()
	var celulas_penhasco := penhasco.get_used_cells()
	var agua_aceita := 0
	for celula in celulas_agua:
		if _meteoro.celula_aceita_impacto(celula, false):
			agua_aceita += 1
	var penhasco_aceito := 0
	for celula in celulas_penhasco:
		if _meteoro.celula_aceita_impacto(celula, false):
			penhasco_aceito += 1
	_verificar("nenhuma das %d celulas de agua aceita respingo" % celulas_agua.size(), celulas_agua.size() > 50 and agua_aceita == 0, "aceitas=%d" % agua_aceita)
	_verificar("nenhuma das %d celulas de penhasco aceita respingo" % celulas_penhasco.size(), celulas_penhasco.size() > 20 and penhasco_aceito == 0, "aceitas=%d" % penhasco_aceito)
	# sob copas de arvore: o centro de cada cobertura nao aceita
	_meteoro._coberto(Vector2.ZERO)
	var cobertas := 0
	var aceitas_sob_copa := 0
	var chao: TileMapLayer = _cena.get_node("Terrains/Chao")
	for i in _meteoro._coberturas.size():
		var r: Rect2 = _meteoro._coberturas[i]
		# so as grandes (copas, caverna): o centro da celula cai dentro do retangulo; as visiveis
		if r.size.x < 32.0 or r.size.y < 32.0 or not _meteoro._cobertura_nos[i].is_visible_in_tree():
			continue
		var celula := chao.local_to_map(chao.to_local(r.get_center()))
		cobertas += 1
		if _meteoro.celula_aceita_impacto(celula, false):
			aceitas_sob_copa += 1
	_verificar("sob copas nao cai respingo (%d coberturas)" % cobertas, cobertas > 20 and aceitas_sob_copa == 0, "aceitas=%d" % aceitas_sob_copa)
	var terra_aceita := 0
	var celulas_terra := terra.get_used_cells()
	for celula in celulas_terra:
		if _meteoro.celula_aceita_impacto(celula, true):
			terra_aceita += 1
	_verificar("na terra batida os flocos caem (%d de %d celulas)" % [terra_aceita, celulas_terra.size()], terra_aceita > celulas_terra.size() / 2, "")
	# em jogo: respingos aparecem, poucos por vez, nunca na agua
	_jogador.global_position = Vector2(560, 232)
	await _quadros(5)
	_meteoro.definir_clima(E.TEMPESTADE, true)
	_meteoro.limpar_raios()
	var maximo := 0
	var visto := 0
	var na_agua := 0
	for i in 150:
		await process_frame
		maximo = maxi(maximo, _meteoro._impactos.size())
		for impacto in _meteoro._impactos:
			visto += 1
			var cel := chao.local_to_map(chao.to_local(impacto.sprite.global_position))
			if agua.get_cell_source_id(cel) != -1 or penhasco.get_cell_source_id(cel) != -1:
				na_agua += 1
		_meteoro._cronometro_raio = 100.0  # sem raios neste teste
	_verificar("respingos de chuva aparecem (max %d ao mesmo tempo, limite %d)" % [maximo, Clima.MAX_IMPACTOS], maximo >= 2 and maximo <= Clima.MAX_IMPACTOS, "max=%d" % maximo)
	_verificar("nenhum respingo na agua ou no penhasco (%d vistos)" % visto, visto > 20 and na_agua == 0, "na_agua=%d" % na_agua)
	_meteoro.definir_clima(E.NEVE_FORTE, true)
	await _quadros(5)
	_est.definir_estacao(3, true)
	_meteoro.definir_clima(E.NEVE_FORTE, true)
	var flocos := 0
	for i in 150:
		await process_frame
		flocos = maxi(flocos, _meteoro._impactos.size())
	_verificar("flocos de neve aparecem no inverno (max %d)" % flocos, flocos >= 1 and flocos <= Clima.MAX_IMPACTOS, "")
	_est.definir_estacao(0, true)
	_meteoro.definir_clima(E.LIMPO, true)
	await create_timer(1.6).timeout
	_verificar("sem chuva os respingos acabam", _meteoro._impactos.is_empty(), "n=%d" % _meteoro._impactos.size())

# -----------------------------------------------------------------
# Som da chuva
# -----------------------------------------------------------------
func _testar_som_da_chuva() -> void:
	var E: Dictionary = Clima.Estado
	var fluxo: AudioStreamWAV = _meteoro._som_chuva.stream
	_verificar("chuva.wav em loop sem clique (loop forward, de 0 ao fim)", fluxo.loop_mode == AudioStreamWAV.LOOP_FORWARD and fluxo.loop_begin == 0 and fluxo.loop_end > 20000, "modo=%d fim=%d" % [fluxo.loop_mode, fluxo.loop_end])
	_verificar("chuva.wav tem de 2 a 3 s", fluxo.get_length() >= 2.0 and fluxo.get_length() <= 3.0, "%f" % fluxo.get_length())
	_verificar("trovao.wav existe no Sons", root.get_node("Sons").existe("trovao"), "")
	_meteoro.definir_clima(E.LIMPO, true)
	_verificar("sem chuva: som parado", not _meteoro._som_chuva.playing, "")
	_meteoro.definir_clima(E.CHUVA_LEVE)
	await create_timer(0.3).timeout
	_verificar("chuva leve: som tocando com fade (%.1f dB)" % _meteoro._som_chuva.volume_db, _meteoro._som_chuva.playing and _meteoro._som_chuva.volume_db > -60.0 and _meteoro._som_chuva.volume_db < -27.0, "")
	await create_timer(1.6).timeout
	_verificar("chuva leve: volume baixinho no alvo (%.1f dB)" % _meteoro._som_chuva.volume_db, is_equal_approx(_meteoro._som_chuva.volume_db, -27.0), "")
	_meteoro.definir_clima(E.TEMPESTADE)
	await create_timer(1.7).timeout
	_verificar("tempestade: chuva mais alta (%.1f dB)" % _meteoro._som_chuva.volume_db, is_equal_approx(_meteoro._som_chuva.volume_db, -18.0), "")
	_meteoro.limpar_raios()
	_meteoro.definir_clima(E.NEVE_LEVE)
	await create_timer(1.7).timeout
	_verificar("sem chuva de novo: som para depois do fade", not _meteoro._som_chuva.playing, "")
	_meteoro.definir_clima(E.LIMPO, true)

# -----------------------------------------------------------------
# Evento TEMPESTADE na onda
# -----------------------------------------------------------------
func _testar_evento_tempestade() -> void:
	var E: Dictionary = Clima.Estado
	_est.definir_estacao(0, true)
	_gerenciador.onda_iniciada.emit(1)   # sorteia o clima base da onda
	var base: int = _meteoro.clima_base
	var tempestade := _evento("tempestade")
	_gerenciador._definir_evento(tempestade)
	_verificar("evento TEMPESTADE forca o clima TEMPESTADE (chuva forte + raios)", _meteoro.clima_atual == E.TEMPESTADE and _meteoro.tempestade_ativa, "clima=%d" % _meteoro.clima_atual)
	await create_timer(0.2).timeout
	_verificar("HUD mostra TEMPESTADE como os outros eventos", _hud.rotulo_evento.visible and _hud.rotulo_evento.text == "TEMPESTADE" and _hud.rotulo_evento.modulate == tempestade["cor"], "texto=%s" % _hud.rotulo_evento.text)
	# o sorteio da onda durante o evento nao tira a tempestade
	_gerenciador.onda_iniciada.emit(1)
	_verificar("sorteio da onda nao derruba a tempestade", _meteoro.clima_atual == E.TEMPESTADE, "")
	_meteoro.criar_raio(Vector2(560, 100), 5.0)
	_verificar("raio criado fica ativo", _meteoro.raios_ativos() == 1, "")
	_gerenciador._encerrar_evento()
	_verificar("fim do evento: clima volta ao da onda", _meteoro.clima_atual == _meteoro.clima_base and not _meteoro.tempestade_ativa, "clima=%d base=%d" % [_meteoro.clima_atual, base])
	_verificar("fim do evento: raios e avisos apagados", _meteoro.raios_ativos() == 0, "n=%d" % _meteoro.raios_ativos())
	await _quadros(2)
	_verificar("fim do evento: indicador de aviso liberado", _contar_indicadores() == 0, "n=%d" % _contar_indicadores())
	_verificar("fim do evento: HUD esconde o indicador", not _hud.rotulo_evento.visible, "")
	_gerenciador.sinal_ondas_paradas.emit()

func _contar_indicadores() -> int:
	var n := 0
	var fila: Array[Node] = [_cena]
	while not fila.is_empty():
		var no: Node = fila.pop_back()
		if no.get_script() == IndicadorAtaqueScript and not no.is_queued_for_deletion():
			n += 1
		fila.append_array(no.get_children())
	return n

# -----------------------------------------------------------------
# Dano do raio: dentro do raio de 28 px sim, fora não
# -----------------------------------------------------------------
func _novo_slime(pos: Vector2) -> Node:
	var slime: Node = load("res://cenas/inimigos/slime.tscn").instantiate()
	_cena.add_child(slime)
	slime.global_position = pos
	slime.vida = 500
	slime.velocidade = 0
	slime.add_to_group("enemy")
	return slime

func _limpar_slimes() -> void:
	for inimigo in get_nodes_in_group("enemy"):
		if is_instance_valid(inimigo):
			inimigo.free()

func _testar_dano_do_raio() -> void:
	_limpar_slimes()
	_gerenciador.onda_atual = 1
	_est.definir_estacao(0, true)
	_meteoro.definir_clima(Clima.Estado.TEMPESTADE, true)
	_meteoro._cronometro_raio = 1000.0
	_jogador.global_position = Vector2(560, 232)
	_jogador.invulneravel = false
	_jogador.estaMorto = false
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo
	await _quadros(3)
	var alvo := Vector2(400, 300)
	var dentro := _novo_slime(alvo + Vector2(12, 8))
	var na_borda := _novo_slime(alvo + Vector2(-26, 0))
	var fora := _novo_slime(alvo + Vector2(45, 0))
	var longe := _novo_slime(alvo + Vector2(0, -90))
	var vida_inicial := 500
	var raio: Node2D = _meteoro.criar_raio(alvo, 5.0)
	_verificar("raio: dano de inimigo cresce com a onda e e moderado (onda 1 = %d)" % raio.dano_inimigo, raio.dano_inimigo == Raio.dano_para_inimigo(1.0) and raio.dano_inimigo >= 10 and raio.dano_inimigo <= 40, "")
	_verificar("raio: dano do jogador cresce com a onda (onda 1 = %d)" % raio.dano_jogador, raio.dano_jogador == Raio.dano_para_jogador(1.0) and Raio.dano_para_jogador(20.0) > Raio.dano_para_jogador(1.0) and raio.dano_jogador < _jogador.estatisticas.hp_maximo / 3, "")
	_verificar("raio: antes do tempo so o aviso (nao caiu, sem dano)", not raio.caiu and dentro.vida == vida_inicial, "")
	raio.cair()
	await _quadros(2)
	_verificar("raio: inimigo dentro do raio leva dano", dentro.vida == vida_inicial - raio.dano_inimigo, "vida=%d" % dentro.vida)
	_verificar("raio: inimigo na borda (26 px) leva dano", na_borda.vida == vida_inicial - raio.dano_inimigo, "vida=%d" % na_borda.vida)
	_verificar("raio: inimigo fora (45 px) nao leva dano", fora.vida == vida_inicial, "vida=%d" % fora.vida)
	_verificar("raio: inimigo longe nao leva dano", longe.vida == vida_inicial, "vida=%d" % longe.vida)
	_verificar("raio: contou 2 inimigos atingidos e nao o jogador", raio.atingidos_inimigos == 2 and not raio.atingiu_jogador, "n=%d" % raio.atingidos_inimigos)
	_verificar("raio: jogador longe continua com a vida cheia", _jogador.hp_atual == _jogador.estatisticas.hp_maximo, "")
	# jogador dentro do raio (a area e no chao: vale a distancia dos pes)
	_limpar_slimes()
	var pes: Vector2 = _jogador.global_position + Vector2(0, 11)
	var hp0: int = _jogador.hp_atual
	var raio2: Node2D = _meteoro.criar_raio(pes + Vector2(14, 6), 5.0)
	raio2.cair()
	await _quadros(2)
	_verificar("raio: jogador dentro do raio leva dano (%d -> %d)" % [hp0, _jogador.hp_atual], raio2.atingiu_jogador and _jogador.hp_atual < hp0 and hp0 - _jogador.hp_atual >= 1, "")
	_verificar("raio: dano ao jogador respeita a reducao de dano (nunca passa do bruto)", hp0 - _jogador.hp_atual <= raio2.dano_jogador, "")
	# fora do raio: 60 px dos pes
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo
	var raio3: Node2D = _meteoro.criar_raio(pes + Vector2(60, 0), 5.0)
	raio3.cair()
	await _quadros(2)
	_verificar("raio: jogador fora do raio (60 px) nao leva dano", not raio3.atingiu_jogador and _jogador.hp_atual == _jogador.estatisticas.hp_maximo, "hp=%d" % _jogador.hp_atual)
	# invulneravel (dash, depois de um golpe): o raio nao fere
	_jogador.invulneravel = true
	var raio4: Node2D = _meteoro.criar_raio(pes, 5.0)
	raio4.cair()
	await _quadros(2)
	_verificar("raio: jogador invulneravel (dash) nao leva dano", _jogador.hp_atual == _jogador.estatisticas.hp_maximo, "hp=%d" % _jogador.hp_atual)
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	# efeitos: clarao, sons e tremor de camera
	var camera: Camera2D = _jogador.get_node("Camera2D")
	var raio5: Node2D = _meteoro.criar_raio(pes + Vector2(200, 0), 5.0)
	raio5.cair()
	await _quadros(1)
	_verificar("raio: clarao branco na tela inteira", _meteoro._flash.color.a > 0.5 and _meteoro._flash.color.r == 1.0 and _meteoro._flash.get_global_rect().size.x > 100.0, "a=%f" % _meteoro._flash.color.a)
	var tremeu := false
	for i in 20:
		await process_frame
		if camera.offset != Vector2.ZERO:
			tremeu = true
	_verificar("raio: tremor de camera", tremeu, "")
	await create_timer(0.9).timeout
	_verificar("raio: clarao some depois (fade)", _meteoro._flash.color.a < 0.01, "a=%f" % _meteoro._flash.color.a)
	_verificar("raio: o raio e o indicador se removem sozinhos", _meteoro.raios_ativos() == 0 and _contar_indicadores() == 0, "raios=%d" % _meteoro.raios_ativos())
	_verificar("raio: camera volta ao lugar", camera.offset == Vector2.ZERO, "%s" % camera.offset)
	_limpar_slimes()
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo
	_meteoro.definir_clima(Clima.Estado.LIMPO, true)

# -----------------------------------------------------------------
# O raio cai exatamente onde o indicador avisou
# -----------------------------------------------------------------
func _testar_alinhamento_do_raio() -> void:
	_meteoro.definir_clima(Clima.Estado.TEMPESTADE, true)
	_meteoro._cronometro_raio = 1000.0
	_jogador.global_position = Vector2(560, 232)
	await _quadros(2)
	var alvo := Vector2(430.0, 280.0)
	var raio: Node2D = _meteoro.criar_raio(alvo, 0.3)
	await _quadros(3)
	_verificar("aviso: indicador de ataque no ponto do raio, antes da queda", is_instance_valid(raio._indicador) and raio._indicador.global_position == alvo and is_equal_approx(raio._indicador.raio, 28.0) and not raio.caiu, "")
	await create_timer(0.45).timeout
	_verificar("o raio caiu depois do aviso", raio.caiu, "")
	# visuais: duas variacoes (A/B); coluna centrada no alvo e base do clarao no alvo
	var visuais: Array = raio.get_children().filter(func(n): return n is Node2D and n.top_level and n.get_child_count() == 2)
	_verificar("raio: duas variacoes de sprite alternando", visuais.size() == 2, "n=%d" % visuais.size())
	var alinhado := true
	var detalhe := ""
	for v in visuais:
		var coluna := v.get_child(0) as TextureRect
		var base := v.get_child(1) as Sprite2D
		var centro_x: float = coluna.position.x + coluna.size.x / 2.0
		var base_y: float = base.position.y + 48.0 - raio.AJUSTE_BASE
		var topo_coluna: float = coluna.position.y
		if not (is_equal_approx(centro_x, alvo.x) and is_equal_approx(base.position.x + 16.0, alvo.x) and is_equal_approx(base_y, alvo.y)):
			alinhado = false
			detalhe += " centro_x=%f base_y=%f" % [centro_x, base_y]
		# a coluna sobe ate acima do topo da tela e emenda na base (sem vao)
		var visivel: Rect2 = _meteoro.retangulo_visivel()
		if not (is_equal_approx(coluna.position.y + coluna.size.y, base.position.y) and topo_coluna <= visivel.position.y):
			alinhado = false
			detalhe += " topo=%f emenda=%f" % [topo_coluna, coluna.position.y + coluna.size.y - base.position.y]
	_verificar("raio: sprite alinhado ao ponto do indicador (x, base) e vindo do topo da tela", alinhado, detalhe)
	await create_timer(0.8).timeout
	_meteoro.definir_clima(Clima.Estado.LIMPO, true)

# -----------------------------------------------------------------
# Cadência: um raio a cada 2,5 a 4 s durante a tempestade
# -----------------------------------------------------------------
func _testar_cadencia_dos_raios() -> void:
	_limpar_slimes()
	_jogador.global_position = Vector2(560, 232)
	_jogador.invulneravel = true   # o objetivo aqui e so a cadencia; nao deixa o jogador morrer
	_jogador.estaMorto = false
	var instantes: Array[float] = []
	var pontos: Array[Vector2] = []
	var guardar := func(r: Node2D):
		instantes.append(Time.get_ticks_msec() / 1000.0)
		pontos.append(r.global_position)
	_meteoro.raio_criado.connect(guardar)
	_meteoro.raios_criados = 0
	_meteoro.definir_clima(Clima.Estado.TEMPESTADE, true)
	await create_timer(17.0).timeout
	_meteoro.raio_criado.disconnect(guardar)
	var intervalos_ok := instantes.size() >= 4
	var texto := ""
	for i in range(1, instantes.size()):
		var d := instantes[i] - instantes[i - 1]
		texto += " %.2f" % d
		if d < 2.4 or d > 4.2:
			intervalos_ok = false
	_verificar("raios a cada 2,5-4 s: %d raios em 17 s, intervalos%s" % [instantes.size(), texto], intervalos_ok, "")
	var perto_jogador := 0
	var pes: Vector2 = _jogador.global_position + Vector2(0, 11)
	for p in pontos:
		if p.distance_to(pes) <= 95.0:
			perto_jogador += 1
	_verificar("raios caem perto do jogador (%d de %d)" % [perto_jogador, pontos.size()], perto_jogador >= 1, "")
	# com inimigos em campo, parte dos raios cai perto deles
	var slime := _novo_slime(Vector2(380, 330))
	var perto_inimigo := 0
	_meteoro._rng.seed = 5
	for i in 60:
		var p: Vector2 = _meteoro.sortear_ponto_raio()
		if p.distance_to(slime.global_position) <= 14.5:
			perto_inimigo += 1
	_verificar("com inimigo em campo, uns %d de 60 sorteios caem em cima dele (~metade)" % perto_inimigo, perto_inimigo >= 15 and perto_inimigo <= 45, "")
	_limpar_slimes()
	_meteoro.limpar_raios()
	_meteoro.definir_clima(Clima.Estado.LIMPO, true)
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0

# -----------------------------------------------------------------
# parar_ondas limpa raios e indicadores
# -----------------------------------------------------------------
func _testar_limpeza() -> void:
	_limpar_slimes()
	_jogador.invulneravel = false
	_gerenciador._definir_evento(_evento("tempestade"))
	_meteoro._cronometro_raio = 1000.0
	_meteoro.criar_raio(Vector2(450, 300), 5.0)
	_meteoro.criar_raio(Vector2(520, 320), 5.0)
	var caido: Node2D = _meteoro.criar_raio(Vector2(480, 340), 5.0)
	caido.cair()
	await _quadros(2)
	_verificar("antes de parar: 3 raios e indicadores existem", _meteoro.raios_ativos() == 3 and _contar_indicadores() >= 2 and get_nodes_in_group("raios_clima").size() == 3, "raios=%d ind=%d" % [_meteoro.raios_ativos(), _contar_indicadores()])
	_verificar("antes de parar: tempestade ativa", _meteoro.clima_atual == Clima.Estado.TEMPESTADE, "")
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	await _quadros(2)
	_verificar("parar_ondas limpa os raios", _meteoro.raios_ativos() == 0 and get_nodes_in_group("raios_clima").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).is_empty(), "raios=%d" % _meteoro.raios_ativos())
	_verificar("parar_ondas limpa os indicadores de aviso", _contar_indicadores() == 0, "ind=%d" % _contar_indicadores())
	_verificar("parar_ondas desfaz a tempestade e o evento", _meteoro.clima_atual != Clima.Estado.TEMPESTADE and not _meteoro.tempestade_ativa and _gerenciador.evento_atual.is_empty(), "clima=%d" % _meteoro.clima_atual)
	_verificar("parar_ondas: volta ao clima do mundo", _meteoro.clima_atual == Clima.clima_do_mundo(_est.estacao_atual), "clima=%d" % _meteoro.clima_atual)
	# nenhum raio novo depois de parar
	await create_timer(5.0).timeout
	_verificar("sem tempestade nao ha raios novos", _meteoro.raios_ativos() == 0, "")

# -----------------------------------------------------------------
# Onda de verdade: o evento sorteado ativa o clima e os raios
# -----------------------------------------------------------------
func _testar_tempestade_em_onda_de_verdade() -> void:
	_limpar_slimes()
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	_progresso.iniciar_partida()
	_gerenciador.chance_evento = 1.0
	_gerenciador.chance_onda_bonus = 0.0
	_gerenciador.onda_atual = 5
	_gerenciador._id_evento_anterior = ""
	# Escolhe a semente do sorteio do gerenciador que, na onda 5 (primavera), traz a TEMPESTADE: o resto e a onda de verdade
	var teste_rng := RandomNumberGenerator.new()
	var semente := 0
	for s in 200:
		teste_rng.seed = s
		if Gerenciador.sortear_evento(5, false, false, "", teste_rng, 1.0, 0).get("id", "") == "tempestade":
			semente = s
			break
	_gerenciador._rng.seed = semente
	var moedas0: int = root.get_node("DadosJogo").moedas
	_gerenciador._resto_saque = 0.0
	_gerenciador.iniciar_onda()
	_verificar("onda de verdade: o sorteio do gerenciador trouxe TEMPESTADE (onda 5, primavera)", _gerenciador.evento_atual.get("id", "") == "tempestade", str(_gerenciador.evento_atual.get("id", "-")))
	_verificar("onda de verdade: clima TEMPESTADE e HUD", _meteoro.clima_atual == Clima.Estado.TEMPESTADE and _hud.rotulo_evento.text == "TEMPESTADE", "clima=%d" % _meteoro.clima_atual)
	_verificar("tempestade na arena = chuva forte no mundo (fazenda)", root.get_node("Fazenda").clima_hoje == Clima.Estado.CHUVA_FORTE, "fazenda=%d" % root.get_node("Fazenda").clima_hoje)
	var total: int = _gerenciador.total_inimigos_onda
	_meteoro.raios_criados = 0
	# durante 6 s a onda segue: o jogador fica de pe (o objetivo e ver os raios caindo) e os inimigos vivos
	for i in 24:
		_jogador.hp_atual = _jogador.estatisticas.hp_maximo
		await create_timer(0.25).timeout
	_verificar("onda de verdade: raios comecam a cair (%d em 6 s)" % _meteoro.raios_criados, _meteoro.raios_criados >= 1, "")
	# derruba tudo ate a onda acabar
	var t := 0.0
	while _gerenciador.onda_em_andamento and t < 60.0:
		_jogador.hp_atual = _jogador.estatisticas.hp_maximo
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and not inimigo.esta_morto:
				inimigo.receber_dano(99999, Vector2.ZERO)
		await create_timer(0.25).timeout
		t += 0.25
	await _quadros(3)
	_verificar("onda de verdade: a onda terminou", not _gerenciador.onda_em_andamento, "")
	var ganho: int = root.get_node("DadosJogo").moedas - moedas0
	var esperado := int(total * 4 * 1.4 + 0.0001) + roundi(_gerenciador.ouro_fim_onda(5) * 1.4)
	_verificar("onda de verdade: ouro x1,4 (%d inimigos: ganho %d, esperado ~%d)" % [total, ganho, esperado], absi(ganho - esperado) <= 2, "")
	_verificar("onda de verdade: fim da onda desfaz tempestade, raios e indicadores", _meteoro.clima_atual != Clima.Estado.TEMPESTADE and _meteoro.raios_ativos() == 0 and _contar_indicadores() == 0 and _gerenciador.evento_atual.is_empty(), "clima=%d" % _meteoro.clima_atual)
	_gerenciador.chance_evento = 0.0
	_gerenciador.parar_ondas()
	_gerenciador.ondas_paradas = false
	_limpar_slimes()

# -----------------------------------------------------------------
# Tela de título: neve leve fixa, sem partículas de neve
# -----------------------------------------------------------------
func _testar_tela_de_titulo() -> void:
	var titulo: Node = load("res://cenas/inicio_do_jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	await _quadros(10)
	await create_timer(1.8).timeout
	var est: Node = titulo.get_node("Cenario/Estacoes")
	var meteoro: Node = est.meteorologia
	_verificar("titulo: inverno com NEVE_LEVE fixa", est.estacao_atual == 3 and meteoro.clima_atual == Clima.Estado.NEVE_LEVE and meteoro.clima_base == Clima.Estado.NEVE_LEVE, "clima=%d" % meteoro.clima_atual)
	var alfas: Array = meteoro._camadas.map(func(c): return snappedf(c.alfa, 0.01))
	_verificar("titulo: so a camada de neve leve visivel", alfas == [0.0, 0.0, 0.0, 1.0], str(alfas))
	_verificar("titulo: sem raios nem chuva", meteoro.raios_ativos() == 0 and not meteoro._som_chuva.playing, "")
	_verificar("titulo: as particulas de neve antigas nao existem mais", titulo.get_node_or_null("Neve") == null and get_nodes_in_group("clima_neve").is_empty(), "")
	await create_timer(3.0).timeout
	_verificar("titulo: continua NEVE_LEVE", meteoro.clima_atual == Clima.Estado.NEVE_LEVE, "")
	titulo.queue_free()
	await _quadros(2)
