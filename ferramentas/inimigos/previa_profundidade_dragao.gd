extends SceneTree

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var arena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 12:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador = arena.get_node("Jogador")
	arena.get_node("Terrains").hide()
	jogador.global_position = Vector2(620, 450)
	jogador.movimento_habilitado = false
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	arena.add_child(chefe)
	chefe.set_physics_process(false)
	chefe.global_position = Vector2(620, 464)
	chefe._linha = 3
	chefe._tocar_quadro("movimento", 0)
	jogador.get_node("Camera2D").reset_smoothing()
	await create_timer(3.0).timeout
	chefe._atualizar_ordem_desenho()
	await process_frame
	await RenderingServer.frame_post_draw
	var caminho := "res://inimigos/dragao_vermelho/previas/profundidade_esquerda.png"
	root.get_viewport().get_texture().get_image().save_png(caminho)
	print("Patas: ", chefe.global_position.y + chefe.altura_pes, " jogador: ", jogador.global_position.y + 11, " z: ", chefe.z_index, "/", jogador.z_index)
	arena.queue_free()
	await process_frame
	quit()
