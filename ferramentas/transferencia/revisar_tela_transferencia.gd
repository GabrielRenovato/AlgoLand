extends SceneTree
## Fotografa o painel TRANSFERIR SAVE da tela inicial em PC (576x324) e celular (288x512). Save isolado.
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	FileAccess.open("user://configuracao_jogador.json", FileAccess.WRITE).store_string("{}")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/transferencia/"))
	for tamanho in [Vector2i(576, 324), Vector2i(288, 512)]:
		var vp := SubViewport.new()
		vp.size = tamanho
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var tela = load("res://cenas/inicio_do_jogo.tscn").instantiate()
		vp.add_child(tela)
		for i in 40: await process_frame
		conferir_menu(tela)
		tela._botao_transferencia.pressed.emit()
		for i in 5: await process_frame
		tela._campo_codigo.text = "K7P-4QX"
		tela._aviso_transferencia.text = "CODIGO: XAC-UV3\nDIGITE NO OUTRO APARELHO EM ATE 15 MINUTOS. SO VALE UMA VEZ."
		tela._ajustar_layout_flex()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(tamanho.x*3, tamanho.y*3, Image.INTERPOLATE_NEAREST)
		img.save_png("res://arte/previas/transferencia/painel_%dx%d.png" % [tamanho.x, tamanho.y])
		var moldura: Control = tela._moldura_transferencia
		var cabe := Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(moldura.get_global_rect())
		print(("OK   " if cabe else "FALHA ") + "painel cabe em %s (%s)" % [tamanho, moldura.get_global_rect()])
		vp.queue_free()
		await process_frame
	quit()
func conferir_menu(tela) -> void:
	print(("OK   " if tela._botao_transferencia.is_visible_in_tree() else "FALHA ") + "botao TRANSFERIR SAVE no menu")
