extends SceneTree
# A tela de criação de personagem em outras proporções (576x324, 720x324 e 4:3), dentro de um SubViewport. Precisa de janela. Uso:
#   godot --path . --script res://ferramentas/personagem/render_criacao_tamanhos.gd -- <pasta_saida>
func _initialize() -> void:
	_rodar()
func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	for tamanho in [Vector2i(576, 324), Vector2i(720, 324), Vector2i(576, 432)]:
		var vp := SubViewport.new()
		vp.size = tamanho
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
		tela.trocar_cena = false
		vp.add_child(tela)
		root.add_child(vp)
		for i in 8:
			await process_frame
		tela._escolher_cabelo(5)
		tela._escolher_roupa(12)
		tela._abrir_aba(1)
		await create_timer(0.5).timeout
		var img := vp.get_texture().get_image()
		img.resize(tamanho.x * 3, tamanho.y * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/criacao_%dx%d.png" % [pasta, tamanho.x, tamanho.y])
		print("salvo ", tamanho)
		vp.queue_free()
		await process_frame
	quit()
