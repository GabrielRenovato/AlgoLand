extends SceneTree

## Prévias reais e quadros de movimento, sempre com saves isolados.
var pasta: String

func _initialize() -> void:
	_rodar()

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute na cópia de testes.")
		quit(1)
		return
	pasta = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1056, 864)
	root.content_scale_size = Vector2i(352, 288)
	for id in ["cidade", "venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]:
		if current_scene != null:
			current_scene.queue_free()
			current_scene = null
			await quadros()
		root.get_node("Calendario").dia = 1
		root.get_node("Transicao").hora_salva = 12.0
		var caminho: String = "res://cenas/cidade.tscn" if id == "cidade" else "res://cenas/cidade/" + id + ".tscn"
		var cena: Node2D = load(caminho).instantiate()
		root.add_child(cena)
		current_scene = cena
		await quadros()
		cena.get_node("Iluminacao").set_process(false)
		for hud in get_nodes_in_group("hud"):
			hud.visible = false
		var jogador := cena.get_node("Jogador")
		jogador.camera.position_smoothing_enabled = false
		if id == "cidade":
			jogador.camera.set_as_top_level(true)
			jogador.camera.global_position = Vector2(170, 480)
		for estacao in 4:
			root.get_node("Calendario").dia = 1 + estacao * 7
			if id == "cidade":
				cena.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
			await quadros(40)
			await process_frame
			root.get_texture().get_image().save_png(pasta.path_join("%s_%d.png" % [id, estacao]))
		if id in ["cidade", "pousada", "mistica"]:
			for q in 12:
				await create_timer(0.16).timeout
				await process_frame
				root.get_texture().get_image().save_png(pasta.path_join("%s_anim_%02d.png" % [id, q]))
		print("PRÉVIA ", id)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit()
