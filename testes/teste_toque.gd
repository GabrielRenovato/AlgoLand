extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_toque.gd
# Controles na tela do celular (Codigos/UI/controles_toque.gd): joystick flutuante, botões que mandam as ações do jogo, multitoque,
# sumir com uma tela aberta, o toque (clique emulado do mouse) não ataca, e os rótulos das dicas.
# ATENCAO: carrega a cena de jogo e equipa itens (grava user://inventario.json); faça backup do user:// antes.

var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _controles: Node
var _ctl: Node
var _eventos: Node

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

func _toque(dedo: int, pos: Vector2, apertou: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = dedo
	ev.position = pos
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _arrasto(dedo: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = dedo
	ev.position = pos
	Input.parse_input_event(ev)

func _botao(acao: String) -> Dictionary:
	for b in _controles._botoes:
		if String(b["acao"]) == acao:
			return b
	return {}

func _rodar() -> void:
	await process_frame
	# Janela de 720x324 (celular comprido): sem escala, as posições do toque são as da tela do jogo
	root.size = Vector2i(720, 324)
	await process_frame
	var controle = root.get_node("Controle")
	_ctl = controle
	_eventos = root.get_node("EventosJogo")
	root.get_node("Progresso").caminho_save = "user://teste_toque_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_toque_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var inventario = root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	# Como se o jogo tivesse aberto em celular
	controle.usando_toque = true
	controle._tirar_mouse_das_acoes()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.3).timeout
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	for inimigo in get_nodes_in_group("enemy"):
		inimigo.queue_free()
	for filho in _cena.get_node("Interface").get_children():
		if filho.get_script() != null and String(filho.get_script().resource_path).ends_with("controles_toque.gd"):
			_controles = filho
	_verificar("a interface cria os controles na tela quando está em modo toque", _controles != null, "")
	if _controles == null:
		quit(1)
		return
	await _quadros(5)

	_verificar("o mouse saiu das ações de ataque e defesa (toque vira clique)", _tem_mouse("attack") == false and _tem_mouse("aparar") == false, "")
	_verificar("rótulos das dicas no toque", controle.rotulo_acao("open_menu") == "AGIR" and controle.rotulo_acao("usar_pocao") == "POÇÃO", controle.rotulo_acao("open_menu"))

	# --- posições: tudo dentro da tela e sem botões sobrepostos
	var tam: Vector2 = _controles._tamanho
	var dentro := true
	var sobrepoe := false
	var lista: Array = _controles._botoes
	for i in lista.size():
		var c: Vector2 = lista[i]["centro"]
		var r: float = lista[i]["raio"]
		dentro = dentro and c.x - r >= 0.0 and c.y - r >= 0.0 and c.x + r <= tam.x and c.y + r <= tam.y
		for j in range(i + 1, lista.size()):
			if c.distance_to(lista[j]["centro"]) < r + float(lista[j]["raio"]):
				sobrepoe = true
				print("  sobreposto: ", lista[i]["acao"], " x ", lista[j]["acao"])
	_verificar("todos os botões cabem na tela", dentro, "tela=%s" % tam)
	_verificar("nenhum botão encosta em outro", not sobrepoe, "")

	# --- joystick flutuante
	var x0: float = _jogador.global_position.x
	_toque(0, Vector2(80, 250), true)
	_arrasto(0, Vector2(120, 250))
	await _fisica(2)
	_verificar("joystick: puxar para a direita manda o vetor para a direita", _ctl.vetor_toque.x > 0.9 and absf(_ctl.vetor_toque.y) < 0.05, str(_ctl.vetor_toque))
	await create_timer(0.5).timeout
	_verificar("o jogador anda para a direita", _jogador.global_position.x > x0 + 5.0, "x %.1f -> %.1f" % [x0, _jogador.global_position.x])
	_arrasto(0, Vector2(100, 220))   # para cima e um pouco à direita (analógico: ângulo livre)
	await _fisica(2)
	_verificar("direção livre (diagonal), não só 4 ou 8 direções", _ctl.vetor_toque.y < -0.5 and _ctl.vetor_toque.x > 0.1 and _ctl.vetor_toque.x < 0.9, str(_ctl.vetor_toque))
	_arrasto(0, Vector2(83, 250))
	await _fisica(1)
	_verificar("dentro da zona morta o joystick não anda", _ctl.vetor_toque == Vector2.ZERO, str(_ctl.vetor_toque))
	_arrasto(0, Vector2(300, 250))
	await _fisica(1)
	_verificar("passar do círculo: vetor limitado a 1 e a base acompanha o dedo", is_equal_approx(_ctl.vetor_toque.length(), 1.0) and _controles._base_joystick.x > 200.0, "%s base=%s" % [_ctl.vetor_toque, _controles._base_joystick])
	_toque(0, Vector2(300, 250), false)
	await _fisica(1)
	_verificar("soltar o dedo zera o joystick", _ctl.vetor_toque == Vector2.ZERO, "")

	# --- toque no lado direito (fora dos botões) não vira joystick
	_toque(5, Vector2(tam.x * 0.7, 60), true)
	_verificar("toque solto no lado direito não cria joystick", _controles._dedo_joystick == -1, "")
	_toque(5, Vector2(tam.x * 0.7, 60), false)

	# --- botões
	var ataque := _botao("attack")
	_toque(1, ataque["centro"], true)
	await _fisica(1)
	_verificar("botão ATACAR aperta a ação attack", Input.is_action_pressed("attack"), "")
	_toque(1, ataque["centro"], false)
	await _fisica(1)
	_verificar("soltar o dedo solta a ação", not Input.is_action_pressed("attack"), "")

	inventario.equipar(inventario.buscar_por_tipo("espada_basica"))
	inventario.equipar(inventario.buscar_por_tipo("escudo_basico"))
	await create_timer(0.5).timeout   # a pose de sacar a arma passa
	_toque(1, ataque["centro"], true)
	await _fisica(3)
	_verificar("tocar em ATACAR faz o jogador atacar", _jogador._esta_atacando, "")
	_toque(1, ataque["centro"], false)
	await create_timer(0.8).timeout

	# multitoque: anda e defende ao mesmo tempo
	var defesa := _botao("aparar")
	_toque(0, Vector2(70, 260), true)
	_arrasto(0, Vector2(100, 260))
	_toque(2, defesa["centro"], true)
	await _fisica(4)
	_verificar("multitoque: joystick e DEFESA ao mesmo tempo", _ctl.vetor_toque.x > 0.5 and Input.is_action_pressed("aparar"), "")
	_verificar("segurar DEFESA levanta a guarda", _jogador.defesa.em_guarda(), "estado=%d" % _jogador.defesa.estado)
	_toque(2, defesa["centro"], false)
	_toque(0, Vector2(100, 260), false)
	await _fisica(3)

	# arrastar o dedo para fora do botão continua apertado até soltar
	var rolar := _botao("rolar")
	_toque(3, rolar["centro"], true)
	_arrasto(3, rolar["centro"] + Vector2(-80, -80))
	await _fisica(2)
	_verificar("o dedo que saiu do botão ainda o mantém apertado", rolar["apertado"], "")
	_toque(3, rolar["centro"] + Vector2(-80, -80), false)
	await _fisica(2)
	_verificar("soltar larga o botão", not rolar["apertado"], "")

	# --- clique emulado do mouse (o toque vira clique para os menus) não ataca
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	clique.position = Vector2(300, 100)
	Input.parse_input_event(clique)
	await _fisica(1)
	_verificar("clique do mouse (toque emulado) não faz o jogador atacar", not Input.is_action_pressed("attack"), "")
	clique.pressed = false
	Input.parse_input_event(clique)

	# --- fazenda: USAR no lugar de ATACAR, sem DEFESA nem POÇÃO
	_jogador.modo_fazenda = true
	await create_timer(0.35).timeout
	_verificar("na fazenda o botão grande vira USAR", _botao("attack")["rotulo"] == "USAR", "")
	_verificar("na fazenda somem DEFESA e POÇÃO", not _botao("aparar")["visivel"] and not _botao("usar_pocao")["visivel"] and _botao("open_menu")["visivel"], "")
	_toque(4, _botao("aparar")["centro"], true)
	_verificar("botão escondido não responde ao toque", not Input.is_action_pressed("aparar"), "")
	_toque(4, _botao("aparar")["centro"], false)
	_jogador.modo_fazenda = false
	await create_timer(0.35).timeout
	_verificar("de volta à arena: ATACAR, DEFESA e POÇÃO", _botao("attack")["rotulo"] == "ATACAR" and _botao("aparar")["visivel"] and _botao("usar_pocao")["visivel"], "")

	# --- tela aberta: os controles somem e soltam tudo
	_toque(0, Vector2(70, 260), true)
	_arrasto(0, Vector2(110, 260))
	_toque(1, ataque["centro"], true)
	await _fisica(2)
	_eventos.abrir_tela.emit("inventario")
	await _fisica(3)
	_verificar("com uma tela aberta os controles de jogo somem", not _controles._ativo and not _controles._tela.visible, "")
	_verificar("e soltam o joystick e os botões", _ctl.vetor_toque == Vector2.ZERO and not Input.is_action_pressed("attack"), "")
	_toque(6, ataque["centro"], true)
	await _fisica(1)
	_verificar("tela aberta: o toque no lugar do botão de ataque não ataca", not Input.is_action_pressed("attack"), "")
	_toque(6, ataque["centro"], false)
	_verificar("não existe mais o botão FECHAR flutuante", not _controles.has_method("_fechar_disponivel"), "")

	# --- o X da mochila (lateral da direita) vai para o lado esquerdo do título, com uma área de toque maior
	var interface: Node = _cena.get_node("Interface")
	var barra: Control = interface.get_node("TelaInventario/Sidebar")
	var x_mochila: Control = barra.get_node("BotaoFechar")
	var area_mochila: Button = barra.get_node_or_null("AreaFechar")
	_verificar("o X da mochila ficou no lado esquerdo da barra", x_mochila.get_global_rect().get_center().x < barra.get_global_rect().get_center().x
			and x_mochila.get_global_rect().position.x - barra.get_global_rect().position.x < 20.0, "x=%s barra=%s" % [x_mochila.get_global_rect(), barra.get_global_rect()])
	_verificar("com uma área de toque de 56x16 sobre o X", area_mochila != null and area_mochila.get_global_rect().size.x >= 56.0 and area_mochila.get_global_rect().size.y >= 16.0
			and area_mochila.get_global_rect().encloses(x_mochila.get_global_rect()), "")
	_verificar("o X não está mais no canto direito da tela", x_mochila.get_global_rect().end.x < tam.x - 100.0 or barra.get_global_rect().position.x > 0.0, "")
	_verificar("o toque na área do X fecha a mochila", interface._telas_abertas.has("inventario"), "")
	area_mochila.pressed.emit()
	await _fisica(4)
	_verificar("e ela fecha", not interface._telas_abertas.has("inventario"), str(interface._telas_abertas))
	_verificar("fechada a tela os controles de jogo voltam", _controles._ativo and _controles._tela.visible, "")
	# o caldeirão (também colado na direita) segue o mesmo caminho; a loja (na esquerda) mantém o X onde estava
	var x_caldeirao: Control = interface.get_node("TelaCaldeirao").find_child("BotaoFechar", true, false)
	_verificar("o X do caldeirão também vai para a esquerda, com área de toque", x_caldeirao.anchor_left == 0.0 and x_caldeirao.get_parent().get_node_or_null("AreaFechar") != null, "")
	var x_loja: Control = interface.get_node("TelaMercante").find_child("BotaoFechar", true, false)
	_verificar("o X da loja continua à direita do painel dela, com área de toque", x_loja.anchor_left >= 1.0 and x_loja.get_parent().get_node_or_null("AreaFechar") != null, "")
	# a tela obrigatória (fim de partida) segue sem como fechar de fora
	_eventos.abrir_tela.emit("fim_partida")
	await _fisica(3)
	_verificar("na tela de fim de partida os controles ficam escondidos", not _controles._ativo, "")
	_eventos.fechar_tela.emit("fim_partida")
	await _fisica(3)
	_toque(0, Vector2(110, 260), false)
	_toque(1, ataque["centro"], false)

	# --- fazenda: tocar nas casas da barra de ferramentas escolhe a ferramenta (sem Q/E) e o toque nela não vira joystick
	_cena.queue_free()
	await _quadros(3)
	var fazenda_dados = root.get_node("Fazenda")
	fazenda_dados.ferramenta = "enxada"
	_cena = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.3).timeout
	_controles = null
	for filho in _cena.get_node("Interface").get_children():
		if filho.get_script() != null and String(filho.get_script().resource_path).ends_with("controles_toque.gd"):
			_controles = filho
	var casas := get_nodes_in_group("toque_hud")
	_verificar("a barra de ferramentas tem casas tocáveis (enxada, regador, mão)", casas.size() >= 3, "casas=%d" % casas.size())
	var regador: Control = null
	for casa in casas:
		if String(casa.name) == "Casa_regador":
			regador = casa
	_verificar("existe a casa do regador", regador != null, "")
	if regador != null:
		_verificar("as casas crescem no toque (30 de lado)", regador.custom_minimum_size.x == 30.0, str(regador.custom_minimum_size))
		var centro := regador.get_global_rect().get_center()
		var clique_casa := InputEventMouseButton.new()
		clique_casa.button_index = MOUSE_BUTTON_LEFT
		clique_casa.pressed = true
		regador.gui_input.emit(clique_casa)
		_verificar("tocar na casa do regador escolhe o regador", fazenda_dados.ferramenta == "regador", fazenda_dados.ferramenta)
		await _quadros(2)   # a barra refaz as casas
		_toque(0, centro, true)
		await _fisica(2)
		_verificar("o toque sobre a barra não cria o joystick", _controles._dedo_joystick == -1, "centro=%s" % centro)
		_toque(0, centro, false)
		await _fisica(1)
		_verificar("o botão de ATACAR vira USAR na fazenda e os de arco não aparecem", _controles != null and not _botao("aparar")["visivel"], "")
	_verificar("não há mais botões < > (a barra do HUD faz esse papel)", _botao("ferramenta_anterior").is_empty() and _botao("ferramenta_proxima").is_empty(), "")

	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	print("--- teste_toque: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)

func _tem_mouse(acao: String) -> bool:
	for ev in InputMap.action_get_events(acao):
		if ev is InputEventMouseButton:
			return true
	return false
