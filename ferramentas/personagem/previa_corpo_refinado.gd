extends SceneTree

func _initialize() -> void:
	_rodar()

func quadros() -> void:
	for i in range(12):
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Transicao").hora_salva = 12
	var vila: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros()
	vila.get_node("Iluminacao").set_process(false)
	var jogador: Node = vila.get_node("Jogador")
	jogador.definir_aparencia(0,2)
	jogador.position = Vector2(392,350)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(392,320)
	for npc in vila.moradores.values():
		npc.set_physics_process(false)
		npc.visible = false
	var npc: Node = vila.moradores["mercador"]
	npc.visible = true
	npc.position = Vector2(352,352)
	npc.sprite.frame = 1
	npc.z_index = 352
	var hud: Node = get_nodes_in_group("hud")[0]
	if hud.get_node_or_null("MiniTutorial") != null:
		hud.get_node("MiniTutorial").set_process(false)
		hud.get_node("MiniTutorial").visible = false
	var pasta := ProjectSettings.globalize_path("res://arte/previas/personagens/refinado")
	DirAccess.make_dir_recursive_absolute(pasta)
	jogador.sprite_corpo.texture = load("res://assets/personagens/Body/body_1.png")
	jogador.sprite_corpo.scale = Vector2.ONE
	await quadros()
	root.get_texture().get_image().save_png(pasta+"/antes.png")
	var imagem := Image.load_from_file("res://assets/personagens/refinado/paginas/andar.png")
	jogador.sprite_corpo.texture = ImageTexture.create_from_image(imagem)
	jogador.sprite_corpo.scale = Vector2(0.5,0.5)
	await quadros()
	root.get_texture().get_image().save_png(pasta+"/depois.png")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit()
