extends SceneTree

## Compara os pixels realmente desenhados pelo TileMap com o platô completo, em save isolado.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 5) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func rodar() -> void:
	if DisplayServer.get_name() == "headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var vista := SubViewport.new()
	vista.disable_3d = true
	vista.size = Vector2i(576,480)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	DirAccess.make_dir_recursive_absolute("res://arte/previas/fenda/relevo")
	for andar in [1,2,5,8]:
		vista.world_2d = World2D.new()
		var terreno: Node2D = load("res://cenas/fendas/terreno_%02d.tscn" % andar).instantiate()
		vista.add_child(terreno)
		var camada: TileMapLayer = terreno.get_node("Penhasco")
		var origens: Array[Vector2i] = []
		for celula in camada.get_used_cells():
			if camada.get_cell_atlas_coords(celula) == Vector2i(5,8): origens.append(celula)
		verificar("andar %d tem relevos para revisar" % andar, not origens.is_empty())
		if origens.is_empty():
			terreno.queue_free()
			await quadros()
			continue
		var origem := camada.map_to_local(origens[0]) - Vector2(8,8)
		var camera := Camera2D.new()
		camera.position = origem + Vector2(48,64)
		camera.zoom = Vector2(3,3)
		vista.add_child(camera)
		camera.make_current()
		await quadros()
		for estacao in 4:
			var estacoes: Node = terreno.get_node("Estacoes")
			estacoes.definir_estacao(estacao,true)
			estacoes.meteorologia.definir_clima(0,true)
			estacoes.get_node("Clima").hide()
			estacoes.get_node("CamadaVagalumes").hide()
			await quadros()
			await RenderingServer.frame_post_draw
			vista.get_texture().get_image().save_png("res://arte/previas/fenda/relevo/andar-%02d-estacao-%d.png" % [andar,estacao])
			# Comparar o recorte sem o ajuste de cores de TilesRefinados; a captura mantém o acabamento real.
			terreno.get_node("Objetos3D").hide()
			var material_original := camada.material
			camada.material = CanvasItemMaterial.new()
			await quadros(2)
			await RenderingServer.frame_post_draw
			var imagem := vista.get_texture().get_image()
			var atlas: TileSetAtlasSource = camada.tile_set.get_source(0)
			var referencia := atlas.texture.get_image()
			var diferentes := 0
			for y in 64:
				for x in 64:
					var tela: Vector2 = camada.get_global_transform_with_canvas() * (origem + Vector2(16+x+0.5,32+y+0.5))
					var desenhado := imagem.get_pixelv(Vector2i(tela.floor()))
					var esperado := referencia.get_pixel(96+x,160+y)
					if absf(desenhado.r-esperado.r)>0.005 or absf(desenhado.g-esperado.g)>0.005 or absf(desenhado.b-esperado.b)>0.005:
						diferentes += 1
			verificar("andar %d estação %d: relevo inteiro renderizado, %d pixels divergentes" % [andar,estacao,diferentes], diferentes == 0)
			camada.material = material_original
			terreno.get_node("Objetos3D").show()
		terreno.queue_free()
		camera.queue_free()
		await quadros()
	vista.queue_free()
	await quadros()
	print("Relevo Gentle: %d falhas" % falhas)
	quit(1 if falhas else 0)
