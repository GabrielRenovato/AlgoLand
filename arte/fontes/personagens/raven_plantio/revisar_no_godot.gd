extends SceneTree
const SAIDA = "res://arte/previas/personagens/raven_plantio/"
const TEMPOS = [0.10,0.30,0.10,0.10,0.10,0.20]
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
		titulo.text=["MANA SEED ORIGINAL","RAVEN - ESTUDO"][i]
		titulo.position=Vector2(18+i*240,12)
		titulo.add_theme_font_size_override("font_size",14)
		titulo.add_theme_color_override("font_shadow_color",Color.BLACK)
		titulo.add_theme_constant_override("shadow_offset_x",1)
		titulo.add_theme_constant_override("shadow_offset_y",1)
		painel.add_child(titulo)
	var atlas=ImageTexture.create_from_image(Image.load_from_file("res://assets/personagens/raven_fantasy/estudo_plantio/plantio_perfil.png"))
	var guia=Image.load_from_file("res://arte/fontes/personagens/raven_plantio/poses_originais_mana_seed.png")
	var referencia=Image.create(480,80,false,Image.FORMAT_RGBA8)
	for q in 6:
		var pose=guia.get_region(Rect2i(q%3*512,q/3*512,512,512))
		pose.resize(64,64,Image.INTERPOLATE_NEAREST)
		referencia.blit_rect(pose,Rect2i(0,0,64,64),Vector2i(q*80+8,8))
	var canonico=AnimatedSprite2D.new()
	canonico.sprite_frames=quadros_da_folha(ImageTexture.create_from_image(referencia))
	canonico.centered=false
	canonico.offset=Vector2(-40,-57)
	canonico.position=jogador.global_position+Vector2(-40,0)
	canonico.process_mode=Node.PROCESS_MODE_ALWAYS
	current_scene.add_child(canonico)
	var estudo=AnimatedSprite2D.new()
	estudo.centered=false
	estudo.offset=Vector2(-40,-57)
	estudo.position=jogador.global_position+Vector2(40,0)
	estudo.process_mode=Node.PROCESS_MODE_ALWAYS
	estudo.sprite_frames=quadros_da_folha(atlas)
	current_scene.add_child(estudo)
	var mat=CanvasItemMaterial.new()
	mat.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	canonico.material=mat
	estudo.material=mat
	await esperar(5)
	DirAccess.make_dir_recursive_absolute(SAIDA+"motor")
	canonico.play("plantar")
	estudo.play("plantar")
	var vistos=[]
	for i in 70:
		await RenderingServer.frame_post_draw
		assert(canonico.frame==estudo.frame,"Referência e estudo devem usar os mesmos tempos")
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

func quadros_da_folha(atlas: Texture2D) -> SpriteFrames:
	var frames=SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("plantar")
	frames.set_animation_loop("plantar",false)
	frames.set_animation_speed("plantar",50)
	for q in 6:
		var tex=AtlasTexture.new()
		tex.atlas=atlas
		tex.region=Rect2(q*80,0,80,80)
		frames.add_frame("plantar",tex,TEMPOS[q]*50)
	return frames
