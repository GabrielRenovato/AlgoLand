extends SceneTree
# Captura a tela de criação de personagem (as 3 abas, uma peça escolhida) numa janela de celular. Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/personagem/render_criacao.gd -- --toque <pasta_saida> [cabelo roupa]
func _initialize() -> void:
	_rodar()
func _rodar() -> void:
	var args: Array = []
	for a in OS.get_cmdline_user_args():
		if a != "--toque":
			args.append(a)
	var pasta: String = args[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena = false
	root.add_child(tela)
	current_scene = tela
	await create_timer(0.8).timeout
	if args.size() > 2:
		tela._escolher_cabelo(int(args[1]))
		tela._escolher_roupa(int(args[2]))
	for aba in 3:
		tela._abrir_aba(aba)
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/criacao_aba%d.png" % [pasta, aba])
		print("salvo aba ", aba)
	quit()
