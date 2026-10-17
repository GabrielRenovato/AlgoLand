extends SceneTree

func _initialize() -> void:
	_rodar.call_deferred()

func quadros(n := 10) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes carroca"):
		push_error("Use somente saves isolados da carroca.")
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	var comercio := root.get_node("Comercio")
	comercio.apagar()
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(320, 180)
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var cena := current_scene
	var camera := Camera2D.new()
	camera.position = Vector2(568, 274)
	cena.add_child(camera)
	camera.make_current()
	var jogador := cena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(520, 310)
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	var luz := cena.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	var calendario := root.get_node("Calendario")
	var estacoes := cena.get_node("Terrains/Estacoes")
	var carroca := cena.get_node("Carroca")
	for estacao in 4:
		calendario.dia = estacao * 7 + 1
		calendario.estacao_mudou.emit(estacao)
		estacoes.definir_estacao(estacao, true)
		for cor in 3:
			comercio.definir_pelagem(cor)
			await quadros(12)
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			var imagem := root.get_texture().get_image()
			imagem.save_png("res://arte/previas/comercio/cavalo_%s_%s.png" % [["preto", "marrom", "branco"][cor], ["primavera", "verao", "outono", "inverno"][estacao]])
			if estacao == 0:
				# Detalhe sem redimensionamento: pixels da renderização real do motor.
				var detalhe := imagem.get_region(Rect2i(225, 60, 510, 270))
				detalhe.save_png("res://arte/previas/comercio/detalhe_%s.png" % ["preto", "marrom", "branco"][cor])
			print("RENDER: estacao %d, pelagem %d, textura %s" % [estacao, cor, carroca.cavalo.texture.resource_path])
	comercio.definir_pelagem(1)
	print("REVISAO: 12 combinacoes de pelagem e estacao renderizadas.")
	quit()
