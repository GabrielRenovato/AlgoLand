extends SceneTree

var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await quadros()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/interface_bosque/"+nome+".png")
func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Cidade").missoes.clear()
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").definir_clima_hoje(2)
	root.get_node("Transicao").hora_salva = 12.0
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute("res://arte/previas/interface_bosque")
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var vila: Node = current_scene
	var jogador: Node2D = vila.get_node("Jogador")
	jogador.position = Vector2(336,272)
	jogador.camera.position_smoothing_enabled = false
	for npc in vila.moradores.values():
		npc.calar()
		npc.set_physics_process(false)
	var caio: Node2D = vila.moradores["bardo"]
	caio.position = Vector2(340,258)
	caio.show()
	caio.dormindo = false
	caio.dizer("CAIO:\nBoa ideia. Quero guardar minhas coisas num lugar seco antes que a chuva aperte.",60)
	await quadros(20)
	verificar("balao fica acima da chuva",caio._balao.z_index > 1001)
	verificar("balao preserva largura legivel",caio._balao.size.x <= 144 and caio._balao.size.y < 100)
	await foto("balao_chuva_pc")
	caio.calar()
	var ui: Node = vila.get_node("Interface")
	ui._abrir_tela("mural_cidade")
	await quadros()
	var mural: Control = ui._telas["mural_cidade"]
	verificar("pedidos aparecem antes da agenda",mural._aba_mural == 0 and mural._lista.get_child(1).name.begins_with("Pedido_"))
	verificar("mural PC cabe na tela",mural.painel.get_global_rect().position.y >= 0 and mural.painel.size.y <= mural.size.y)
	await foto("mural_pedidos_pc")
	mural._botoes[0].pressed.emit()
	await quadros()
	verificar("aceitar pelo cartao atualiza o pedido",root.get_node("Cidade").missoes.size() == 1 and mural._aviso == "Pedido aceito.")
	await foto("mural_aceito_pc")
	mural._abas_mural[1].pressed.emit()
	await quadros()
	verificar("agenda fica em aba propria",mural._aba_mural == 1 and mural._abas_mural[1].button_pressed and not mural._abas_mural[0].button_pressed and mural._botoes.is_empty() and mural._lista.get_child_count() >= 8)
	await foto("mural_agenda_pc")
	mural._abas_mural[0].pressed.emit()
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros(20)
	verificar("mural mobile cabe na tela",mural.painel.get_global_rect().position.y >= 0 and mural.painel.size.x <= mural.size.x and mural.painel.size.y <= mural.size.y)
	await foto("mural_pedidos_mobile")
	var barra: VScrollBar = mural._rolagem.get_v_scroll_bar()
	barra.value = barra.max_value
	await foto("mural_mobile_rolado")
	verificar("lista mobile permite chegar ao fim",barra.value > 0)
	ui._fechar_tela("mural_cidade")
	caio.dizer("CAIO:\nBoa ideia. Quero guardar minhas coisas num lugar seco antes que a chuva aperte.",60)
	await foto("balao_chuva_mobile")
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Saves").trocar("coop")
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(25)
	var ui2: Node = root.get_node("Cooperativo").interface_p2()
	ui2._abrir_tela("mural_cidade")
	await quadros()
	mural = ui2._telas["mural_cidade"]
	verificar("mural coop respeita viewport do jogador",mural.painel.size.x <= mural.size.x and mural.painel.size.y <= mural.size.y)
	await foto("mural_coop")
	print("Mural e baloes: %d falhas" % falhas)
	quit(falhas)
