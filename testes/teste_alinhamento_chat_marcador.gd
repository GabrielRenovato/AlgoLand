extends SceneTree
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func conferir(condicao: bool, descricao: String) -> void:
	print("OK " if condicao else "FALHA ", descricao)
	if not condicao:
		falhas += 1

func rodar() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Transicao").hora_salva = 12
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(35)
	current_scene.get_node("Jogador").set_physics_process(false)
	var ui: Node = current_scene.get_node("Interface")
	var tela: Control = ui._telas.lobby
	var sessao: Node = tela._sessao
	# Estado local para inspecionar o campo, sem conectar ou enviar mensagens.
	sessao.set_process(false)
	sessao.online = true
	sessao.conectado = true
	sessao.eu = "teste"
	sessao.mensagens = [{"jogador":"teste", "apelido":"ALFEIM", "texto":"Mensagem longa para conferir a quebra e as margens do chat na cidade."}]
	tela._atualizar()
	for medida in [Vector2i(576,324), Vector2i(390,540), Vector2i(288,216)]:
		root.content_scale_size = medida
		root.size = medida * 2
		await quadros(15)
		var tamanho: Vector2 = tela.EscalaInterface.tamanho_logico(tela)
		var painel: Control = tela._historico
		conferir(painel.position.y + painel.size.y <= tamanho.y - 7.5, "chat respeita margem inferior em " + str(medida))
		var hud: Node = get_first_node_in_group("hud")
		var barra: Control = hud.barra_armas._painel
		var area_chat := painel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,painel.size)
		var area_barra := barra.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,barra.size)
		conferir(not area_chat.grow(3).intersects(area_barra), "chat não cobre a barra de itens em " + str(medida))
		var objetivo: Control = hud.get_node("ObjetivoPrincipal")
		var area_objetivo := objetivo.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,objetivo.size)
		conferir(not area_chat.grow(3).intersects(area_objetivo), "chat não cobre o objetivo principal")
		if medida.x == 576:
			conferir(is_equal_approx(painel.position.y + painel.size.y, tamanho.y - 8), "PC usa o espaço livre até o rodapé")
		conferir(Rect2(Vector2.ZERO,tamanho).encloses(Rect2(painel.position,painel.size)), "chat cabe na tela " + str(medida))
		var campo: LineEdit = tela._historico_campo
		conferir(campo.is_visible_in_tree() and campo.get_theme_stylebox("normal").get_margin(SIDE_LEFT) >= 12 and campo.get_theme_stylebox("normal").get_margin(SIDE_RIGHT) >= 12, "campo respeita a decoração nas duas laterais")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-alinhado-%dx%d.png" % [medida.x, medida.y])
	var npc: Node2D = current_scene.moradores.lia
	var marcador: Node2D = npc.get_node("IndicadorPedido")
	var vp := SubViewport.new()
	vp.size = Vector2i(40,40)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	for simbolo in ["?", "!"]:
		marcador._rotulo.text = simbolo
		marcador._centralizar_simbolo()
		var rotulo: Label = marcador._rotulo.duplicate()
		rotulo.text = simbolo
		rotulo.position = Vector2(10,10) + marcador._rotulo.position
		vp.add_child(rotulo)
		await quadros(2)
		await RenderingServer.frame_post_draw
		var imagem := vp.get_texture().get_image()
		var desenho := Rect2(imagem.get_used_rect())
		conferir(desenho.has_area() and absf(desenho.get_center().x - 19) <= 0.5 and absf(desenho.get_center().y - 19) <= 0.5, "desenho visível de " + simbolo + " centralizado no círculo")
		conferir(Rect2(12,12,14,14).encloses(desenho), "símbolo tem margem interna")
		rotulo.queue_free()
		await quadros(2)
	vp.queue_free()
	await quadros(2)
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Cooperativo").entrar(-2)
	await quadros(45)
	var coop: Node = root.get_node("Cooperativo")
	for lado in [1,2]:
		var vista: SubViewport = coop._vistas[lado]
		var interface: Node = vista.get_node("Interface" if lado == 1 else "InterfaceP2")
		var chat: Control = interface._telas.lobby._historico
		await quadros(5)
		var area_chat := chat.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,chat.size)
		for hud in get_nodes_in_group("hud"):
			if hud.get_viewport()!=vista:
				continue
			var barra: Control = hud.barra_armas._painel
			var area_barra := barra.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,barra.size)
			conferir(not area_chat.grow(3).intersects(area_barra), "chat não cobre inventário de P%d" % lado)
		conferir(Rect2(Vector2.ZERO,vista.get_visible_rect().size).encloses(area_chat), "chat cabe na metade de P%d" % lado)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-chat-alinhado-coop.png")
	print("Falhas: ", falhas)
	quit(1 if falhas else 0)
