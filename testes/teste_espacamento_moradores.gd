extends "res://testes/teste_rolagem_mural.gd"

func percurso(a: CharacterBody2D, b: CharacterBody2D, deslocamento: float, nome: String) -> void:
	for npc in [a,b]:
		npc.visible = true
		npc.dormindo = false
		npc._saindo = false
		npc.agenda = {"local":"praia","ponto":Vector2(300,230),"atividade":"Caminhando"}
		npc.position = Vector2(180,230)
		npc._atualizar_colisao()
		if "_rotina_em" in npc: npc._rotina_em = INF
		if "_espera_balao" in npc: npc._espera_balao = INF
	b.position.x += deslocamento
	a._ir_ate(Vector2(300 if deslocamento == 0 else 280,230))
	b._ir_ate(Vector2(280 if deslocamento == 0 else 300,230))
	var afastados := true
	for passo in 180:
		a._physics_process(0.1)
		b._physics_process(0.1)
		await physics_frame
		if passo >= 25:
			afastados = afastados and a.position.distance_to(b.position) >= 16
		if passo == 24 and nome == "mesma entrada" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-npcs-espacados.png")
	verificar("moradores nao andam colados: " + nome,afastados)
	verificar("os dois concluem a rota: " + nome,a.caminho.is_empty() and b.caminho.is_empty())
	a.hide()
	b.hide()

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(20)
	var praia: Node2D = current_scene
	praia.set_process(false)
	praia.get_node("Iluminacao").set_process(false)
	var jogador: Node2D = praia.get_node("Jogador")
	jogador.position = Vector2(600,200)
	if DisplayServer.get_name() != "headless":
		root.content_scale_size = Vector2i(704,576)
		root.size = Vector2i(1408,1152)
		jogador.camera.set_as_top_level(true)
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.zoom = Vector2(3,3)
		jogador.camera.global_position = Vector2(240,235)
	for npc in get_nodes_in_group("moradores_cidade"):
		npc.set_physics_process(false)
		npc.hide()
	await percurso(praia.moradores["curandeira"],praia.moradores["ferreiro"],0,"mesma entrada")
	await percurso(praia.moradores["curandeira"],praia.moradores["ferreiro"],8,"lider criado depois")
	await percurso(praia.get_node("Nilo"),praia.moradores["ferreiro"],0,"Nilo e visitante")
	current_scene.queue_free()
	await quadros()
	print("Espacamento moradores: %d falhas" % falhas)
	quit(1 if falhas else 0)
