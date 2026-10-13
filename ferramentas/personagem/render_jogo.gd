extends SceneTree
# O personagem com um cabelo e uma roupa novos em várias poses no jogo (parado, correndo, golpe de espada e de lança, aparar, arco,
# enxada e sentado). Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/personagem/render_jogo.gd -- --toque <pasta_saida> <cabelo> <roupa>
# Cada foto é um recorte ampliado em volta do jogador; grava user://inventario.json (faça backup do user:// antes).

func _initialize() -> void:
	_rodar()

func _foto(img_pasta: String, nome: String, tiras: Array) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var c := img.get_size() / 2
	var r := img.get_region(Rect2i(c.x - 90, c.y - 100, 180, 160))
	r.resize(360, 320, Image.INTERPOLATE_NEAREST)
	tiras.append(r)

func _salvar(tiras: Array, caminho: String) -> void:
	var t := Image.create(360 * tiras.size(), 320, false, Image.FORMAT_RGBA8)
	for i in tiras.size():
		t.blit_rect(tiras[i], Rect2i(0, 0, 360, 320), Vector2i(i * 360, 0))
	t.save_png(caminho)
	print("salvo ", caminho)

func _rodar() -> void:
	var args: Array = []
	for a in OS.get_cmdline_user_args():
		if a != "--toque":
			args.append(a)
	var pasta: String = args[0]
	var cabelo := int(args[1])
	var roupa := int(args[2])
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_pecas_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_pecas_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 30:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador: Node = arena.get_node("Jogador")
	jogador.cor_cabelo = Color(0.35, 0.6, 1.0)
	jogador.definir_aparencia(cabelo, roupa)
	var tiras: Array = []
	# parado e correndo (sem arma)
	await create_timer(0.4).timeout
	_foto(pasta, "parado", tiras)
	# espada e escudo: golpes
	inv.equipar(inv.buscar_por_tipo("espada_basica"))
	inv.equipar(inv.buscar_por_tipo("escudo_basico"))
	await create_timer(0.6).timeout
	var ev := InputEventAction.new()
	ev.action = &"attack"
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.12).timeout
	_foto(pasta, "golpe_espada", tiras)
	ev.pressed = false
	Input.parse_input_event(ev)
	await create_timer(0.7).timeout
	# aparar
	Input.action_press("aparar")
	await create_timer(0.2).timeout
	_foto(pasta, "aparar", tiras)
	Input.action_release("aparar")
	await create_timer(0.4).timeout
	# lança
	inv.equipar(inv.buscar_por_tipo("lanca_basica"))
	await create_timer(0.6).timeout
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.2).timeout
	_foto(pasta, "golpe_lanca", tiras)
	ev.pressed = false
	Input.parse_input_event(ev)
	await create_timer(0.8).timeout
	_salvar(tiras, "%s/pecas_%d_%d.png" % [pasta, cabelo, roupa])
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
