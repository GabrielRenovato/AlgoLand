extends SceneTree
## Tela de criação com a escolha de olhos, em PC e celular; confere margens e o dado gravado.
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/personagens/base_3d/acabamento/"))
	for tamanho in [Vector2i(576,324), Vector2i(288,512)]:
		var vp := SubViewport.new()
		vp.size = tamanho
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
		tela.trocar_cena = false
		tela.caminho_save = "user://teste_olhos.json"
		vp.add_child(tela)
		for i in 10: await process_frame
		for i in 30: await process_frame
		tela._botoes_olhos[2].pressed.emit()
		tela._escolher_peca_3d("cabelo", "cabelo_cacheado")
		tela._escolher_peca_3d("camisa", "blusa_bufante")
		tela._escolher_peca_3d("calca", "saia_pregas")
		tela._escolher_cor(tela.PALETA[4])
		tela._abrir_aba(1 if "--roupa" in OS.get_cmdline_user_args() else 0)
		for i in 15: await process_frame
		var fora := 0
		for b in tela._botoes_olhos:
			if b.is_visible_in_tree() and not Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(b.get_global_rect()): fora += 1
		print("CRIACAO %s olhos=%d gravado=%s roupas=%s casas_fora=%d visiveis=%s" % [tamanho, tela.olhos, tela.dados_do_personagem().aparencia_raven.get("olhos"), tela.dados_do_personagem().get("roupas_3d"), fora, tela._botoes_olhos[0].is_visible_in_tree()])
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(tamanho.x*3, tamanho.y*3, Image.INTERPOLATE_NEAREST)
		img.save_png("res://arte/previas/personagens/base_3d/acabamento/criacao_3d_%dx%d%s.png" % [tamanho.x, tamanho.y, "_roupa" if "--roupa" in OS.get_cmdline_user_args() else ""])
		vp.queue_free()
		await process_frame
	quit()
