extends SceneTree
## Captura a chefe na fenda real, sem acessar a partida do usuário.
const SAIDA := "res://arte/previas/inimigos/medusa/revisao_arte/"

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 6) -> void:
	for i in n:
		await process_frame
		await physics_frame

func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(576, 324)
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Saves").trocar("coop" if "--coop" in OS.get_cmdline_user_args() else "solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Transicao").retornando = true
	root.get_node("Transicao").estado = {"onda_atual": 3}
	root.get_node("Transicao").iniciar_onda_ao_chegar = false
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(20)
	root.get_node("Transicao").retornando = false
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var p2: Node2D = root.get_node("Cooperativo").jogador2()
	if p2 != null:
		p2.set_physics_process(false)
		p2.position = jogador.position + Vector2(-30, 20)
		p2.invulneravel = true
		p2.temporizador_invul = 999
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	var medusa: Node2D = load("res://cenas/inimigos/medusa.tscn").instantiate()
	medusa.position = jogador.position + Vector2(110, 10)
	current_scene.add_child(medusa)
	medusa.set_physics_process(false)
	medusa._definir_linha(Vector2.LEFT)
	medusa._tocar("movimento", 0)
	var camera := Camera2D.new()
	current_scene.add_child(camera)
	camera.global_position = jogador.global_position + Vector2(20, -30)
	camera.make_current()
	await create_timer(3.5).timeout
	if "--poses-pixellab" in OS.get_cmdline_user_args():
		await revisar_poses_pixellab(medusa, jogador, camera)
		current_scene.queue_free()
		current_scene = null
		await quadros()
		quit()
		return
	if "--estudo-garras" in OS.get_cmdline_user_args():
		await revisar_estudo_garras(medusa, jogador, camera)
		current_scene.queue_free()
		current_scene = null
		await quadros()
		quit()
		return
	if "--combate" in OS.get_cmdline_user_args():
		await revisar_combate(medusa, jogador)
		current_scene.queue_free()
		current_scene = null
		await quadros()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + "repouso.png")
	var inicio := medusa.position
	medusa._recarga = 99
	medusa.set_physics_process(true)
	for i in 12:
		await create_timer(0.05).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA + "movimento_%03d.png" % i)
	medusa.set_physics_process(false)
	medusa.position = inicio
	medusa.iniciar_ataque("ruina", jogador.global_position)
	for i in 90:
		if is_instance_valid(medusa):
			medusa._physics_process(0.05)
		if jogador.petrificacao != null:
			jogador.petrificacao.atualizar(0.05)
		if jogador.estaMorto:
			var fim := current_scene.get_node_or_null("Interface/TelaFimPartida")
			if fim != null:
				fim.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA + "quadro_%03d.png" % i)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit()

func revisar_poses_pixellab(medusa: Node2D, jogador: Node2D, camera: Camera2D) -> void:
	var pasta := "res://arte/previas/inimigos/medusa/pixellab/"
	jogador.invulneravel = true
	jogador.temporizador_invul = 999
	var registros: Array = []
	var argumentos := OS.get_cmdline_user_args()
	var filtro := argumentos.find("--direcao")
	for linha in 4:
		var rumo: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][linha]
		var nome: String = ["baixo", "cima", "direita", "esquerda"][linha]
		if filtro >= 0 and filtro + 1 < argumentos.size() and nome != argumentos[filtro + 1]:
			continue
		var destino := pasta + nome + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
		medusa._recuperar()
		medusa.estado = medusa.Estado.LIVRE
		medusa.position = jogador.position - rumo * 55
		camera.global_position = jogador.global_position - rumo * 25 + Vector2(0, -35)
		medusa.iniciar_ataque("garras", jogador.global_position)
		for indice in 108:
			medusa._physics_process(1.0 / 60.0)
			medusa._recarga = 99
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destino + "quadro_%03d.png" % indice)
			registros.append({"direcao": nome, "quadro": indice, "duracao_ms": 1000.0 / 60.0, "estado": medusa.estado, "acertou": medusa._acertou})
	FileAccess.open(pasta + "tempos.json", FileAccess.WRITE).store_string(JSON.stringify(registros))

