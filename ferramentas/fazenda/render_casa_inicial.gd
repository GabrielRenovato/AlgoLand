extends SceneTree

## Prévia das cenas reais com saves isolados. Argumento: pasta de saída absoluta.
func _initialize() -> void:
	_rodar()

func _quadros(n := 12) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute a prévia na cópia de testes, com saves isolados.")
		quit(1)
		return
	var pasta := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	root.size = Vector2i(960, 720)
	root.content_scale_size = Vector2i(320, 240)
	for tomada in range(5):
		var interior := tomada == 4
		var estacao := tomada % 4
		root.get_node("Transicao").hora_salva = 12.0
		root.get_node("Calendario").dia = estacao * 7 + 1
		var cena: Node2D = load("res://cenas/casa.tscn" if interior else "res://cenas/fazenda.tscn").instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		var jogador: Node2D = cena.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.position = Vector2(152, 156) if interior else Vector2(376, 255)
		var camera := Camera2D.new()
		camera.position = Vector2(128, 112) if interior else Vector2(376, 181)
		cena.add_child(camera)
		camera.make_current()
		for hud in get_nodes_in_group("hud"):
			hud.hide()
		if not interior:
			var luz: Node = cena.get_node("Iluminacao")
			luz.hora = 12.0
			luz.set_process(false)
			luz._aplicar()
		await _quadros(30)
		var nome: String = "interior" if interior else ["primavera", "verao", "outono", "inverno"][estacao]
		root.get_texture().get_image().save_png(pasta.path_join("casa_inicial_%s.png" % nome))
		cena.queue_free()
		current_scene = null
		await _quadros()
	quit()
