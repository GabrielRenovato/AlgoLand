extends "res://testes/teste_rolagem_mural.gd"

func obstaculo(cena: Node2D, ponto: Vector2, corpo: Node) -> bool:
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.position = ponto
	consulta.collision_mask = 64
	return cena.get_world_2d().direct_space_state.intersect_point(consulta).any(func(acerto): return acerto["collider"] == corpo)

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
	var jogador: CharacterBody2D = praia.get_node("Jogador")
	for x in [208,432]:
		var base := Vector2(x,152)
		var corpo: Node = praia.get_node("MobiliarioCais/canteiro_%d_152_Colisao" % x)
		verificar("extremidades da caixa bloqueiam: %d" % x,obstaculo(praia,base+Vector2(-20,-6),corpo) and obstaculo(praia,base+Vector2(20,-6),corpo))
		verificar("flor e laterais nao criam barreira invisivel: %d" % x,not obstaculo(praia,base+Vector2(0,-26),corpo) and not obstaculo(praia,base+Vector2(-28,-6),corpo) and not obstaculo(praia,base+Vector2(28,-6),corpo))
		jogador.position = base+Vector2(-45,-11)
		jogador.velocity = Vector2.ZERO
		await quadros(3)
		Input.action_press(jogador.acao("move_right"))
		await quadros(45)
		Input.action_release(jogador.acao("move_right"))
		await quadros(10)
		verificar("corpo do jogador para na lateral da caixa: %d" % x,jogador.position.x < base.x-24 and jogador.position.x > base.x-42)
	if DisplayServer.get_name() != "headless":
		root.content_scale_size = Vector2i(704,576)
		root.size = Vector2i(1408,1152)
		jogador.camera.set_as_top_level(true)
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.zoom = Vector2(2,2)
		jogador.camera.global_position = Vector2(320,150)
		for estacao in 4:
			root.get_node("Calendario").dia = estacao*30+1
			root.get_node("Calendario").estacao_mudou.emit(estacao)
			await quadros(6)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-canteiros-colisao-%d.png" % estacao)
	current_scene.queue_free()
	await quadros()
	print("Canteiros praia: %d falhas" % falhas)
	quit(1 if falhas else 0)
