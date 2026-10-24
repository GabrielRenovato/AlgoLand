extends SceneTree
## Estudo em save isolado: dois passos e um apoio adicional nas laterais, sem trocar o conjunto ativo.
const BASE="res://arte/fontes/armaduras/carrasco/estudo_cidade/animacoes/"
const SAIDA="res://arte/previas/armaduras/carrasco/estudo_cidade/"
var _sprites: Array[AnimatedSprite2D]=[]

func _initialize() -> void: revisar.call_deferred()

func criar(dados: Dictionary, altura: float) -> AnimatedSprite2D:
	var quadros := SpriteFrames.new()
	quadros.set_animation_speed("default",20.0)
	quadros.set_animation_loop("default",true)
	for indice in dados.sequencia.size():
		var pose := int(dados.sequencia[indice])
		var arquivo: String=dados.get("arquivos_por_pose",[])[pose] if dados.has("arquivos_por_pose") else dados.arquivo
		var imagem := Image.load_from_file(arquivo)
		assert(imagem!=null and not imagem.is_empty())
		var textura := ImageTexture.create_from_image(imagem)
		var r: Array=dados.regioes[pose]
		var atlas := AtlasTexture.new()
		atlas.atlas=textura;atlas.region=Rect2(r[0],r[1],r[2],r[3]);atlas.filter_clip=true
		quadros.add_frame("default",atlas,float(dados.duracoes_ms[indice])/50.0)
	var sprite := AnimatedSprite2D.new()
	sprite.centered=false
	sprite.sprite_frames=quadros
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*altura/float(dados.altura)
	sprite.flip_h=dados.espelhar
	var ancorar := func() -> void:
		var pose := int(dados.sequencia[sprite.frame])
		var x := float(dados.ancoras_x[pose])
		if dados.espelhar:x=float(dados.regioes[pose][2])-x
		var chao := float(dados.chaos_por_pose[pose]) if dados.has("chaos_por_pose") else float(dados.chao)
		var escala := float(dados.escalas_por_pose[pose]) if dados.has("escalas_por_pose") else 1.0
		sprite.scale=Vector2.ONE*altura/float(dados.altura)*escala
		sprite.offset=Vector2(-x,-chao)
	sprite.frame_changed.connect(ancorar)
	ancorar.call()
	return sprite

func revisar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 35:await process_frame
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	var jogador: Node2D=current_scene.get_node("Jogador")
	jogador.visible=false
	current_scene.get_node("Interface").visible=false
	var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"apoio_lateral.json"))
	for config in dados.direcoes:
		var total := 0
		for duracao in config.duracoes_ms:total+=int(duracao)
		assert(total==300)
		assert(config.regioes.size()==(2 if config.nome in ["FRENTE","COSTAS"] else 3))
	var vp := SubViewport.new()
	vp.size=Vector2i(800,320)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fundo := ColorRect.new();fundo.size=vp.size;fundo.color=Color("485044");vp.add_child(fundo)
	var fonte := preload("res://assets/ui/Planes_ValMore.ttf")
	for d in dados.direcoes.size():
		var config: Dictionary=dados.direcoes[d]
		var titulo := Label.new();titulo.text=config.nome;titulo.position=Vector2(d*200+18,14)
		titulo.add_theme_font_override("font",fonte);titulo.add_theme_font_size_override("font_size",16);vp.add_child(titulo)
		var sprite := criar(config,210)
		sprite.position=Vector2(d*200+100,284)
		vp.add_child(sprite);_sprites.append(sprite)
		# Representação apenas de revisão, no cenário real e na altura do jogador.
		var no_mapa := criar(config,34)
		no_mapa.position=jogador.position+Vector2(-60+d*40,0)
		no_mapa.process_mode=Node.PROCESS_MODE_ALWAYS
		current_scene.add_child(no_mapa);no_mapa.play()
	var tela := CanvasLayer.new();tela.layer=100;root.add_child(tela)
	var imagem := TextureRect.new();imagem.texture=vp.get_texture();imagem.position=Vector2(240,24);imagem.size=vp.size;tela.add_child(imagem)
	DirAccess.make_dir_recursive_absolute(SAIDA)
	# Capturas nos mesmos instantes da reprodução: passos de 50 ms.
	for q in 6:
		for d in _sprites.size():
			var config: Dictionary=dados.direcoes[d]
			var acumulado := 0
			for indice in config.sequencia.size():
				acumulado+=int(config.duracoes_ms[indice])
				if q*50<acumulado:
					_sprites[d].frame=indice
					break
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(SAIDA+"apoio_%d.png"%q)
		if q==2:root.get_texture().get_image().save_png(SAIDA+"cidade_apoio.png")
	var vistos: Array[Dictionary]=[{}, {}, {}, {}]
	for sprite in _sprites:sprite.stop();sprite.play()
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<1500:
		await process_frame
		for d in _sprites.size():vistos[d][_sprites[d].frame]=true
	for d in _sprites.size():assert(vistos[d].size()==dados.direcoes[d].sequencia.size())
	print("CARRASCO ESTUDO: frente/costas 2 poses; laterais 3 poses; ciclo de 300 ms; reprodução em cidade com save isolado")
	quit()
