extends SceneTree

## Renderiza os sprites e os avisos reais sem carregar a arena ou a partida.
func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	raiz.add_child(viewport)
	var cena := Node2D.new()
	viewport.add_child(cena)
	for i in 3:
		var rotulo := Label.new()
		rotulo.text = ["SOPRO DE FOGO", "VARRIDA DE CAUDA", "BATIDA DE ASAS"][i]
		rotulo.position = Vector2(100 + 480 * i, 30)
		cena.add_child(rotulo)
	var chefes := []
	for i in 3:
		var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
		cena.add_child(chefe)
		chefe.set_physics_process(false)
		chefe.position = Vector2(200 + 480 * i, 350)
		chefe.scale = Vector2(1.5, 1.5)
		chefe.iniciar_ataque(chefe.ATAQUES[i], chefe.global_position + Vector2(100, 0))
		chefes.append(chefe)
	var saida := "res://inimigos/dragao_vermelho/previas/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	for quadro in 60:
		for chefe in chefes:
			chefe._physics_process(0.05)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(saida + "quadro_%02d.png" % quadro)
	quit()
