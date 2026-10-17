extends SceneTree

const FONTE := "res://arte/fontes/personagens/base_zelda_estudo/corrida_fonte.png"
const SAIDA := "res://arte/previas/personagens/base_zelda_estudo/"
const REGISTRO := preload("res://ferramentas/personagem/registro_sprite_gerado.gd")

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Prévia exige projeto com save isolado.")
		quit(1)
		return
	root.size = Vector2i(768, 256)
	root.content_scale_size = Vector2i(768, 256)
	var imagem := Image.load_from_file(FONTE)
	if imagem == null:
		quit(1)
		return
	# Recorte e registro de poses inteiras; nenhuma parte do corpo é redesenhada.
	var tamanho := Vector2i(imagem.get_width() / 6, imagem.get_height() / 4)
	var atlas := Image.create(tamanho.x * 6, tamanho.y * 4, false, Image.FORMAT_RGBA8)
	for direcao in 4:
		for quadro in 6:
			var linha := 1 if direcao == 3 else direcao
			var coluna := quadro % 3 if direcao in [0, 2] else quadro
			var pose := imagem.get_region(Rect2i(Vector2i(coluna, linha) * tamanho, tamanho))
			REGISTRO.limpar(pose)
			if direcao == 3 or (direcao in [0, 2] and quadro >= 3):
				pose.flip_x()
			var limites := pose.get_used_rect()
			var destino := Vector2i((tamanho.x - limites.size.x) / 2, tamanho.y - 24 - limites.size.y)
			destino.y += [0, 6, 0, 0, 6, 0][quadro]
			atlas.blit_rect(pose, limites, Vector2i(quadro, direcao) * tamanho + destino)
	atlas.save_png(SAIDA + "corrida_registrada.png")
	var textura := ImageTexture.create_from_image(atlas)
	var cena := Node2D.new()
	root.add_child(cena)
	var fundo := ColorRect.new()
	fundo.size = Vector2(768, 256)
	fundo.color = Color("26343b")
	cena.add_child(fundo)
	var sprites: Array[Sprite2D] = []
	for direcao in 4:
		var titulo := Label.new()
		titulo.text = ["BAIXO", "DIREITA", "CIMA", "ESQUERDA"][direcao]
		titulo.position = Vector2(direcao * 192, 16)
		titulo.size = Vector2(192, 28)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cena.add_child(titulo)
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.hframes = 6
		sprite.vframes = 4
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * 144.0 / float(imagem.get_height() / 4)
		sprite.position = Vector2(96 + direcao * 192, 140)
		cena.add_child(sprite)
		sprites.append(sprite)
	for quadro in 6:
		for direcao in 4:
			sprites[direcao].frame = direcao * 6 + quadro
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA + "quadro_%02d.png" % quadro)
	print("PRÉVIA: quatro direções, seis quadros por ciclo, sem modificar o jogador.")
	cena.queue_free()
	await process_frame
	quit()
