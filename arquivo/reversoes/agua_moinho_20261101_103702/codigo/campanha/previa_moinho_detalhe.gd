extends Node2D
## Enquadramento de revisão do moinho, em projeto com save isolado.
func _ready() -> void:
	var mapa := preload("res://cenas/campanha/terreno_moinho.tscn").instantiate()
	mapa.set_meta("captura_visual", true)
	add_child(mapa)
	await get_tree().process_frame
	mapa._roda_moinho.definir_ligado(true)
	for inimigo in get_tree().get_nodes_in_group("enemy"):
		if mapa.is_ancestor_of(inimigo): inimigo.queue_free()
	var ator := preload("res://cenas/jogador.tscn").instantiate()
	ator.name = "Jogador"
	add_child(ator)
	ator.set_physics_process(false)
	ator.set_process(false)
	ator.get_node("Camera2D").enabled = false
	ator.position = Vector2(-456, -280)
	ator.z_index = mapa.Profundidade.z_de(ator.position.y + 11)
	var camera := Camera2D.new()
	camera.position = Vector2(-493, -366)
	camera.zoom = Vector2.ONE * 1.1
	add_child(camera)
	camera.make_current()
	var destino := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="): destino = argumento.trim_prefix("--capturas=")
	if destino.is_empty(): return
	DirAccess.make_dir_recursive_absolute(destino)
	for i in 4:
		mapa.definir_estacao(i)
		mapa._roda_moinho.instante_forcado = 0.0
		mapa._roda_moinho._process(0.0)
		for quadro in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destino.path_join("moinho-%d.png" % i))
	mapa.definir_estacao(0)
	for i in 16:
		mapa._roda_moinho.instante_forcado = i * TAU / (16.0 * 0.32)
		mapa._roda_moinho._process(0.0)
		for quadro in 2: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destino.path_join("roda-%02d.png" % i))
	get_tree().quit()
