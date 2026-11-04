extends SceneTree
## Captura o GLB real em projeto isolado, sem autoloads ou saves.

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var origem := OS.get_environment("ALGOLAND_GOBLIN_MACHADO")
	if origem.is_empty():
		origem = ProjectSettings.globalize_path("res://assets/inimigos/goblin_machado_3d/goblin_machado.glb")
	var saida := OS.get_environment("ALGOLAND_GOBLIN_MACHADO_PREVIAS")
	if saida.is_empty():
		saida = ProjectSettings.globalize_path("res://arte/previas/inimigos/goblin_machado_3d")
	DirAccess.make_dir_recursive_absolute(saida)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	assert(doc.append_from_file(origem, estado) == OK)
	assert(estado.json.get("skins", []).is_empty())
	assert(estado.json.get("animations", []).is_empty())
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 1000)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var modelo := doc.generate_scene(estado)
	vp.add_child(modelo)
	for malha in modelo.find_children("*", "MeshInstance3D", true, false):
		for i in malha.mesh.get_surface_count():
			var mat = malha.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("bfbfba")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("b9c8d5")
	ambiente.environment.ambient_light_energy = .40
	vp.add_child(ambiente)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200,200)
	piso.mesh = plano
	piso.position.y = -.004
	var tinta_piso := StandardMaterial3D.new()
	tinta_piso.albedo_color = Color("b5b5af")
	tinta_piso.roughness = 1.0
	piso.material_override = tinta_piso
	vp.add_child(piso)
	for dados in [[Vector3(-3,5,4), Color("ffe3bb"), .95], [Vector3(4,3,1), Color("b8d3ff"), .42]]:
		var luz := DirectionalLight3D.new()
		vp.add_child(luz)
		luz.position = dados[0]
		luz.look_at(Vector3(0,.8,0))
		luz.light_color = dados[1]
		luz.light_energy = dados[2]
		luz.shadow_enabled = dados[2] > .5
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.05
	camera.current = true
	var vistas := [["frente",Vector3(0,1.75,5)], ["tres_quartos",Vector3(1.7,1.9,5)],
		["perfil",Vector3(5,1.65,0)], ["costas",Vector3(0,1.7,-5)]]
	for vista in vistas:
		camera.position = vista[1]
		camera.look_at(Vector3(-.15,.84,0))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(saida.path_join(vista[0]+"_pintura.png")) == OK)
	camera.size = 1.0
	for detalhe in [["empunhadura",Vector3(0,1.0,4)], ["empunhadura_lateral",Vector3(3,1.25,2.4)]]:
		camera.position = detalhe[1]
		camera.look_at(Vector3(0,.77,.36))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(saida.path_join(detalhe[0]+".png")) == OK)
	camera.size = 2.05
	if OS.get_cmdline_user_args().has("--pixel"):
		piso.visible = false
		vp.size = Vector2i(160,160)
		vp.transparent_bg = true
		ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
		RenderingServer.set_default_clear_color(Color.TRANSPARENT)
		var final := SubViewport.new()
		final.size = Vector2i(800,800)
		final.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(final)
		var fundo := ColorRect.new()
		fundo.size = Vector2(800,800)
		fundo.color = Color("c0bfba")
		final.add_child(fundo)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = vp.get_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE*5
		var shader: Shader
		if ResourceLoader.exists("res://contorno_pixel_base_3d.gdshader"):
			shader = load("res://contorno_pixel_base_3d.gdshader")
		else:
			shader = load("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
		assert(shader != null)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat
		final.add_child(sprite)
		for vista in vistas.slice(0,2):
			camera.position = vista[1]
			camera.look_at(Vector3(-.15,.84,0))
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			assert(final.get_texture().get_image().save_png(saida.path_join(vista[0]+"_filtro_pixel.png")) == OK)
	print("GOBLIN_MACHADO_PREVIAS_OK ", saida)
	quit(0)
