extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 12) -> void:
	for i in n: await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",mensagem)
func conferir(zona: Node) -> void:
	verificar(zona._aviso.texture == null and zona._aviso.scale == Vector2.ONE,"sem moldura antiga: "+zona.name)
	verificar(zona._rotulo_tecla.size == Vector2(18,18),"circulo compacto: "+zona.name)
	verificar(zona._rotulo_tecla.get_theme_stylebox("normal") is StyleBoxFlat,"circulo preservado pelo acabamento global")
	verificar(not zona._rotulo_tecla.has_meta("arte_acabamento"),"sem pergaminho sobre o circulo")
	verificar(zona._rotulo_tecla.get_theme_color("font_color").get_luminance() > 0.8,"letra clara")
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await esperar(50)
	var controle = root.get_node("Controle")
	var bigorna = current_scene.get_node("Bigorna")
	var npc = current_scene.moradores["ferreiro"]
	var zona: Node
	for filho in npc.get_children():
		if filho.get_script() == load("res://codigo/cidade/interacao_morador.gd"): zona = filho
	verificar(zona != null,"aviso do ferreiro encontrado")
	if zona == null: quit(1); return
	for toque in [false,true]:
		controle.usando_toque = toque
		for aviso in [bigorna,zona]:
			aviso._atualizar_tecla()
		await esperar()
		for aviso in [bigorna,zona]:
			conferir(aviso)
			verificar(aviso._icone_tecla.visible == toque,"glifo acompanha toque")
	controle.usando_toque = false
	zona._atualizar_tecla()
	bigorna._atualizar_tecla()
	var jogador = current_scene.get_node("Jogador")
	npc.set_process(false)
	npc.set_physics_process(false)
	npc.show()
	npc.global_position = jogador.global_position + Vector2(20,-8)
	zona.set_process(false)
	zona._aviso.show()
	await esperar()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-aviso-morador.png")
	print("AVISOS DE INTERACAO: ",falhas," falhas")
	quit(1 if falhas else 0)
