extends SceneTree

## Sequência real do relógio e das sombras solares. Só executa com saves isolados.
## godot --path <cópia> --script res://ferramentas/cidade/render_sombras.gd -- <pasta>
func _initialize() -> void:
	_rodar()

func _quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute a prévia com saves isolados.")
		quit(1)
		return
	var pasta := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1408, 1152)
	root.content_scale_size = Vector2i(704, 576)
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 8.0
	var cena: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	var jogador: Node = cena.get_node("Jogador")
	jogador.position = Vector2(392, 360)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(352, 288)
	var tutorial: Node = get_nodes_in_group("hud")[0].get_node("MiniTutorial")
	tutorial.set_process(false)
	tutorial.visible = false
	var luz: Node = cena.get_node("Iluminacao")
	luz.set_process(false)
	for hora in [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20]:
		luz.definir_hora(float(hora))
		luz._aplicar()
		await _quadros(60)
		root.get_texture().get_image().save_png(pasta.path_join("hora_%02d.png" % hora))
	print("sequência solar salva")
	current_scene.queue_free()
	current_scene = null
	await _quadros()
	quit()
