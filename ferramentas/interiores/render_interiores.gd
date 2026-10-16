extends SceneTree

## Prévia dos seis interiores com as cenas reais. Execute na cópia de testes para preservar todos os saves.
## godot --path <copia> --script res://ferramentas/interiores/render_interiores.gd -- <pasta> [casa] [hora]
var pasta := ""

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
	pasta = args[0]
	var casas: Array = ["venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]
	if args.size() > 1 and args[1] != "todas":
		casas = [args[1]]
	var hora := float(args[2]) if args.size() > 2 else 12.0
	# Qualquer quarto argumento liga o desenho das colisões
	if args.size() > 3:
		debug_collisions_hint = true
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(576, 324)
	for casa in casas:
		if current_scene != null:
			current_scene.queue_free()
			await _quadros()
		root.get_node("Calendario").dia = 1
		root.get_node("Transicao").hora_salva = hora
		var cena: Node = load("res://cenas/cidade/%s.tscn" % casa).instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		cena.get_node("Iluminacao").set_process(false)
		cena.get_node("Iluminacao")._aplicar()
		var hud: Node = get_nodes_in_group("hud")[0]
		if hud.get_node_or_null("MiniTutorial") != null:
			hud.get_node("MiniTutorial").set_process(false)
			hud.get_node("MiniTutorial").visible = false
		await _quadros(20)
		root.get_texture().get_image().save_png(pasta.path_join("interior_%s_%d.png" % [casa, int(hora)]))
		print("salvo: ", casa)
	current_scene.queue_free()
	current_scene = null
	await _quadros()
	quit()
