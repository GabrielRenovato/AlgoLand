extends SceneTree
## Com o personagem base 3D, segurar o direcional durante o golpe não desloca o jogador (só o quadro do clique, ~2 px). Save isolado.
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 40: await process_frame
	root.get_node("Transicao").limpar()
	set_meta("visual_base_3d_p1", true)
	root.get_node("Transicao").entrar_na_arena()
	for i in 600:
		await process_frame
		if current_scene.scene_file_path.contains("fendas/andar_") and not root.get_node("Transicao").ocupada: break
	for i in 60: await process_frame
	var j = current_scene.get_node("Jogador")
	print("GOLPE cena=", current_scene.scene_file_path, " base3d=", j.has_node("HeroiBase3D"), " bloqueado=", j.ataques_bloqueados, " fazenda=", j.modo_fazenda)
	j.equipar_espada()
	j.usando_espada = true
	j.usando_arco = false
	j.usando_lanca = false
	for i in 10: await process_frame
	Input.action_press("move_right")
	for i in 20: await physics_frame
	var andando: float = j.velocity.length()
	var inicio: Vector2 = j.global_position
	print("GOLPE foco=", j.get_viewport().gui_get_focus_owner(), " mov=", j.movimento_habilitado, " reacao=", j.no_reacao.visible, " espada=", j.usando_espada, " arma=", j.id_arma_atual, " sem_acao=", j._sem_acao_ate_ms - Time.get_ticks_msec())
	j.get_viewport().gui_release_focus()
	j._pedido_ataque = true
	var atacou := false
	var maior := 0.0
	var andou := 0.0
	for i in 25:
		var antes: Vector2 = j.global_position
		await physics_frame
		atacou = atacou or j._esta_atacando
		if j._esta_atacando:
			maior = maxf(maior, j.velocity.length())
			andou += j.global_position.distance_to(antes)
	Input.action_release("move_right")
	print("GOLPE andando_antes=%.1f atacou=%s velocidade_no_golpe=%.1f deslocamento=%.1f px" % [andando, atacou, maior, andou])
	print((("OK" if atacou and andando > 50 and andou <= 2.5 else "FALHA")) + " golpe parado")
	quit()
