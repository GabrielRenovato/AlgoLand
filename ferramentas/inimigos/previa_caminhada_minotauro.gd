extends SceneTree

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var jogo := Node2D.new()
	root.add_child(jogo)
	current_scene = jogo
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	jogo.add_child(viewport)
	var palco := Node2D.new()
	viewport.add_child(palco)
	var chefes: Array[Node2D] = []
	var referencias: Array[Sprite2D] = []
	var nomes := ["FRENTE", "COSTAS", "DIREITA", "ESQUERDA"]
	for linha in 4:
		var chefe = load("res://cenas/inimigos/minotauro.tscn").instantiate()
		palco.add_child(chefe)
		chefe.set_physics_process(false)
		chefe.position = Vector2(80 + linha * 160, 210)
		chefe._linha = linha
		chefes.append(chefe)
		for arquivo in ["res://CharacterSprites/Body/body_1.png", "res://CharacterSprites/Outfit/outfit (5).png"]:
			var referencia := Sprite2D.new()
			referencia.texture = load(arquivo)
			referencia.hframes = 8
			referencia.vframes = 8
			referencia.position = Vector2(80 + linha * 160, 90)
			referencia.scale = Vector2(2, 2)
			palco.add_child(referencia)
			referencias.append(referencia)
		var texto := Label.new()
		texto.position = Vector2(30 + linha * 160, 30)
		texto.text = nomes[linha]
		palco.add_child(texto)
	var saida := "res://inimigos/minotauro/previas/caminhada/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	for i in 80:
		for chefe in chefes:
			# Usa o mesmo controlador de passos do jogo, a 72 unidades/s.
			chefe._animar_deslocamento(Vector2(72 * 0.05, 0))
		for j in referencias.size():
			var linha := j / 2
			referencias[j].frame = 32 + linha * 8 + chefes[linha].sprite.frame % 6
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(saida + "quadro_%03d.png" % i)
	jogo.queue_free()
	await process_frame
	quit()
