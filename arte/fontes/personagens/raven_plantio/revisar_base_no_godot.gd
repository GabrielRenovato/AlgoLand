extends SceneTree
const BASE="res://assets/personagens/raven_fantasy/estudo_plantio/base/"
const FONTES="res://arte/fontes/personagens/raven_plantio/"
const SAIDA="res://arte/previas/personagens/raven_plantio/"
const TEMPOS=[0.30,0.10,0.10,0.10]
var atores: Array[AnimatedSprite2D]=[]
var efeitos: Array[AnimatedSprite2D]=[]
func _initialize(): rodar.call_deferred()
func esperar(n):
	for i in n: await process_frame
func folha(path: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(path))
func animar(tex: Texture2D, direcao: int, parado: Texture2D=null) -> SpriteFrames:
	var quadros=SpriteFrames.new()
	quadros.remove_animation("default")
	quadros.add_animation("plantar")
	quadros.set_animation_loop("plantar",false)
	quadros.set_animation_speed("plantar",50)
	for q in 4:
		var celula=AtlasTexture.new()
		celula.atlas=tex
		celula.region=Rect2(q*80,direcao*80,80,80)
		quadros.add_frame("plantar",celula,TEMPOS[q]*50)
	quadros.add_animation("parado")
	var repouso=AtlasTexture.new()
	repouso.atlas=parado if parado!=null else ImageTexture.create_from_image(Image.create(320,320,false,Image.FORMAT_RGBA8))
	repouso.region=Rect2(0,direcao*80,80,80)
	quadros.add_frame("parado",repouso)
	return quadros
func ator(tex: Texture2D, parado: Texture2D, direcao: int, pos: Vector2) -> AnimatedSprite2D:
	var sprite=AnimatedSprite2D.new()
	sprite.sprite_frames=animar(tex,direcao,parado)
	sprite.centered=false
	sprite.offset=Vector2(-40,-47)
	sprite.position=pos
	sprite.process_mode=Node.PROCESS_MODE_ALWAYS
	var mat=CanvasItemMaterial.new()
	mat.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material=mat
	sprite.animation_finished.connect(func(): sprite.play("parado"))
	current_scene.add_child(sprite)
	return sprite
func conferir_base():
	var base=Image.load_from_file(BASE+"corpo_0.png")
	assert(base.get_size()==Vector2i(320,320))
	for pele in [1,2]:
		var variante=Image.load_from_file(BASE+"corpo_%d.png"%pele)
		for y in 320:
			for x in 320: assert(variante.get_pixel(x,y).a==base.get_pixel(x,y).a,"As peles precisam manter as mesmas poses")
	for d in 4:
		for q in 4:
			var quadro=base.get_region(Rect2i(q*80,d*80,80,80))
			var limites=quadro.get_used_rect()
			assert(limites.has_area())
			assert(limites.position.x>1 and limites.position.y>1 and limites.end.x<79 and limites.end.y<79,"Margens e células sem vazamento")
			if q>1: assert(quadro.get_data()==base.get_region(Rect2i(80,d*80,80,80)).get_data(),"O corpo mantém a pose; somente o efeito muda")
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	conferir_base()
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(25)
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	# Oculta apenas sprites de decoração nesta revisão para comparar os corpos sem oclusão.
	for decoracao in current_scene.find_children("*","Sprite2D",true,false):decoracao.hide()
	var jogador=current_scene.get_node("Jogador")
	jogador.hide()
	var ponto=jogador.global_position+Vector2(0,120)
	var vp=SubViewport.new()
	vp.size=Vector2i(640,384)
	vp.world_2d=current_scene.get_world_2d()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var camera=Camera2D.new()
	camera.position=ponto+Vector2(0,-14)
	camera.zoom=Vector2(3,3)
	vp.add_child(camera)
	camera.make_current()
	var painel=CanvasLayer.new()
	vp.add_child(painel)
	for i in 2:
		var titulo=Label.new()
		titulo.text=["MANA SEED ORIGINAL","RAVEN - CORPO BASE"][i]
		titulo.position=Vector2(18,18+i*190)
		titulo.add_theme_font_size_override("font_size",14)
		titulo.add_theme_color_override("font_shadow_color",Color.BLACK)
		titulo.add_theme_constant_override("shadow_offset_x",1)
		titulo.add_theme_constant_override("shadow_offset_y",1)
		painel.add_child(titulo)
	var acoes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_fantasy/camadas/acoes.json"))
	var idle=Image.load_from_file("res://assets/personagens/raven_fantasy/camadas/corpo_0.png").get_region(Rect2i(0,acoes.find("parado")*320,320,320))
	var idle_mana=Image.create(320,320,false,Image.FORMAT_RGBA8)
	var fonte=Image.load_from_file(FONTES+"mana_seed_parado_original.png")
	for d in 4:idle_mana.blit_rect(fonte,Rect2i(0,[0,2,1,3][d]*64,64,64),Vector2i(8,d*80+1))
	for d in 4:
		var x=d*48-72
		atores.append(ator(folha(FONTES+"mana_seed_nativo.png"),ImageTexture.create_from_image(idle_mana),d,ponto+Vector2(x,-30)))
		atores.append(ator(folha(BASE+"corpo_0.png"),ImageTexture.create_from_image(idle),d,ponto+Vector2(x,34)))
		efeitos.append(ator(folha(BASE+"efeitos.png"),null,d,ponto+Vector2(x,34)))
	await esperar(5)
	DirAccess.make_dir_recursive_absolute(SAIDA+"motor_base")
	for sprite in atores+efeitos:sprite.play("plantar")
	var vistos=[]
	for i in 60:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(SAIDA+"motor_base/%03d.png"%i)
		if not vistos.has(atores[1].animation+str(atores[1].frame)):vistos.append(atores[1].animation+str(atores[1].frame))
		for sprite in atores:assert(sprite.frame==atores[0].frame and sprite.animation==atores[0].animation,"Referência e base sincronizadas")
		await process_frame
	assert(vistos==["plantar0","plantar1","plantar2","plantar3","parado0"])
	print("OK base modular no Godot: quatro direções, três peles com alfa igual, efeitos independentes, tempos300/100/100/100ms e retorno ao parado")
	current_scene.queue_free()
	current_scene=null
	vp.queue_free()
	await esperar(3)
	quit()
