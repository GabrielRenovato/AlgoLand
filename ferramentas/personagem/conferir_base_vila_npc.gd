extends SceneTree
## Compara a base NPC e suas oito animações na fazenda, com save isolado.
const FONTES := "res://arte/fontes/personagens/base_vila_npc/"
const PREVIAS := "res://arte/previas/personagens/base_vila_npc/"

func _initialize() -> void:
	rodar.call_deferred()

func esperar(n: int) -> void:
	for i in n:
		await process_frame

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var folha := Image.load_from_file(FONTES + "corrida-v1-80.png")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.visible = false
	var atores: Array[AnimatedSprite2D] = []
	for acao in ["corrida", "espada"]:
		folha = Image.load_from_file(FONTES + acao + "-v1-80.png")
		for direcao in 4:
			var quadros := SpriteFrames.new()
			quadros.set_animation_speed("default", 10.0)
			for indice in 8:
				var imagem := folha.get_region(Rect2i(indice * 80, direcao * 80, 80, 80))
				quadros.add_frame("default", ImageTexture.create_from_image(imagem), 5.0 if acao == "espada" and indice == 0 else 1.0)
			var ator := AnimatedSprite2D.new()
			ator.sprite_frames = quadros
			ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ator.centered = false
			ator.offset = Vector2(-40, -52)
			ator.position = jogador.position + Vector2((direcao - 1.5) * 34, 11 if acao == "corrida" else 75)
			ator.z_index = jogador.z_index + 3
			current_scene.add_child(ator)
			ator.play()
			atores.append(ator)
	var tomas := Image.load_from_file("res://assets/npcs/cidade/tomas.png")
	var modelo := Image.load_from_file(FONTES + "parado-v1-80.png")
	for linha in 2:
		var comparacao := Sprite2D.new()
		comparacao.texture = ImageTexture.create_from_image((tomas if linha == 0 else modelo).get_region(Rect2i(0,0,64 if linha == 0 else 80,64 if linha == 0 else 80)))
		comparacao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		comparacao.offset = Vector2(-32,-44) if linha == 0 else Vector2(-40,-52)
		comparacao.centered = false
		comparacao.position = jogador.position + Vector2(-85,11 if linha == 0 else 75)
		comparacao.z_index = jogador.z_index + 3
		current_scene.add_child(comparacao)
	await create_timer(2.4).timeout
	for indice in 12:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(PREVIAS + "godot_%02d.png" % indice)
		await create_timer(0.1).timeout
	print("BASE_NPC_GODOT: oito animações reproduzidas com tempos aprovados; 12 capturas e comparação com Tomas; save isolado.")
	quit()
