extends SceneTree

## Captura o jogador em 1:1 (quadro parado de frente, sem HUD) para servir de referência de proporção e estilo.
## Execute na cópia de testes: godot --path <copia> --script res://ferramentas/personagem/capturar_jogador.gd -- <arquivo.png>
func _initialize() -> void:
	_rodar()

func _quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	var destino := OS.get_cmdline_user_args()[0]
	RenderingServer.set_default_clear_color(Color(1, 0, 1))
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(576, 324)
	root.content_scale_size = Vector2i(576, 324)
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node = load("res://cenas/cidade/venda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Iluminacao").get_node("CanvasModulate").color = Color.WHITE
	for no in get_nodes_in_group("hud"):
		no.visible = false
	cena.get_node("Vinheta").visible = false
	cena.get_node("Fundo").visible = false
	cena.get_node("Interior").visible = false
	for npc in get_nodes_in_group("moradores_cidade"):
		npc.visible = false
	var jogador: Node2D = cena.get_node("Jogador")
	jogador.position = Vector2(128, 101)
	await _quadros(20)
	var imagem := root.get_texture().get_image()
	# O centro da tela é o centro da câmera (128, 101): recorte de 64x64 em volta do jogador
	var recorte := imagem.get_region(Rect2i(288 - 32, 162 - 32, 64, 64))
	recorte.convert(Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var c := recorte.get_pixel(x, y)
			if c.r > 0.97 and c.g < 0.03 and c.b > 0.97:
				recorte.set_pixel(x, y, Color(0, 0, 0, 0))
	recorte.save_png(destino)
	print("salvo: ", destino, " usado: ", recorte.get_used_rect())
	quit()
