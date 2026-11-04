extends SceneTree
## Prévia do modelo real, com iluminação e câmera do Godot; sem carregar partidas.
func _initialize() -> void:
	mostrar.call_deferred()

func mostrar() -> void:
	var documento := GLTFDocument.new()
	var estado := GLTFState.new()
	var origem := OS.get_environment("ALGOLAND_GOBLIN_CAPUZ")
	if origem.is_empty(): origem = ProjectSettings.globalize_path("res://assets/inimigos/goblin_capuz_3d/goblin_capuz.glb")
	if documento.append_from_file(origem, estado) != OK:
		push_error("Não foi possível abrir o goblin de capuz")
		quit(1)
		return
	var palco := Node3D.new()
	root.add_child(palco)
	var modelo := documento.generate_scene(estado)
	palco.add_child(modelo)
	assert(estado.json.get("animations", []).is_empty())
	assert(estado.json.get("skins", []).is_empty())
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("202827")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c5d1df")
	ambiente.environment.ambient_light_energy = .45
	palco.add_child(ambiente)
	for dados in [[Vector3(-3,5,4), Color("ffe4bb"), 1.0], [Vector3(4,3,2), Color("b8d3ff"), .45]]:
		var luz := DirectionalLight3D.new()
		palco.add_child(luz)
		luz.position = dados[0]
		luz.look_at(Vector3(0,.7,0))
		luz.light_color = dados[1]
		luz.light_energy = dados[2]
	var camera := Camera3D.new()
	palco.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(1.6,1.65,4.5)
	camera.look_at(Vector3(0,.72,0))
	camera.current = true
	root.size = Vector2i(900,1000)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var destino := origem.get_base_dir().path_join("../../../arte/previas/inimigos/goblin_capuz_3d/godot.png").simplify_path()
	var resultado := root.get_texture().get_image().save_png(destino)
	print("PREVIA_GOBLIN_CAPUZ ", resultado, " ", destino)
	for vista in [["frente",Vector3(0,1.5,5)],["perfil",Vector3(5,1.4,0)],["costas",Vector3(0,1.5,-5)]]:
		camera.position = vista[1]
		camera.look_at(Vector3(0,.75,0))
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destino.get_base_dir().path_join(vista[0]+".png")) == OK)
	quit(0 if resultado == OK else 1)
