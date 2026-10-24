extends SceneTree
const SAIDA = "res://arte/previas/personagens/raven_colheita/"
const TEMPOS = [0.12,0.14,0.18,0.12,0.16,0.18]
func _initialize(): rodar.call_deferred()
func esperar(n):
	for i in n: await process_frame
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(25)
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	var jogador=current_scene.get_node("Jogador")
	jogador.hide()
	var vp=SubViewport.new()
	vp.size=Vector2i(480,240)
	vp.world_2d=current_scene.get_world_2d()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var camera=Camera2D.new()
	camera.position=jogador.global_position+Vector2(0,-22)
	camera.zoom=Vector2(3,3)
	vp.add_child(camera)
	camera.make_current()
	var painel=CanvasLayer.new()
	vp.add_child(painel)
	for i in 2:
		var titulo=Label.new()
		titulo.text=["RAVEN ORIGINAL","COLHEITA - ESTUDO"][i]
		titulo.position=Vector2(18+i*240,12)
		titulo.add_theme_font_size_override("font_size",14)
		titulo.add_theme_color_override("font_shadow_color",Color.BLACK)
		titulo.add_theme_constant_override("shadow_offset_x",1)
		titulo.add_theme_constant_override("shadow_offset_y",1)
		painel.add_child(titulo)
	var atlas=ImageTexture.create_from_image(Image.load_from_file("res://assets/personagens/raven_fantasy/estudo_colheita/colheita_perfil.png"))
	var molde=Image.load_from_file("res://arte/fontes/personagens/raven_colheita/molde_perfil.png").get_region(Rect2i(0,0,512,512))
	molde.resize(64,64,Image.INTERPOLATE_NEAREST)
	var original=Image.create(80,80,false,Image.FORMAT_RGBA8)
	original.blit_rect(molde,Rect2i(0,0,64,64),Vector2i(8,8))
	var canonico=Sprite2D.new()
	canonico.texture=ImageTexture.create_from_image(original)
	canonico.centered=false
	canonico.offset=Vector2(-40,-57)
	canonico.position=jogador.global_position+Vector2(-40,0)
	current_scene.add_child(canonico)
	var estudo=AnimatedSprite2D.new()
	estudo.centered=false
	estudo.offset=Vector2(-40,-57)
	estudo.position=jogador.global_position+Vector2(40,0)
	estudo.process_mode=Node.PROCESS_MODE_ALWAYS
	var frames=SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("colher")
	frames.set_animation_loop("colher",false)
	frames.set_animation_speed("colher",50)
	for q in 6:
		var tex=AtlasTexture.new()
		tex.atlas=atlas
		tex.region=Rect2(q*80,0,80,80)
		frames.add_frame("colher",tex,TEMPOS[q]*50)
	estudo.sprite_frames=frames
	current_scene.add_child(estudo)
	var mat=CanvasItemMaterial.new()
	mat.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	canonico.material=mat
	estudo.material=mat
	await esperar(5)
	DirAccess.make_dir_recursive_absolute(SAIDA+"motor")
	estudo.play("colher")
	var vistos=[]
	for i in 70:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(SAIDA+"motor/%03d.png"%i)
		if not vistos.has(estudo.frame): vistos.append(estudo.frame)
		await process_frame
	assert(vistos==[0,1,2,3,4,5],"Todos os seis quadros devem aparecer na ordem")
	assert(not estudo.is_playing())
	print("OK reprodução Godot isolada: seis quadros,0.90s, sem repetir; pausa final0.5s na prévia")
	current_scene.queue_free()
	current_scene=null
	vp.queue_free()
	await esperar(3)
	quit()
