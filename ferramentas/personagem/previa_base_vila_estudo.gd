extends SceneTree
## Estudo estático: prepara e mostra a base sem substituir o jogador.
const FONTES := "res://arte/fontes/personagens/base_vila_estudo/"
const PREVIAS := "res://arte/previas/personagens/base_vila_estudo/"

func _initialize() -> void:
	rodar.call_deferred()

func esperar(n: int) -> void:
	for i in n:
		await process_frame

func preparar() -> Image:
	var origem := Image.load_from_file(FONTES + "parado-v1-original.png")
	origem.convert(Image.FORMAT_RGBA8)
	for y in origem.get_height():
		for x in origem.get_width():
			var cor := origem.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= 0.5 else 0.0
			origem.set_pixel(x, y, cor)
	var altura := 0
	var quadros: Array[Image] = []
	for i in 4:
		var inicio := origem.get_width() * i / 4
		var fim := origem.get_width() * (i + 1) / 4
		var quadro := origem.get_region(Rect2i(inicio, 0, fim - inicio, origem.get_height()))
		quadros.append(quadro)
		altura = maxi(altura, quadro.get_used_rect().size.y)
	var folha := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	var escala := 31.0 / altura
	for i in 4:
		var area := quadros[i].get_used_rect()
		var recorte := quadros[i].get_region(area)
		recorte.resize(roundi(area.size.x * escala), roundi(area.size.y * escala), Image.INTERPOLATE_NEAREST)
		folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(i * 64 + (64 - recorte.get_width()) / 2, 44 - recorte.get_height()))
	folha.save_png(FONTES + "parado-v1-64.png")
	return folha

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var folha := preparar()
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
	var imagens: Array[Image] = []
	var tomas := Image.load_from_file("res://assets/npcs/cidade/tomas.png")
	imagens.append(tomas.get_region(Rect2i(0, 0, 64, 64)))
	for i in 4:
		imagens.append(folha.get_region(Rect2i(i * 64, 0, 64, 64)))
	for i in imagens.size():
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(imagens[i])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = Vector2(-32, -44)
		sprite.position = jogador.position + Vector2((i - 2) * 28, 11)
		sprite.z_index = jogador.z_index + 3
		current_scene.add_child(sprite)
	await esperar(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PREVIAS + "comparacao_no_godot.png")
	print("ESTUDO: Tomas à esquerda e quatro vistas da nova base, altura31px, sem trocar jogador.")
	quit()
