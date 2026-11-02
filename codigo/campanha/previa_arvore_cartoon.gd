extends SceneTree
## Prancha de revisão do modelo real, em projeto com save isolado.
func _initialize() -> void:
	_renderizar.call_deferred()

func _renderizar() -> void:
	root.size = Vector2i(900,900)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var fabrica := preload("res://codigo/campanha/modelo_natureza_bacia_3d.gd").new()
	mundo.add_child(fabrica.criar("carvalho",0))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(0,31.8,30)
	mundo.add_child(camera)
	camera.look_at(Vector3(0,1.8,0))
	camera.current = true
	var ambiente := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("e8ebe3")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9bb8cb")
	e.ambient_light_energy = .52
	ambiente.environment = e
	mundo.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52,-35,0)
	sol.light_color = Color("ffe4b5")
	sol.light_energy = .82
	sol.shadow_enabled = true
	mundo.add_child(sol)
	var pasta := "res://arte/previas/campanha/natureza_bacia_3d/arvore-cartoon-modelo"
	DirAccess.make_dir_recursive_absolute(pasta)
	await create_timer(.5).timeout
	for i in 4:
		fabrica.definir_estacao(i)
		for quadro in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta.path_join("arvore-%d.png" % i))
	quit()
