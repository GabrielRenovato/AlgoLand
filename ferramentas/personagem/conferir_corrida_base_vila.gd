extends SceneTree
## Reproduz as quatro corridas em cenário real com save de teste.
const FONTES := "res://arte/fontes/personagens/base_vila_estudo/"
const PREVIAS := "res://arte/previas/personagens/base_vila_estudo/"

func _initialize() -> void:
	rodar.call_deferred()

func esperar(n: int) -> void:
	for i in n:
		await process_frame

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var folha := Image.load_from_file(FONTES + "corrida-v1-64.png")
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
	for direcao in 4:
		var quadros := SpriteFrames.new()
		quadros.set_animation_speed("default", 10.0)
		for indice in 8:
			var imagem := folha.get_region(Rect2i(indice * 64, direcao * 64, 64, 64))
			quadros.add_frame("default", ImageTexture.create_from_image(imagem))
		var ator := AnimatedSprite2D.new()
		ator.sprite_frames = quadros
		ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ator.centered = false
		ator.offset = Vector2(-32, -44)
		ator.position = jogador.position + Vector2((direcao - 1.5) * 30, 11)
		ator.z_index = jogador.z_index + 3
		current_scene.add_child(ator)
		ator.play()
		atores.append(ator)
	await create_timer(1.6).timeout
	for indice in 8:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(PREVIAS + "corrida_quatro_direcoes/godot_%d.png" % indice)
		await create_timer(0.1).timeout
	print("CORRIDA_GODOT: quatro animações a 10 FPS reproduzidas; oito capturas; save isolado.")
	quit()
