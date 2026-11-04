extends SceneTree
const SAIDA = "res://arte/previas/inimigos/goblin_capuz_3d/mixamo/"
func _initialize(): rodar.call_deferred()
func rodar():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var vp = SubViewport.new()
	vp.size = Vector2i(160,160)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var documento = GLTFDocument.new()
	var estado = GLTFState.new()
	assert(documento.append_from_file("res://assets/inimigos/goblin_capuz_3d/goblin_capuz_animado.glb",estado)==OK)
	var modelo = documento.generate_scene(estado)
	vp.add_child(modelo)
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
	camera.position = Vector3(0,1.65,5)
	camera.look_at(Vector3(0,.85,0))
	var final = SubViewport.new()
	final.size = Vector2i(160,160)
	final.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(final)
	var fundo = ColorRect.new()
	fundo.size = Vector2(160,160)
	fundo.color = Color("202827")
	final.add_child(fundo)
	var sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE
	var material = ShaderMaterial.new()
	material.shader = load("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
	sprite.material = material
	final.add_child(sprite)
	var animadores = modelo.find_children("*","AnimationPlayer",true,false)
	assert(animadores.size()==1)
	var animador: AnimationPlayer = animadores[0]
	var relatorio = []
	for nome in animador.get_animation_list():
		if nome=="RESET": continue
		var clipe = animador.get_animation(nome)
		assert(clipe.length>0)
		clipe.loop_mode = Animation.LOOP_LINEAR if nome in ["parado","correr","defesa"] else Animation.LOOP_NONE
		camera.size = 3.0
		var pasta = SAIDA+nome+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
		animador.play(nome)
		animador.pause()
		var quadros = maxi(2,ceili(clipe.length*30))
		modelo.rotation.y = PI*.12
		if "--vistas" in OS.get_cmdline_user_args():
			for direcao in 4:
				modelo.rotation.y = direcao*PI/2
				for q in 12:
					animador.seek(clipe.length*q/12.0,true)
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					verificar_margens(vp, nome)
					assert(final.get_texture().get_image().save_png(pasta+"vista_%d_%02d.png"%[direcao,q])==OK)
		else:
			for q in quadros:
				animador.seek(clipe.length*q/quadros,true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				verificar_margens(vp, nome)
				assert(final.get_texture().get_image().save_png(pasta+"%04d.png"%q)==OK)
		relatorio.append({"nome":nome,"duracao":clipe.length,"quadros":quadros})
		print("CAPTURA_MIXAMO ",nome," ",quadros)
	FileAccess.open(SAIDA+"revisao.json",FileAccess.WRITE).store_string(JSON.stringify(relatorio,"  "))
	# Reprodução contínua no motor, por dois ciclos completos da corrida.
	animador.play("correr")
	var duracao = animador.get_animation("correr").length
	var inicio = Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio < duracao*2000.0:
		await process_frame
	print("REPRODUCAO_CONTINUA_OK dois ciclos")
	quit()

func verificar_margens(vp: SubViewport, nome: String) -> void:
	var r := vp.get_texture().get_image().get_used_rect()
	assert(r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<vp.size.x and r.end.y<vp.size.y, "Personagem cortado: "+nome)
