extends SceneTree

## Regressão visual das junções de parede e da margem recuperada da arte do autor.
func _initialize() -> void: rodar.call_deferred()

func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		print("FALHA continuidade exige renderizacao e save isolado")
		quit(1)
		return
	await process_frame
	var falhas := 0
	for caso in [[4,"fenda_continuidade"],[7,"fenda_margem_usuario"]]:
		var vista := SubViewport.new()
		vista.disable_3d = true
		vista.size = Vector2i(576,324)
		vista.world_2d = World2D.new()
		vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vista)
		var terreno: Node2D = load("res://cenas/fendas/terreno_%02d.tscn" % caso[0]).instantiate()
		vista.add_child(terreno)
		var camera := Camera2D.new()
		camera.position = terreno.get_node("Setores").get_child(1).position
		vista.add_child(camera)
		camera.make_current()
		await quadros()
		terreno.get_node("Estacoes").definir_estacao(0,true)
		await quadros()
		await RenderingServer.frame_post_draw
		var atual := vista.get_texture().get_image()
		var textura_ref := load("res://testes/referencias/%s.png" % caso[1]) as Texture2D
		var referencia: Image = textura_ref.get_image() if textura_ref else null
		var diferentes := 0
		if referencia == null or referencia.get_size() != atual.get_size():
			diferentes = atual.get_width()*atual.get_height()
		else:
			for y in atual.get_height():
				for x in atual.get_width():
					var a := atual.get_pixel(x,y)
					var b := referencia.get_pixel(x,y)
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 2.0/255.0:
						diferentes += 1
		var pasta := "res://arte/previas/fenda/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
		atual.save_png(pasta+"%s_atual.png" % caso[1])
		print("OK continuidade visual %s" % caso[1] if diferentes <= 5 else "FALHA continuidade visual %s: %d pixels diferentes" % [caso[1],diferentes])
		if diferentes > 5: falhas += 1
		vista.queue_free()
		await quadros()
	quit(0 if falhas == 0 else 1)
