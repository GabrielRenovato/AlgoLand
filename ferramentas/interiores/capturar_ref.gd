extends SceneTree

func _initialize() -> void:
	_rodar()

func _quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(576, 324)
	root.content_scale_size = Vector2i(576, 324)
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node = load("res://cenas/cidade/ref_sala.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Iluminacao/CanvasModulate").color = Color.WHITE
	for no in get_nodes_in_group("hud"):
		no.visible = false
	cena.get_node("Vinheta").visible = false
	cena.get_node("Jogador").position = Vector2(-500, -500)
	for npc in get_nodes_in_group("moradores_cidade"):
		npc.visible = false
	await _quadros(20)
	var img := root.get_texture().get_image()
	img.save_png("/home/alfeim/AlgoLand/arte/fontes/cenario/interiores/ref_mana_tela.png")
	img.get_region(Rect2i(160, 34, 256, 176)).save_png("/home/alfeim/AlgoLand/arte/fontes/cenario/interiores/ref_mana_sala.png")
	quit()
