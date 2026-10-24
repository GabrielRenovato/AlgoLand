extends SceneTree
const BASE="res://assets/personagens/raven_fantasy/estudo_colheita/base/"
const FONTES="res://arte/fontes/personagens/raven_colheita/"
const SAIDA="res://arte/previas/personagens/raven_colheita/"
const TEMPOS=[0.40,0.24,0.18,0.30]
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
	quadros.add_animation("colher")
	quadros.set_animation_loop("colher",false)
	quadros.set_animation_speed("colher",50)
	for q in 4:
		var celula=AtlasTexture.new()
		celula.atlas=tex
		celula.region=Rect2(q*80,direcao*80,80,80)
		quadros.add_frame("colher",celula,TEMPOS[q]*50)
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
			var pixels_short=0
			for y in 80:
				for x in 80:
					var cor=quadro.get_pixel(x,y)
					if cor.a>0 and cor in [Color8(35,39,47),Color8(53,58,69),Color8(76,83,96)]:pixels_short+=1
			assert(pixels_short>=3,"Short neutro presente em toda pose")
			assert(limites.position.x>1 and limites.position.y>1 and limites.end.x<79 and limites.end.y<79,"Margens e células sem vazamento")
			if q==3: assert(quadro.get_data()==base.get_region(Rect2i(160,d*80,80,80)).get_data(),"Último quadro mantém os braços erguidos")
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
	for decoracao in current_scene.find_children("*","Sprite2D",true,false):
		if decoracao.get_rect().size.length()<400:decoracao.hide()
	for tipo in ["CPUParticles2D","GPUParticles2D"]:
		for particula in current_scene.find_children("*",tipo,true,false):particula.hide()
	var jogador=current_scene.get_node("Jogador")
	jogador.hide()
	var ponto=jogador.global_position+Vector2(0,120)
	var vp=SubViewport.new()
	vp.size=Vector2i(640,420)
	vp.world_2d=current_scene.get_world_2d()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var camera=Camera2D.new()
	camera.position=ponto+Vector2(0,-20)
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
	for d in 4:
		var x=d*48-72
		atores.append(ator(folha(FONTES+"mana_seed_nativo.png"),null,d,ponto+Vector2(x,-30)))
		atores.append(ator(folha(BASE+"corpo_0.png"),null,d,ponto+Vector2(x,34)))
		efeitos.append(ator(folha(BASE+"efeitos.png"),null,d,ponto+Vector2(x,34)))
	await esperar(5)
	DirAccess.make_dir_recursive_absolute(SAIDA+"motor_base")
	for sprite in atores+efeitos:sprite.play("colher")
	var vistos=[]
	for i in 86:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(SAIDA+"motor_base/%03d.png"%i)
		if not vistos.has(atores[1].animation+str(atores[1].frame)):vistos.append(atores[1].animation+str(atores[1].frame))
		for sprite in atores:assert(sprite.frame==atores[0].frame and sprite.animation==atores[0].animation,"Referência e base sincronizadas")
		await process_frame
	assert(vistos==["colher0","colher1","colher2","colher3"])
	print("OK base modular no Godot: quatro direções, três peles com alfa igual, efeitos independentes, tempos400/240/180/300ms e sustentação final com short")
	current_scene.queue_free()
	current_scene=null
	vp.queue_free()
	await esperar(3)
	quit()
