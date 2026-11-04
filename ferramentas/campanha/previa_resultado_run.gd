extends SceneTree
## Prévia do componente real, com dados demonstrativos. Não lê nem altera a partida.
func _initialize() -> void:rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:await process_frame;await physics_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	var destino := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):destino=arg.trim_prefix("--capturas=")
	if destino.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(destino)
	var saque := preload("res://codigo/campanha/catalogo_saque_inicial.gd")
	var rng := RandomNumberGenerator.new();rng.seed=12
	var drops: Array=[]
	for par in [["peitoral_guarda_novato","raro"],["botas_guarda_novato","comum"],["anel_cobre","comum"]]:
		drops.append({"item":saque.criar(par[0],par[1],rng).para_dict(),"recolhido":true})
	var dados := {"tempo":522,"inimigos":19,"abates":19,"chefe":true,"eu":"noel","pessoal":{"mortes":0,"recebido":186,"bloqueios":12,"abates":9},"drops":drops,"maestria":[{"familia":"espada","xp":128,"nivel":7}],"grupo":[{"id":"noel","nome":"Noel","dano":6400},{"id":"kael","nome":"Kael","dano":3840},{"id":"lyra","nome":"Lyra","dano":2560}]}
	root.mode=Window.MODE_WINDOWED
	for medida in [Vector2i(960,900),Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=medida;root.size=medida*2
		var tela := preload("res://codigo/campanha/tela_resultado.gd").new()
		root.add_child(tela)
		tela.apresentar(dados,"chegada");tela.show()
		root.warp_mouse(Vector2(1,1));await quadros(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destino.path_join("resultado-%dx%d.png" % [medida.x,medida.y]))
		if tela.abas!=null:
			tela.abas.current_tab=1;await quadros(8)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destino.path_join("resultado-%dx%d-ranking.png" % [medida.x,medida.y]))
		tela.queue_free();await process_frame
	quit()
