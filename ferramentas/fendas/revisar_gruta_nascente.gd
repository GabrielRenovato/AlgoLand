extends SceneTree

## Captura a cena real e verifica atlas, colisões e rotas em save isolado.
const SAIDA := "res://arte/previas/fenda/gruta_nascente/"

func _initialize() -> void:
	rodar.call_deferred()

func aguardar() -> void:
	for i in 5:
		await physics_frame
		await process_frame

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		push_error("Revisão exige save isolado e renderização gráfica")
		quit(1)
		return
	var vista := SubViewport.new()
	vista.size = Vector2i(1280, 896)
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	var terreno := load("res://cenas/fendas/gruta_nascente.tscn").instantiate() as Node2D
	vista.add_child(terreno)
	var camera := Camera2D.new()
	camera.position = Vector2(320, 224)
	camera.zoom = Vector2(2, 2)
	vista.add_child(camera)
	camera.make_current()
	await aguardar()
	var chao := terreno.get_node("Chao") as TileMapLayer
	var agua := terreno.get_node("Agua") as TileMapLayer
	assert(chao.tile_set.tile_size == Vector2i(16, 16))
	assert(chao.get_used_cells().size() == 1120)
	assert(agua.get_used_cells().size() > 0)
	var reutilizados := {}
	for celula in chao.get_used_cells():
		var coordenada := chao.get_cell_atlas_coords(celula)
		reutilizados[coordenada] = reutilizados.get(coordenada, 0) + 1
	assert(reutilizados.size() < chao.get_used_cells().size()/4)
	var espaco := vista.world_2d.direct_space_state
	for ponto in [Vector2(320, 408), Vector2(320, 270), Vector2(250, 220)]:
		var consulta := PhysicsPointQueryParameters2D.new()
		consulta.position = ponto
		consulta.collision_mask = 1
		assert(espaco.intersect_point(consulta).is_empty(), "Piso livre bloqueado: %s" % ponto)
	for ponto in [Vector2(16, 16), Vector2(460, 175)]:
		var consulta := PhysicsPointQueryParameters2D.new()
		consulta.position = ponto
		consulta.collision_mask = 1
		assert(not espaco.intersect_point(consulta).is_empty(), "Limite sem colisão: %s" % ponto)
	var mapa: RID = vista.world_2d.navigation_map
	NavigationServer2D.map_force_update(mapa)
	var rota := NavigationServer2D.map_get_path(mapa, Vector2(320, 408), Vector2(220, 190), true)
	assert(rota.size() >= 2, "Entrada sem rota até o interior")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	await RenderingServer.frame_post_draw
	vista.get_texture().get_image().save_png(SAIDA + "caverna_godot.png")
	camera.position = Vector2(460, 172)
	camera.zoom = Vector2(4, 4)
	vista.size = Vector2i(768, 640)
	await aguardar()
	await RenderingServer.frame_post_draw
	vista.get_texture().get_image().save_png(SAIDA + "detalhe_margens_godot.png")
	print("GRUTA OK: TileMaps16 reutilizáveis, piso livre, rocha/água bloqueadas, rota de entrada; duas capturas reais")
	quit()
