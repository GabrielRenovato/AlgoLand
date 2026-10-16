extends SceneTree

class AlvoPrevia extends Node2D:
	var estaMorto := false
	var invulneravel := true
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		pass

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var jogo := Node2D.new()
	root.add_child(jogo)
	current_scene = jogo
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	jogo.add_child(viewport)
	var palco := Node2D.new()
	viewport.add_child(palco)
	var jogador := AlvoPrevia.new()
	jogador.name = "Jogador"
	jogo.add_child(jogador)
	var chefe = load("res://cenas/inimigos/minotauro.tscn").instantiate()
	palco.add_child(chefe)
	chefe.set_physics_process(false)
	var texto := Label.new()
	texto.position = Vector2(20, 20)
	texto.add_theme_font_size_override("font_size", 20)
	palco.add_child(texto)
	var saida := "res://arte/previas/inimigos/minotauro/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var indice := 0
	for tipo in ["investida", "pisao", "machado", "furia"]:
		chefe.position = Vector2(170, 230)
		jogador.position = Vector2(400, 230)
		chefe.forcar_ataque_debug(tipo)
		texto.text = "MINOTAURO: " + tipo.to_upper()
		var total := 180 if tipo == "furia" else 40
		for i in total:
			# O alvo fica à frente para visualizar o combo sem sair da prévia.
			if tipo == "furia":
				jogador.position = Vector2(470, 230) if chefe.position.x < 320 else Vector2(170, 230)
			chefe._physics_process(0.05)
			if chefe.estado == chefe.Estado.LIVRE:
				chefe._recarga = 10
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(saida + "quadro_%03d.png" % indice)
			indice += 1
	jogo.queue_free()
	await process_frame
	quit()