func revisar_estudo_garras(medusa: Node2D, jogador: Node2D, camera: Camera2D) -> void:
	var pasta := "res://arte/previas/inimigos/medusa/poses_20261024/"
	var imagem := Image.load_from_file(pasta + "garras_direita_folha.png")
	medusa._folhas["garras"] = ImageTexture.create_from_image(imagem)
	medusa.position = jogador.position + Vector2(-55, 0)
	camera.global_position = jogador.global_position + Vector2(-25, -35)
	medusa._definir_linha(Vector2.RIGHT)
	jogador.invulneravel = true
	jogador.temporizador_invul = 999
	for indice in 6:
		medusa._tocar("garras", indice)
		medusa.sprite.material = null
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta + "chave_%02d.png" % indice)
	medusa.iniciar_ataque("garras", jogador.global_position)
	var registros: Array = []
	for indice in 120:
		medusa._physics_process(1.0 / 60.0)
		medusa.sprite.material = null
		if medusa.estado == medusa.Estado.LIVRE:
			medusa._recarga = 99
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta + "quadro_%03d.png" % indice)
		registros.append({"quadro": indice, "duracao_ms": 1000.0 / 60.0, "estado": medusa.estado, "pose": medusa.sprite.frame})
	var arquivo := FileAccess.open(pasta + "tempos_estudo.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(registros))

func revisar_combate(medusa: Node2D, jogador: Node2D) -> void:
	var coop := "--coop" in OS.get_cmdline_user_args()
	var pasta := "res://arte/previas/inimigos/medusa/combate_coop/" if coop else "res://arte/previas/inimigos/medusa/combate/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	jogador.invulneravel = true
	jogador.temporizador_invul = 999
	var registros: Array = []
	for fase in ([3] if coop else [1, 2, 3]):
		medusa.set_physics_process(false)
		medusa._sequencia.clear()
		medusa._recuperar()
		medusa.estado = medusa.Estado.LIVRE
		medusa.fase = fase
		medusa.vida = medusa.vida_maxima
		medusa._proxima_ruina = 2
		medusa._ruina_pendente = false
		medusa._padroes = 0
		medusa.position = jogador.position + Vector2(50, 10)
		medusa._direcao = Vector2.LEFT
		medusa._iniciar_padrao(jogador)
		var destino := pasta + "fase_%d/" % fase
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
		medusa.set_physics_process(true)
		for i in (50 if fase == 1 else (80 if fase == 2 else 100)):
			if medusa.estado == medusa.Estado.LIVRE:
				medusa._recarga = 99
			await create_timer(0.05).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destino + "quadro_%03d.png" % i)
			registros.append({"fase": fase, "quadro": i, "tempo_ms": Time.get_ticks_msec(), "estado": medusa.estado, "ataque": medusa.ataque_atual})
		medusa.set_physics_process(false)
	medusa._sequencia.clear()
	medusa._recuperar()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + "exposta_pc.png")
	if coop:
		medusa.estado = medusa.Estado.LIVRE
		medusa.iniciar_ataque("ruina", jogador.global_position)
		medusa._physics_process(1.4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta + "ruina_coop.png")
		return
	root.size = Vector2i(780, 1080)
	root.content_scale_size = Vector2i(390, 540)
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + "exposta_mobile.png")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(576, 324)
	await quadros()
	medusa.estado = medusa.Estado.LIVRE
	medusa._proxima_ruina = 0
	medusa._ruina_pendente = false
	medusa.vida = roundi(medusa.vida_maxima * 0.6)
	medusa._physics_process(0.01)
	medusa._physics_process(1.4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + "ruina_pc.png")
	root.size = Vector2i(780, 1080)
	root.content_scale_size = Vector2i(390, 540)
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + "ruina_mobile.png")
	var arquivo := FileAccess.open(pasta + "tempos.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(registros))
