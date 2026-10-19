extends SceneTree

## Android simulado: P1 no toque e P2 no controle, usando as interfaces reais do coop.
var falhas := 0
var coop: Node
var eventos: Node
var controle: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func controles_de(interface: Node) -> Array[Node]:
	var lista: Array[Node] = []
	for filho in interface.get_children():
		if filho.get_script() != null and filho.get_script().resource_path == "res://codigo/ui/controles_toque.gd":
			lista.append(filho)
	return lista

func toque(vista: Viewport, posicao: Vector2, pressionado: bool, dedo := 1) -> void:
	var evento := InputEventScreenTouch.new()
	evento.index = dedo
	evento.position = vista.get_parent().get_global_transform() * vista.get_stretch_transform() * posicao
	evento.pressed = pressionado
	root.push_input(evento, true)
	Input.flush_buffered_events()

func botao(indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = 40
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(3)

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Execute pelo testar_coop.py com save isolado.")
		quit(1)
		return
	await process_frame
	controle = root.get_node("Controle")
	eventos = root.get_node("EventosJogo")
	coop = root.get_node("Cooperativo")
	controle.usando_toque = true
	controle._tirar_mouse_das_acoes()
	root.size = Vector2i(1440, 648)
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	coop.dispositivo_p1 = coop.SEM_CONTROLE
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	var interface: Node = eventos.interface_p1()
	var interface2: Node = coop.interface_p2()
	var lista := controles_de(interface)
	verificar("P1 recebe um conjunto de controles de toque", lista.size() == 1)
	verificar("P2 de controle não recebe joystick de toque duplicado", controles_de(interface2).is_empty())
	if lista.is_empty():
		quit(1)
		return
	var toque_ui: Node = lista[0]
	var vista: Viewport = interface.get_viewport()
	await create_timer(0.3).timeout
	# Dicas por dono: Android não deve apagar os botões do controle do parceiro.
	verificar("P1 vê rótulo de toque", controle.rotulo_acao("open_menu", interface) == "AGIR")
	verificar("P2 vê rótulo do controle", controle.rotulo_acao("ui_accept", interface2) == "A")
	verificar("fazenda oferece USAR e COLHER", toque_ui._botao_da_acao(&"attack").rotulo == "USAR" and toque_ui._botao_da_acao(&"colher").visivel)
	var botoes: Array = toque_ui._botoes
	var area := Rect2(Vector2.ZERO, toque_ui._tamanho)
	for i in botoes.size():
		var b: Dictionary = botoes[i]
		if not b.visivel:
			continue
		verificar("botão cabe na metade P1: " + str(b.acao), area.encloses(Rect2(b.centro - Vector2.ONE * b.raio, Vector2.ONE * b.raio * 2)))
		for j in range(i + 1, botoes.size()):
			if botoes[j].visivel:
				verificar("botões separados: %s/%s" % [b.acao, botoes[j].acao], b.centro.distance_to(botoes[j].centro) >= b.raio + botoes[j].raio)
	# Todos os botões visíveis de gameplay atravessam a entrada do viewport.
	for acao in [&"attack", &"rolar", &"colher", &"open_menu"]:
		var b: Dictionary = toque_ui._botao_da_acao(acao)
		toque(vista, b.centro, true)
		verificar("toque pressiona somente P1: " + str(acao), Input.is_action_pressed(acao) and not Input.is_action_pressed("p2_" + acao))
		toque(vista, b.centro, false)
		verificar("soltar limpa ação: " + str(acao), not Input.is_action_pressed(acao))
	# A mochila do parceiro não pode interromper o toque do P1.
	await botao(JOY_BUTTON_BACK)
	verificar("controle abre mochila somente em P2", interface2._telas_abertas.has("inventario") and interface._telas_abertas.is_empty())
	verificar("menu de P2 preserva toque de P1", toque_ui._ativo)
	await botao(JOY_BUTTON_B)
	await botao(JOY_BUTTON_START)
	await create_timer(0.3).timeout
	verificar("pausa global de P2 suspende o toque de P1", paused and not toque_ui._ativo)
	await botao(JOY_BUTTON_START)
	await create_timer(0.3).timeout
	verificar("despausar devolve toque ao P1", not paused and toque_ui._ativo)
	var itens: Dictionary = toque_ui._botao_da_acao(&"open_inventory")
	toque(vista, itens.centro, true)
	await quadros()
	toque(vista, itens.centro, false)
	verificar("ITENS abre mochila do P1", interface._telas_abertas.has("inventario"))
	verificar("mochila do P1 esconde e solta toque", not toque_ui._ativo and controle.vetor_toque == Vector2.ZERO and not Input.is_action_pressed("attack"))
	await create_timer(0.25).timeout
	var fechar: Button = interface._telas["inventario"].find_child("BotaoFechar", true, false)
	verificar("mochila tem área ampliada para fechar", fechar != null and fechar.size.x >= 28)
	# O clique emulado do Android segue a rota GUI, sem chamar o callback do botão.
	vista.notify_mouse_entered()
	var movimento := InputEventMouseMotion.new()
	movimento.position = vista.get_parent().get_global_transform() * vista.get_stretch_transform() * fechar.get_global_rect().get_center()
	root.push_input(movimento, true)
	await quadros(2)
	for pressionado in [true, false]:
		var clique := InputEventMouseButton.new()
		clique.position = movimento.position
		clique.button_index = MOUSE_BUTTON_LEFT
		clique.pressed = pressionado
		clique.global_position = clique.position
		clique.button_mask = MOUSE_BUTTON_MASK_LEFT if pressionado else 0
		root.push_input(clique, true)
		await quadros(2)
	verificar("toque no X fecha somente P1", interface._telas_abertas.is_empty() and interface2._telas_abertas.is_empty())
	verificar("fechar recupera comandos de toque", toque_ui._ativo)
	# Reviver depende da proximidade; ambos os personagens são reais.
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	p2._cair()
	p1.position = p2.position + Vector2(100, 0)
	coop._cuidar_dos_caidos(p1, p2, coop.TEMPO_REVIVER + 0.1)
	verificar("parceiro distante não revive", p2.caido)
	p1.position = p2.position + Vector2(12, 0)
	coop._cuidar_dos_caidos(p1, p2, coop.TEMPO_REVIVER + 0.1)
	verificar("parceiro próximo revive com vida", not p2.caido and not p2.estaMorto and p2.hp_atual > 0)
	coop.sair()
	await quadros()
	current_scene.queue_free()
	current_scene = null
	await quadros(6)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
