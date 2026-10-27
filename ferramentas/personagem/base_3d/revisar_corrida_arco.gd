extends SceneTree
## Corrida com arco (mixamo/BowRun) ou, com -- --sem-arco, a corrida normal (mixamo/Running), no jogo de verdade:
## equipa o arco, anda com as teclas nas quatro direções e fotografa seis momentos de cada. Save isolado.
const SAIDA := "res://arte/previas/personagens/base_3d/corrida_arco/"
const RECORTE := 110
const AMPLIAR := 3
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 35: await process_frame
	root.get_node("Transicao").limpar()
	root.get_node("PainelDebug")._ativar_base_3d("--roupas" in OS.get_cmdline_user_args())
	var jogador = current_scene.get_node("Jogador")
	var com_arco := not "--sem-arco" in OS.get_cmdline_user_args()
	if com_arco: jogador.equipar_arco()
	var heroi = jogador.get_node("HeroiBase3D")
	for i in 20: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var folha := Image.create(RECORTE*AMPLIAR*6, RECORTE*AMPLIAR*4, false, Image.FORMAT_RGBA8)
	var linha := 0
	var animacoes := {}
	for acao in ["move_down", "move_right", "move_up", "move_left"]:
		Input.action_press(acao)
		for i in 12: await process_frame
		for q in 6:
			for i in 4: await process_frame
			animacoes[heroi._player.assigned_animation] = true
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var escala := Vector2(img.get_size())/root.get_visible_rect().size
			var centro: Vector2 = jogador.get_global_transform_with_canvas().origin*escala
			var parte := img.get_region(Rect2i(Vector2i(centro)-Vector2i(RECORTE/2, RECORTE*3/4), Vector2i(RECORTE, RECORTE)))
			parte.convert(Image.FORMAT_RGBA8)
			parte.resize(RECORTE*AMPLIAR, RECORTE*AMPLIAR, Image.INTERPOLATE_NEAREST)
			folha.blit_rect(parte, Rect2i(0, 0, RECORTE*AMPLIAR, RECORTE*AMPLIAR), Vector2i(q*RECORTE*AMPLIAR, linha*RECORTE*AMPLIAR))
		Input.action_release(acao)
		for i in 20: await process_frame
		linha += 1
	folha.save_png(SAIDA+("folha.png" if com_arco else "folha_sem_arco.png").replace(".png", "_roupas.png" if "--roupas" in OS.get_cmdline_user_args() else ".png"))
	print("CORRIDA ARCO usou: ", animacoes.keys(), " arco visivel=", heroi._arco_visual.visible)
	quit()
