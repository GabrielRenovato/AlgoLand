extends SceneTree

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena = false
	root.add_child(tela)
	tela._escolher_cabelo(3)
	tela._escolher_roupa(1)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var fundo := ColorRect.new()
	fundo.size = viewport.size
	fundo.color = Color("212033")
	viewport.add_child(fundo)
	for i in 2:
		var modelo: Node2D = tela._modelo.duplicate()
		modelo.position = Vector2(200 + i * 400, 300)
		modelo.scale = Vector2(12, 12)
		viewport.add_child(modelo)
		modelo.get_child(1).material = null if i == 0 else preload("res://arquivo/prototipos/personagem/nitidez/corpo_nitido.tres")
		for camada in modelo.get_children():
			if camada is Sprite2D:
				camada.frame = 0
		var legenda := Label.new()
		legenda.text = "ANTES" if i == 0 else "TONS DEFINIDOS"
		legenda.position = Vector2(90 + i * 400, 16)
		legenda.add_theme_font_size_override("font_size", 22)
		viewport.add_child(legenda)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://arte/previas/personagens/prototipo/nitidez/comparacao.png")
	tela.queue_free()
	viewport.queue_free()
	await process_frame
	quit()
