extends SceneTree
# Captura a transicao arena -> fazenda (caverna) como o jogador a ve: fade para preto, fade de entrada e a chegada.
# Precisa de janela (nao headless). Uso:
#   godot --path . --script res://ferramentas/fazenda/render_transicao.gd -- <pasta_saida>
# Usa arquivos de teste para Progresso e Calendario (nao toca nos saves reais) e salva 4 PNGs: transicao_1_fade_saida,
# transicao_2_preto, transicao_3_fade_entrada, transicao_4_chegada_fazenda.

func _initialize() -> void:
	_rodar()

func _foto(pasta: String, nome: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var caminho := "%s/%s.png" % [pasta, nome]
	img.save_png(caminho)
	print("salvo: ", caminho, " ", img.get_size())

func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	var progresso := root.get_node("Progresso")
	var calendario := root.get_node("Calendario")
	progresso.caminho_save = "user://render_transicao_progresso.json"
	calendario.caminho_save = "user://render_transicao_calendario.json"
	progresso.apagar()
	calendario.apagar()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 30:
		await process_frame
	var jogador := arena.get_node("Jogador")
	var passagem := arena.get_node("Terrains/PassagemCaverna")
	jogador.global_position = passagem.global_position + Vector2(0, -9)
	for i in 10:
		await physics_frame
	passagem.abrir_tela()
	await create_timer(0.17).timeout
	_foto(pasta, "transicao_1_fade_saida")
	var transicao := root.get_node("Transicao")
	while not transicao.esta_escuro():
		await process_frame
	_foto(pasta, "transicao_2_preto")
	# a cena nova entra com o fade ainda escuro e clareia: pega no meio da subida
	while current_scene == arena or current_scene == null:
		await process_frame
	await create_timer(0.3).timeout
	_foto(pasta, "transicao_3_fade_entrada")
	await create_timer(1.2).timeout
	_foto(pasta, "transicao_4_chegada_fazenda")
	progresso.apagar()
	calendario.apagar()
	quit()
