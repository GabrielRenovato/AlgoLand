extends Node2D
## Enquadramento de revisão do moinho, em projeto com save isolado.
func _ready() -> void:
	var mapa := preload("res://cenas/campanha/terreno_moinho.tscn").instantiate()
	mapa.set_meta("captura_visual", true)
	add_child(mapa)
	await get_tree().process_frame
	mapa._roda_moinho.definir_ligado(true)
	mapa._roda_moinho.definir_vazao(1.0)
	mapa.atualizar_fluxo_puzzle([2,0,2],true)
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
	if "--mapa-todo" in OS.get_cmdline_user_args():
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE * 0.30
	if "--comporta" in OS.get_cmdline_user_args():
		camera.position = Vector2(-350,-220)
		camera.zoom = Vector2.ONE * 0.85
		for id in ["registro_entrada", "registro_desvio", "registro_retorno"]:
			var p: Array = mapa.dados.alvos[id].p
			mapa._construcoes.registro(Vector2(p[0],p[1]))
	if "--grama-interativa" in OS.get_cmdline_user_args():
		ator.position = Vector2(-320,-92)
		ator.z_index = mapa.Profundidade.z_de(ator.position.y+11)
		camera.position = Vector2(-320,-100)
		camera.zoom = Vector2.ONE*2.0
	add_child(camera)
	camera.make_current()
	var destino := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="): destino = argumento.trim_prefix("--capturas=")
	if destino.is_empty(): return
	DirAccess.make_dir_recursive_absolute(destino)
	# Deixa a corrente alcançar a roda e o canal antes das capturas sazonais.
	await get_tree().create_timer(2.5).timeout
	if "--grama-interativa" in OS.get_cmdline_user_args():
		print("FPS antes das capturas: ",Engine.get_frames_per_second())
		print("Sobreposições: ",mapa._natureza_lowpoly._frentes.size()," pés; ",mapa._natureza_lowpoly._bases_frentes.size()," bases")
	for i in 4:
		mapa.definir_estacao(i)
		mapa._roda_moinho.instante_forcado = 0.0
		mapa._roda_moinho._process(0.0)
		for quadro in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destino.path_join("moinho-%d.png" % i))
	if "--apenas-estacoes" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if "--grama-interativa" in OS.get_cmdline_user_args():
		mapa.definir_estacao(0)
		for i in 60:
			ator.position = Vector2(-344+float(i)*.8,-92)
			ator.velocity = Vector2(48,0)
			ator.z_index = mapa.Profundidade.z_de(ator.position.y+11)
			await get_tree().create_timer(1.0/30.0).timeout
			if i%18 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(destino.path_join("passagem-%02d.png" % i))
		ator.velocity = Vector2.ZERO
		for i in 12:
			await get_tree().create_timer(.1).timeout
			if i%3 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(destino.path_join("retorno-%02d.png" % i))
		print("Prévia de grama: ",Engine.get_frames_per_second()," FPS")
		get_tree().quit()
		return
	mapa.definir_estacao(0)
	for i in 16:
		if "--comporta" in OS.get_cmdline_user_args():
			mapa._comporta.definir_aberta(i >= 8)
			for mecanismo in mapa._construcoes.mecanismos:
				if mecanismo.tipo == 1: mecanismo.definir_estado(i % 3)
			await get_tree().create_timer(0.15).timeout
		mapa._roda_moinho.instante_forcado = i * TAU / (16.0 * 0.32)
		mapa._roda_moinho._process(0.0)
		for quadro in 2: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destino.path_join("roda-%02d.png" % i))
	mapa._roda_moinho.instante_forcado = -1.0
	# Duas voltas em tempo real: a prévia documenta água, rotação e espuma juntas.
	for i in 25:
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destino.path_join("agua-%02d.png" % i))
	get_tree().quit()
