extends SceneTree
# Captura o jogador sentado nas duas cadeiras da casa (recorte ampliado ao redor da cadeira). Precisa de janela. Uso:
#   godot --path . --script res://ferramentas/fazenda/render_cadeira.gd -- <pasta_saida>
# Usa arquivos de teste para Progresso e Fazenda (nao toca nos saves reais). Salva cadeira_E.png e cadeira_D.png.

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_cadeira_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_cadeira_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var casa: Node = load("res://cenas/casa.tscn").instantiate()
	root.add_child(casa)
	current_scene = casa
	for i in 20:
		await process_frame
	var jogador: Node = casa.get_node("Jogador")
	jogador.roupa_atual = 6
	for chave in ["E", "D"]:
		var zona: Node = casa.get_node("ZonaCadeira" + chave)
		jogador.global_position = zona.global_position + Vector2(0, 8)
		for i in 8:
			await physics_frame
		zona.abrir_tela()
		for i in 30:
			await process_frame
		if OS.get_cmdline_user_args().size() > 1:
			jogador.visible = false
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var centro := img.get_size() / 2
		var recorte := img.get_region(Rect2i(centro.x - 150, centro.y - 150, 300, 300))
		recorte.resize(900, 900, Image.INTERPOLATE_NEAREST)
		recorte.save_png("%s/cadeira_%s.png" % [pasta, chave])
		jogador.pediu_levantar.emit()
		for i in 20:
			await process_frame
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
