extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 8) -> void:
	for i in n: await process_frame
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(25)
	root.mode = Window.MODE_WINDOWED
	var jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var ui = root.get_node("EventosJogo").interface_p1()
	var tela = ui._telas["conversa_cidade"]
	var saida := ProjectSettings.globalize_path("res://arte/previas/botoes_carta")
	DirAccess.make_dir_recursive_absolute(saida)
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		root.get_node("Controle").usando_toque = tamanho.x == 288
		await esperar()
		for carta in ["boas_vindas","carta_pesca_0_0","misterio_1"]:
			root.get_node("Cidade").abrir_carta(jogador,carta)
			await esperar()
			var tentativas := 0
			while not tela._menu_assuntos.visible and tentativas < 20:
				conferir(tela._fala.size.y+0.1>=tela._fala.get_minimum_size().y,"Fala cabe na carta "+carta)
				tela._fala.visible_ratio = 1.0
				tela._avancar_fala()
				await esperar()
				tentativas += 1
			conferir(tela._menu_assuntos.visible,"Carta exibe as respostas "+carta)
			await esperar()
			var moldura: StyleBox = tela.painel.get_theme_stylebox("panel")
			var interior: Rect2 = tela.painel.get_global_rect()
			interior.position += Vector2(moldura.get_content_margin(SIDE_LEFT),moldura.get_content_margin(SIDE_TOP))
			interior.size -= moldura.get_minimum_size()
			conferir(interior.encloses(tela._menu_assuntos.get_global_rect()),"Respostas preservam margem do painel "+carta)
			var area: Rect2 = tela._rolagem.get_global_rect()
			for botao: Button in tela._botoes:
				conferir(area.encloses(botao.get_global_rect()),"Botão inteiro na carta %s %s: %s dentro de %s" % [carta,tamanho,botao.get_global_rect(),area])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida+"/%s-%dx%d.png" % [carta,tamanho.x,tamanho.y])
			ui._fechar_tela("conversa_cidade")
	print("BOTÕES CARTA: ",falhas," falhas")
	quit(1 if falhas else 0)
