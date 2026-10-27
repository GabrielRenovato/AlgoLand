extends SceneTree
## Abre F3 → CUSTOMIZAR ROUPAS 3D na fazenda (save isolado) e fotografa a tela inteira.
## -- --tamanho=576x324 (padrão) ou 288x512; -- --pixel liga o acabamento pixel art.
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var tamanho := Vector2i(576, 324)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tamanho="): tamanho = Vector2i(int(a.get_slice("=",1).get_slice("x",0)), int(a.get_slice("=",1).get_slice("x",1)))
	root.content_scale_size = tamanho
	DisplayServer.window_set_size(tamanho*3)
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 40: await process_frame
	root.get_node("Transicao").limpar()
	root.get_node("PainelDebug")._ativar_base_3d(true, "--pixel" in OS.get_cmdline_user_args())
	for i in 10: await process_frame
	root.get_node("PainelDebug")._customizar_roupas_3d()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	var nome := "personalizacao_3d_%dx%d%s.png" % [tamanho.x, tamanho.y, "_pixel" if "--pixel" in OS.get_cmdline_user_args() else ""]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/personagens/base_3d/acabamento/"))
	root.get_texture().get_image().save_png("res://arte/previas/personagens/base_3d/acabamento/"+nome)
	print("TELA salva ", nome, " janela=", root.get_visible_rect().size)
	quit()
