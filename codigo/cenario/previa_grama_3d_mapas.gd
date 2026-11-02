extends SceneTree
## Capturas dos cenários reais usando exclusivamente o projeto de save isolado.
func _initialize() -> void:
	_abrir.call_deferred()

func _abrir() -> void:
	var destino := "chegada"
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--mapa="): destino = argumento.trim_prefix("--mapa=")
	var mundo := Node2D.new()
	root.add_child(mundo)
	current_scene = mundo
	var caminho := "res://cenas/campanha/terreno_%s.tscn" % destino
	if destino == "cidade": caminho = "res://cenas/cidade.tscn"
	var mapa := load(caminho).instantiate() as Node2D
	mapa.set_meta("captura_visual",true)
	root.add_child(mapa)
	current_scene = mapa
	print("Mapa carregado: ",destino)
	var pontos := {"chegada":Vector2(-350,240),"estrada":Vector2(-290,30),"vila":Vector2(-430,130),"cidade":Vector2(500,310)}
	var ponto: Vector2 = pontos[destino]
	if "--pedras" in OS.get_cmdline_user_args(): ponto = Vector2(-228,220)
	var ator := mapa.get_node_or_null("Jogador") as Node2D
	if ator == null:
		ator = load("res://cenas/jogador.tscn").instantiate()
		mundo.add_child(ator)
	ator.position = ponto
	ator.set_process(false)
	ator.set_physics_process(false)
	ator.z_index = preload("res://codigo/globais/profundidade.gd").z_de(ponto.y+11)
	var camera := Camera2D.new()
	camera.position = ponto
	camera.zoom = Vector2.ONE*1.4
	mundo.add_child(camera)
	camera.make_current()
	await create_timer(2.0).timeout
	print("Capturando: ",destino)
	var pasta := "res://arte/previas/cenario/grama_3d_mapas/"+destino
	DirAccess.make_dir_recursive_absolute(pasta)
	for i in 4:
		if destino == "cidade": mapa.get_node("Terrains/Estacoes").definir_estacao(i,true)
		else: mapa.definir_estacao(i)
		for quadro in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta.path_join("estacao-%d.png" % i))
	quit()
