extends SceneTree
# Captura uma cena na janela atual (para conferir a interface em proporções de celular). Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/fazenda/render_cena.gd -- --toque <cena.tscn> <saida.png> [segundos [botao]]
# Usa arquivos de teste para Progresso e Fazenda.

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var args: Array = []
	for a in OS.get_cmdline_user_args():
		if a != "--toque":
			args.append(a)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_cena_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_cena_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var cena: Node = load(args[0]).instantiate()
	root.add_child(cena)
	current_scene = cena
	await create_timer(float(args[2]) if args.size() > 2 else 1.0).timeout
	# 4º argumento (opcional): botão a apertar antes da foto (nome único, ex.: %BotaoOpcoes)
	if args.size() > 3:
		cena.get_node(args[3]).pressed.emit()
		await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png(args[1])
	print("salvo: ", args[1])
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
