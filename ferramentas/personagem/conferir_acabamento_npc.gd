extends SceneTree
## Tomas, Caio, versão aprovada e controlador atual na mesma cena/escala.
const PREVIA := "res://arte/previas/personagens/base_vila_npc/v2_acabamento/"

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
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.usando_espada = false
	jogador.velocity = Vector2.ZERO
	jogador._direcao_ataque = Vector2.DOWN
	var visual := jogador.get_node("HeroiBaseVila")
	visual._process(0.0)
	var antigo := Sprite2D.new()
	var imagens := [Image.load_from_file("res://assets/npcs/cidade/tomas.png"), Image.load_from_file("res://assets/npcs/cidade/caio.png"), Image.load_from_file("res://arte/fontes/personagens/base_vila_npc/parado-v1-80.png")]
	for i in 4:
		if i < 3:
			var tamanho := 64 if i < 2 else 80
			var ator := antigo if i == 2 else Sprite2D.new()
			ator.texture = ImageTexture.create_from_image(imagens[i].get_region(Rect2i(0, 0, tamanho, tamanho)))
			ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ator.centered = false
			ator.offset = Vector2(-32, -44) if i < 2 else Vector2(-40, -52)
			ator.position = jogador.position + Vector2((i - 3) * 40, 11)
			ator.z_index = jogador.z_index + 3
			current_scene.add_child(ator)
		var rotulo := Label.new()
		rotulo.text = ["TOMAS", "CAIO", "ANTES", "AGORA"][i]
		rotulo.add_theme_font_size_override("font_size", 7)
		rotulo.add_theme_color_override("font_color", Color.WHITE)
		rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
		rotulo.add_theme_constant_override("shadow_offset_x", 1)
		rotulo.add_theme_constant_override("shadow_offset_y", 1)
		rotulo.position = jogador.position + Vector2((i - 3) * 40 - 13, -32)
		rotulo.z_index = 1000
		current_scene.add_child(rotulo)
	await esperar(4)
	await RenderingServer.frame_post_draw
	var captura := root.get_texture().get_image()
	captura.save_png(PREVIA + "comparacao_no_jogo.png")
	var recorte := Rect2i(roundi(captura.get_width() * 0.245), roundi(captura.get_height() * 0.36), roundi(captura.get_width() * 0.33), roundi(captura.get_height() * 0.23))
	captura.get_region(recorte).save_png(PREVIA + "comparacao_detalhe.png")
	# Os dois corpos usam precisamente o mesmo índice e deslocamento de cada passada.
	antigo.texture = ImageTexture.create_from_image(Image.load_from_file("res://arte/fontes/personagens/base_vila_npc/corrida-v1-80.png"))
	antigo.hframes = 8
	antigo.vframes = 4
	jogador._direcao_ataque = Vector2.RIGHT
	jogador.velocity = Vector2.RIGHT * 114
	visual._process(0.0)
	for i in 8:
		visual._tempo = i * 0.1 + 0.01
		visual._process(0.0)
		antigo.frame = visual.frame
		await RenderingServer.frame_post_draw
		captura = root.get_texture().get_image()
		captura.save_png(PREVIA + "corrida_no_jogo_%d.png" % i)
		await create_timer(0.1).timeout
	print("ACABAMENTO_NPC_GODOT_OK: Tomas/Caio/antes/agora, mesma escala e pivô; corrida atual no controlador real; save isolado.")
	quit()
