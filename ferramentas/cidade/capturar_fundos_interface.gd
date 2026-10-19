extends SceneTree

## Captura a arte existente da vila em quatro estacoes, sem tocar os saves reais.
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		push_error("Use o projeto e saves isolados de teste.")
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Saves").trocar("solo")
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(704,576)
	root.size = Vector2i(704,576)
	DirAccess.make_dir_recursive_absolute("res://assets/ui/fundos_menu")
	for estacao in 4:
		root.get_node("Calendario").dia = 1+estacao*30
		root.get_node("Transicao").hora_salva = 12
		change_scene_to_file("res://cenas/cidade.tscn")
		await quadros(25)
		var jogador = current_scene.get_node("Jogador")
		jogador.desabilitar_todas_acoes(true)
		jogador.set_physics_process(false)
		jogador.global_position = Vector2(352,288)
		jogador.hide()
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.zoom = Vector2.ONE
		jogador.camera.offset = Vector2.ZERO
		jogador.camera.reset_smoothing()
		root.get_node("EventosJogo").interface_p1().hide()
		get_first_node_in_group("hud_p1").hide()
		current_scene.get_node("Iluminacao").set_process(false)
		current_scene.get_node("Iluminacao").definir_hora(12)
		var clima = get_first_node_in_group("clima")
		if clima != null: clima.definir_clima(0,true)
		for morador in current_scene.moradores.values():
			morador.set_physics_process(false)
			morador.hide()
		if estacao == 0:
			var pontos := [Vector2(320,304),Vector2(344,320),Vector2(344,368),Vector2(344,416),Vector2(368,440),Vector2(400,448),Vector2(456,448),Vector2(400,448),Vector2(344,432),Vector2(328,400),Vector2(328,352)]
			var rotas := []
			for indice in pontos.size():
				var rota := []
				for ponto in current_scene.caminho_entre(pontos[indice],pontos[(indice+1)%pontos.size()]): rota.append([ponto.x,ponto.y])
				rotas.append(rota)
			var arquivo := FileAccess.open("res://assets/ui/fundos_menu/rotas.json",FileAccess.WRITE)
			arquivo.store_string(JSON.stringify({"tamanho":[704,576],"origem":[0,0],"rotas":rotas},"\t"))
		if OS.get_cmdline_user_args().has("--somente-rotas"): break
		await quadros(12)
		await RenderingServer.frame_post_draw
		var nome: String = ["primavera","verao","outono","inverno"][estacao]
		root.get_texture().get_image().save_png("res://assets/ui/fundos_menu/"+nome+".png")
		print("FUNDO ",nome)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit()
