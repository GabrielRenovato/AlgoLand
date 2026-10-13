extends SceneTree
# Captura a arena e a fazenda com os controles na tela (celular). Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/fazenda/render_toque.gd -- --toque <pasta_saida>
# (a janela 1440x648 é o dobro de 720x324: celular comprido). Salva toque_arena.png, toque_arena_jogando.png (joystick e
# botões apertados) e toque_fazenda.png. Usa arquivos de teste para Progresso e Fazenda.

func _initialize() -> void:
	_rodar()

func _foto(pasta: String, nome: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])
	print("salvo: ", nome)

func _toque(dedo: int, pos: Vector2, apertou: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = dedo
	ev.position = pos * 2.0
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _arrasto(dedo: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = dedo
	ev.position = pos * 2.0
	Input.parse_input_event(ev)

func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[args.size() - 1]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_toque_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_toque_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var inventario := root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 30:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	inventario.equipar(inventario.buscar_por_tipo("espada_basica"))
	inventario.equipar(inventario.buscar_por_tipo("escudo_basico"))
	await create_timer(0.8).timeout
	_foto(pasta, "toque_arena")
	_toque(0, Vector2(90, 240), true)
	_arrasto(0, Vector2(125, 225))
	_toque(1, Vector2(666, 270), true)
	await create_timer(0.3).timeout
	_foto(pasta, "toque_arena_jogando")
	_toque(0, Vector2(125, 225), false)
	_toque(1, Vector2(666, 270), false)
	await create_timer(0.3).timeout
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
