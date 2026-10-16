extends SceneTree

const SAIDA := "res://arte/previas/inimigos/goblin_maromba/caminhada/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 310)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new()
	fundo.size = vp.size
	fundo.color = Color("242a2d")
	vp.add_child(fundo)
	var corpos: Array[Sprite2D] = []
	var rotulos: Array[Label] = []
	for direcao in 2:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/inimigos/goblin_maromba/movimento.png")
		sprite.hframes = 12
		sprite.vframes = 4
		sprite.position = Vector2(160 + direcao * 320, 155)
		vp.add_child(sprite)
		corpos.append(sprite)
		var titulo := Label.new()
		titulo.position = Vector2(20 + direcao * 320, 8)
		titulo.text = "Direita" if direcao == 0 else "Esquerda"
		vp.add_child(titulo)
		var rotulo := Label.new()
		rotulo.position = Vector2(20 + direcao * 320, 284)
		vp.add_child(rotulo)
		rotulos.append(rotulo)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for quadro in 72:
		var indice := int(quadro / 6) % 12
		for direcao in 2:
			corpos[direcao].frame = (direcao + 2) * 12 + indice
			rotulos[direcao].text = "Quadro %02d / 12" % (indice + 1)
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(SAIDA + "quadro_%03d.png" % quadro)
	vp.queue_free()
	await process_frame
	quit()
