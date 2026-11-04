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
	estado.bake_fps = 60
	assert(doc.append_from_file(origem, estado) == OK)
	assert(not estado.json.get("skins", []).is_empty())
	assert(not estado.json.get("animations", []).is_empty())
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

	vp.size = Vector2i(224,224)
	camera.size = 2.65
	camera.position = Vector3(1.7,1.9,5)
	if OS.get_environment("ALGOLAND_GOBLIN_VISTA") == "perfil": camera.position = Vector3(5,1.7,0)
	camera.look_at(Vector3(-.12,1.02,0))
	var animador: AnimationPlayer = modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var final := SubViewport.new()
	final.size = Vector2i(224,224)
	final.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(final)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load("res://contorno_pixel_base_3d.gdshader")
	sprite.material = mat
	final.add_child(sprite)
	for nome in animador.get_animation_list():
		if nome == "RESET": continue
		var animacao := animador.get_animation(nome)
		var pasta := saida.path_join(nome)
		DirAccess.make_dir_recursive_absolute(pasta)
		animador.play(nome)
		animador.pause()
		var total := roundi(animacao.length*30)
		for quadro in total:
			animador.seek(quadro/30.0,true)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(final.get_texture().get_image().save_png(pasta.path_join("%04d.png" % quadro)) == OK)
		print("CAPTURA_OK ",nome," ",total)
	if OS.get_cmdline_user_args().has("--reproduzir"):
		for nome in ["parado", "andar", "correr", "ataque_1", "ataque_2", "ferido", "morrer"]:
			var animacao := animador.get_animation(nome)
			var ciclo: bool = nome in ["parado", "andar", "correr"]
			animacao.loop_mode = Animation.LOOP_LINEAR if ciclo else Animation.LOOP_NONE
			animador.play(nome)
			await create_timer(animacao.length*(2.0 if ciclo else 1.0)).timeout
			print("REPRODUCAO_REAL_OK ",nome)
	print("GOBLIN_MACHADO_ANIMACAO_PREVIAS_OK")
	quit(0)
