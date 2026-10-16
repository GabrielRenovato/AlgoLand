extends SceneTree

const SAIDA := "res://arte/previas/inimigos/goblin_maromba/execucao/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Prévia de combate: execute com saves isolados.")
		quit(1)
		return
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await create_timer(0.4).timeout
	var gerenciador: Node = arena.get_node("enemySpawner/GerenciadorOndas")
	gerenciador.parar_ondas()
	await process_frame
	root.get_node("PainelDebug")._ao_onda_goblin()
	await create_timer(1.0).timeout
	var goblin_maromba: Node = get_first_node_in_group("boss_goblin_maromba")
	if goblin_maromba == null:
		quit(1)
		return
	goblin_maromba.set_physics_process(false)
	var jogador: Node = arena.get_node("Jogador")
	jogador.set_physics_process(false)
	goblin_maromba.global_position = jogador.global_position + Vector2(-110, 40)
	goblin_maromba._definir_linha(jogador.global_position - goblin_maromba.global_position)
	goblin_maromba._tocar("movimento", 0)
	jogador.invulneravel = true
	jogador.temporizador_invul = 99
	await create_timer(2).timeout
	goblin_maromba.forcar_ataque_debug("execucao")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for quadro in 90:
		if is_instance_valid(goblin_maromba) and not goblin_maromba.is_queued_for_deletion():
			goblin_maromba._physics_process(0.05)
		jogador._physics_process(0.05)
		if jogador.estaMorto:
			# A captura mantém o combate visível; a tela de fim aparece normalmente no jogo.
			arena.get_node("Interface/TelaFimPartida").hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var imagem := root.get_viewport().get_texture().get_image()
		imagem.save_png(SAIDA + "quadro_%03d.png" % quadro)
		if quadro in [4, 25, 55, 65, 80]:
			imagem.save_png(SAIDA + "fase_%02d.png" % quadro)
	print("Execução: 90 quadros; morto=", jogador.estaMorto, "; HP=", jogador.hp_atual)
	arena.queue_free()
	await process_frame
	quit()
