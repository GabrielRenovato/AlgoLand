extends SceneTree
const SAIDA = "res://arte/previas/inimigos/goblin_molde_jogador/pixel_art/"
func _initialize(): rodar.call_deferred()
func rodar():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var vp = SubViewport.new()
	vp.size = Vector2i(160,160)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var modelo = load("res://assets/inimigos/goblin_molde_jogador/goblin.tscn").instantiate()
	vp.add_child(modelo)
	for instancia in modelo.find_children("*","MeshInstance3D",true,false):
		var mat = instancia.material_override
		if mat is ShaderMaterial:
			for parametro in ["luz_em_blocos","luz_dura"]:
				if mat.get_shader_parameter(parametro) != null: mat.set_shader_parameter(parametro,true)
	var ambiente = WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c5d1df")
	ambiente.environment.ambient_light_energy = .4
	vp.add_child(ambiente)
	for item in [[Vector3(-3,5,4),.8,Color("ffe4bb")],[Vector3(4,3,2),.35,Color("b8d3ff")]]:
		var luz = DirectionalLight3D.new()
		vp.add_child(luz)
		luz.position = item[0]
		luz.look_at(Vector3(0,.7,0))
		luz.light_energy = item[1]
		luz.light_color = item[2]
	var camera = Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(0,2.3,5)
	camera.look_at(Vector3(0,.72,0))
	var animador = modelo.find_children("*","AnimationPlayer",true,false)[0]
	animador.play("Idle_Loop")
	animador.advance(.1)
	animador.pause()
	var final = SubViewport.new()
	final.size = Vector2i(800,800)
	final.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(final)
	var fundo = ColorRect.new()
	fundo.size = Vector2(800,800)
	fundo.color = Color("35423c")
	final.add_child(fundo)
	var sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*5
	var material = ShaderMaterial.new()
	material.shader = load("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
	sprite.material = material
	final.add_child(sprite)
	for item in [["frente",0.0],["tres_quartos",PI*.18]]:
		modelo.rotation.y = item[1]
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(final.get_texture().get_image().save_png(SAIDA+item[0]+".png")==OK)
	print("GOBLIN_PIXEL_OK")
	quit()
