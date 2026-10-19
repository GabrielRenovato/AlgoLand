extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_recortada/"
const SAIDA := "res://arte/previas/fenda/caverna_recortada/"

func _initialize() -> void:
	rodar.call_deferred()

func quadros() -> void:
	for i in 6:
		await physics_frame
		await process_frame

func rodar() -> void:
	if DisplayServer.get_name()=="headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"andar_08.json"))
	var vista := SubViewport.new()
	vista.size = Vector2i(dados.limites[2],dados.limites[3])
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	var terreno := load("res://cenas/fendas/previa_caverna_08.tscn").instantiate() as Node2D
	vista.add_child(terreno)
	var camera := Camera2D.new()
	camera.position = Vector2(dados.limites[0]+dados.limites[2]*.5,dados.limites[1]+dados.limites[3]*.5)
	vista.add_child(camera)
	camera.make_current()
	await quadros()
	assert(terreno.get_node("Setores").get_child_count()==10)
	var mapa: RID = vista.world_2d.navigation_map
	NavigationServer2D.map_force_update(mapa)
	var inicio := Vector2(dados.entrada[0],dados.entrada[1])
	for setor: Dictionary in dados.setores:
		var destino := Vector2(setor.centro[0],setor.centro[1])
		var rota := NavigationServer2D.map_get_path(mapa,inicio,destino,true)
		if rota.size()==0 or rota[-1].distance_to(destino)>=12:
			push_error("Rota interrompida: "+str(setor.id))
			quit(1)
			return
		var consulta := PhysicsPointQueryParameters2D.new()
		consulta.position = destino
		consulta.collision_mask = 1
		if not vista.world_2d.direct_space_state.intersect_point(consulta).is_empty():
			push_error("Centro bloqueado: "+str(setor.id))
			quit(1)
			return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	vista.get_texture().get_image().save_png(SAIDA+"andar_08_geral_godot.png")
	vista.size = Vector2i(1280,960)
	camera.position = Vector2(272,-80)
	camera.zoom = Vector2(2,2)
	await quadros()
	await RenderingServer.frame_post_draw
	vista.get_texture().get_image().save_png(SAIDA+"andar_08_detalhe_godot.png")
	print("CAVERNA08 OK: dez salas alcançáveis e livres, captura geral e detalhe; save isolado")
	quit()
