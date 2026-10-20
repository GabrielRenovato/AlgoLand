extends SceneTree
## Revisão do controlador real, somente em projeto com saves isolados.
func _initialize() -> void:
	rodar.call_deferred()

func esperar(n: int) -> void:
	for i in n:
		await process_frame

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(384, 216)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var visual := jogador.get_node("HeroiCraftpix")
	visual.set_process(false)
	assert(visual.scale == Vector2.ONE)
	# Referência nativa no mesmo chão e câmera; nó só existe nesta revisão.
	var referencia := Sprite2D.new()
	referencia.texture = load("res://assets/npcs/cidade/tomas.png")
	referencia.hframes = 7
	referencia.vframes = 4
	referencia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	referencia.centered = false
	referencia.offset = Vector2(-32, -44)
	referencia.position = jogador.position + Vector2(-30, 11)
	referencia.z_index = jogador.z_index + 3
	current_scene.add_child(referencia)
	assert(visual.visible and not jogador.get_node("CompositeSprites").visible)
	var direcoes := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	for direcao in direcoes:
		jogador._direcao_ataque = direcao
		jogador.velocity = Vector2.ZERO
		jogador.usando_espada = false
		visual._process(0.0)
		assert(visual.visible and visual.frame / visual.hframes == direcoes.find(direcao))
		for i in 16:
			visual._process(0.1)
			assert(visual.frame % visual.hframes < (4 if direcao == Vector2.UP else 12))
		jogador.velocity = direcao * 80
		visual._process(0.1)
		assert(visual._animacao == "unarmed_run")
		jogador.usando_espada = true
		jogador._esta_atacando = true
		visual._process(0.05)
		assert(visual._animacao == "sword_attack")
		print("Direção validada: ", direcao, " parado, corrida e ataque")
		jogador._esta_atacando = false
	jogador.velocity = Vector2.ZERO
	jogador._direcao_ataque = Vector2.DOWN
	jogador.usando_espada = false
	visual._process(0.0)
	jogador.esta_em_acao_fazenda = true
	visual._process(0.0)
	assert(not visual.visible and jogador.get_node("CompositeSprites").visible)
	jogador.esta_em_acao_fazenda = false
	visual._process(0.0)
	await esperar(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-craftpix-no-jogo.png")
	print("CRAFTPIX OK: controlador real, quatro direções e retorno de ferramentas; save isolado.")
	change_scene_to_file("res://cenas/menu.tscn") if ResourceLoader.exists("res://cenas/menu.tscn") else current_scene.queue_free()
	await esperar(8)
	quit()
