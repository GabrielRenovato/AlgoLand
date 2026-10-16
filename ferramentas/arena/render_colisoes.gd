extends SceneTree
# A arena com as colisões e a malha de navegação visíveis (conferir se fogueira, árvores, pedras e lago têm a colisão onde o desenho está).
# Precisa de janela. Uso: godot --path . --script res://ferramentas/arena/render_colisoes.gd -- <saida.png> [x y]
# (x y = posição do jogador em coordenadas do mundo; a câmera o segue)
func _initialize() -> void:
	_rodar()
func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_col_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_col_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	debug_collisions_hint = true
	debug_navigation_hint = true
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 20:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	if a.size() >= 3:
		arena.get_node("Jogador").global_position = Vector2(float(a[1]), float(a[2]))
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	print("salvo ", a[0])
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
