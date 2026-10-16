extends SceneTree

## Mostra as capas nas quatro direções, com os sprites e o clima reais. Só em saves isolados.
func _initialize() -> void:
	_rodar()

func quadros(n := 12) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var pasta := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").definir_clima_hoje(2)
	root.get_node("Transicao").hora_salva = 12.0
	var vila: Node2D = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros()
	vila.set_process(false)
	vila.get_node("Iluminacao").set_process(false)
	vila.get_node("Iluminacao")._aplicar()
	var jogador: Node2D = vila.get_node("Jogador")
	jogador.position = Vector2(490, 350)
	jogador.set_physics_process(false)
	var camera := Camera2D.new()
	camera.position = Vector2(312, 278)
	camera.zoom = Vector2(1.4, 1.4)
	vila.add_child(camera)
	camera.make_current()
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	var i := 0
	for npc in vila.moradores.values():
		npc.set_physics_process(false)
		npc.position = Vector2(204 + i * 40, 300)
		npc.visible = true
		npc.sprite.frame = (i % 4) * npc._colunas
		npc.z_index = load("res://codigo/globais/profundidade.gd").z_de(309)
		i += 1
	await quadros(50)
	root.get_texture().get_image().save_png(pasta.path_join("moradores_capas_chuva_no_jogo.png"))
	vila.queue_free()
	current_scene = null
	await quadros()
	quit()
