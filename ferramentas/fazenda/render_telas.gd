extends SceneTree
# Captura as telas do jogo (mochila, loja, acampamento...) numa janela de celular. Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/fazenda/render_telas.gd -- --toque <pasta_saida> [tela ...]
# Sem nomes de tela, captura todas. Usa arquivos de teste para Progresso e Fazenda; grava user://inventario.json.

const TELAS := ["inventario", "mercante", "acampamento", "mistica", "caldeirao", "dormir"]

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta := ""
	var nomes: Array = []
	for a in args:
		if a == "--toque":
			continue
		if pasta == "":
			pasta = a
		else:
			nomes.append(a)
	if nomes.is_empty():
		nomes = TELAS
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_telas_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_telas_fazenda.json"
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
	root.get_node("DadosJogo").moedas = 900
	root.get_node("Progresso").brasas = 120
	for nome in nomes:
		# "acampamento_moradores" abre o acampamento já na aba MORADORES
		var tela: String = nome.trim_suffix("_moradores")
		root.get_node("EventosJogo").abrir_tela.emit(tela)
		await create_timer(0.6).timeout
		if nome.ends_with("_moradores"):
			arena.get_node("Interface/TelaAcampamento").get_node("%AbaMoradores").pressed.emit()
			await create_timer(0.3).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/tela_%s.png" % [pasta, nome])
		print("salvo: ", nome)
		root.get_node("EventosJogo").fechar_tela.emit(tela)
		await create_timer(0.3).timeout
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
