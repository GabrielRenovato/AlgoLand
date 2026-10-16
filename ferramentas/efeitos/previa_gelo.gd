extends SceneTree

## Prévia dos sprites reais, sem carregar arena ou saves.
func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var cena := Node2D.new()
	viewport.add_child(cena)
	current_scene = cena
	var alvos := []
	var cenas := ["slime", "esqueleto_arqueiro", "golem"]
	for i in cenas.size():
		var alvo = load("res://cenas/inimigos/" + cenas[i] + ".tscn").instantiate()
		alvo.set_physics_process(false)
		cena.add_child(alvo)
		alvo.set_physics_process(false)
		alvo.scale = Vector2(3, 3)
		var corpo: Sprite2D = alvo.sprite
		var imagem := corpo.texture.get_image()
		var tamanho := Vector2i(imagem.get_width() / corpo.hframes, imagem.get_height() / corpo.vframes)
		var origem := Vector2i((corpo.frame % corpo.hframes) * tamanho.x, (corpo.frame / corpo.hframes) * tamanho.y)
		var area := imagem.get_region(Rect2i(origem, tamanho)).get_used_rect()
		var pe: float = corpo.position.y + (corpo.get_rect().position.y + area.end.y) * corpo.scale.y
		alvo.position = Vector2([96, 288, 576][i], 280 - pe * 3)
		if alvo.get_node_or_null("HPBar") != null:
			alvo.get_node("HPBar").hide()
		alvo.aplicar_congelamento(2)
		alvos.append(alvo)
	var saida := "res://arte/previas/efeitos/congelamento/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	for quadro in 6:
		for alvo in alvos:
			var gelo = alvo.get_node("GeloMordomo")
			gelo.set_process(false)
			gelo._sprite.frame = quadro
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(saida + "estado_%d.png" % quadro)
	quit()
