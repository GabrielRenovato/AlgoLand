extends SceneTree

## Prévia da cidade inteira (dia e noite) com as fachadas e placas. Execute na cópia de testes (saves isolados).
## godot --path <copia> --script res://ferramentas/cidade/render_fachadas.gd -- <pasta> [hora]
func _initialize() -> void:
	_rodar()

func _quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute a previa com saves isolados.")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var pasta := args[0]
	var hora := float(args[1]) if args.size() > 1 else 12.0
	var dia := int(args[2]) if args.size() > 2 else 1
	# COLISOES=1 no ambiente desenha as formas de colisão
	if OS.get_environment("COLISOES") == "1":
		debug_collisions_hint = true
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1408, 1152)
	root.content_scale_size = Vector2i(704, 576)
	root.get_node("Calendario").dia = dia
	root.get_node("Transicao").hora_salva = hora
	var cena: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Iluminacao")._aplicar()
	# Quarto argumento: força a estação pelo nó Estacoes, como faz o painel F3
	if args.size() > 3:
		cena.get_node("Terrains/Estacoes").definir_estacao(int(args[3]), true)
		await _quadros(60)
	if debug_collisions_hint:
		for corpo in cena.find_children("*", "CollisionObject2D", true, false):
			corpo.z_as_relative = false
			corpo.z_index = 4000
	var jogador: Node = cena.get_node("Jogador")
	jogador.position = Vector2(392, 360)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(352, 288)
	var hud: Node = get_nodes_in_group("hud")[0]
	if hud.get_node_or_null("MiniTutorial") != null:
		hud.get_node("MiniTutorial").set_process(false)
		hud.get_node("MiniTutorial").visible = false
	# Deixa os lampiões reconhecerem o horário e terminarem de acender antes da captura.
	await _quadros(90)
	root.get_texture().get_image().save_png(pasta.path_join("fachadas_%d_d%d.png" % [int(hora), dia]))
	# Aproximação em duas casas (zoom 2 sobre a cena)
	root.content_scale_size = Vector2i(352, 288)
	jogador.camera.global_position = Vector2(float(args[4]), float(args[5])) if args.size() > 5 else Vector2(200, 230)
	await _quadros(10)
	root.get_texture().get_image().save_png(pasta.path_join("fachadas_perto_%d_d%d.png" % [int(hora), dia]))
	print("salvo")
	current_scene.queue_free()
	current_scene = null
	await _quadros()
	quit()
