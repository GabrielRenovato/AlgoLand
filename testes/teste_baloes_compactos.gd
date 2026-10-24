extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("GDConsole").hide()
	root.get_node("GDConsole").set_process_input(false)
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.mode = Window.MODE_WINDOWED
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var vila := current_scene
	vila.set_process(false)
	for npc in vila.moradores.values():
		npc.set_physics_process(false)
		npc.hide()
	var estela: Node2D = vila.moradores.mistica
	var rosa: Node2D = vila.moradores.curandeira
	for npc in [estela,rosa]:
		npc.visible = true
		npc.dormindo = false
		npc._saindo = false
		npc.caminho.clear()
		npc.sprite.visible = true
	rosa.position = Vector2(344,304)
	estela.position = rosa.position + Vector2(38,0)
	var jogador := vila.get_node("Jogador") as Node2D
	jogador.set_physics_process(false)
	jogador.position = rosa.position + Vector2(-120,-19)
	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(344,285)
	camera.reset_smoothing()
	var texto := "ESTELA: Desta vez eu levo o pao e como com voce. As estrelas podem esperar um pouco."
	for tamanho in [Vector2i(576,324),Vector2i(288,216),Vector2i(390,540)]:
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(20)
		for zoom in [1.0,2.0,3.0]:
			jogador.get_node("Camera2D").zoom = Vector2.ONE * zoom
			jogador.get_node("Camera2D").reset_smoothing()
			estela.dizer(texto,30)
			await quadros(20)
			for ajuste in 5:
				estela._ajustar_balao()
				await process_frame
			await RenderingServer.frame_post_draw
			var balao: Label = estela._balao
			var area: Rect2 = balao.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,balao.size)
			verificar("largura compacta com zoom %s em %s" % [zoom,tamanho],area.size.x <= 136.5)
			verificar("fala inteira e dentro da tela",balao.size.y >= balao.get_combined_minimum_size().y and estela.get_viewport_rect().grow(-7).encloses(area))
			var livre := true
			for obstaculo: Rect2 in estela._obstaculos_da_fala(): livre = livre and not area.intersects(obstaculo)
			verificar("fala separada de HUD e botões",livre)
			if not livre:
				print("CAIXA ",area," linhas=",balao.max_lines_visible," paginas=",balao.get_line_count())
				for obstaculo: Rect2 in estela._obstaculos_da_fala():
					if area.intersects(obstaculo): print("CRUZA ",obstaculo)
			var corpo: Rect2 = estela.get_global_transform_with_canvas() * Rect2(Vector2(-9,-26),Vector2(18,38))
			verificar("balão não cobre quem fala", not area.intersects(corpo))
			if zoom==2:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-balao-compacto-v2-%dx%d.png" % [tamanho.x,tamanho.y])
				if estela._fala_compacta:
					estela._inicio_fala = Time.get_ticks_msec()-29990
					estela._ajustar_balao()
					verificar("paginação chega à última linha sem cortar texto", balao.text == texto and balao.lines_skipped == balao.get_line_count()-1)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Baloes compactos: %d falhas" % falhas)
	quit(1 if falhas else 0)
