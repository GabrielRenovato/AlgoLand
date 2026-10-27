extends SceneTree
const SAIDA = "res://arte/previas/personagens/raven_cartoon/ataques_quatro_direcoes/motor/"

func _initialize():
	rodar.call_deferred()

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var com_espada = "--com-espada" in OS.get_cmdline_user_args()
	var saida = SAIDA.replace("ataques_quatro_direcoes/", "ataques_quatro_direcoes_com_espada/") if com_espada else SAIDA
	var tamanho_logico = Vector2i(1280, 1280) if com_espada else Vector2i(1280, 600)
	root.content_scale_size = tamanho_logico
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(900, 900) if com_espada else tamanho_logico
	var fundo = ColorRect.new()
	fundo.size = Vector2(tamanho_logico)
	fundo.color = Color("ece7d8")
	root.add_child(fundo)
	var atores = []
	for i in 4:
		var direcao = ["baixo", "direita", "cima", "esquerda"][i]
		var fonte = "direita" if direcao == "esquerda" else direcao
		var coluna = i % 2 if com_espada else i
		var linha = i / 2 if com_espada else 0
		var largura = 640 if com_espada else 320
		var topo = linha * 640
		var titulo = Label.new()
		titulo.position = Vector2(coluna*largura+20, topo+24)
		titulo.size = Vector2(largura-40, 36)
		titulo.text = direcao.to_upper()
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.z_index = 20
		titulo.add_theme_font_size_override("font_size", 22)
		titulo.add_theme_color_override("font_color", Color("454440"))
		root.add_child(titulo)
		var ator = AnimatedSprite2D.new()
		ator.sprite_frames = load("res://assets/personagens/raven_cartoon/ataque_" + fonte + "_sem_arma.tres")
		ator.animation = "ataque_" + fonte
		ator.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# A arma atrás do corpo ainda deve ficar acima do fundo da prévia.
		ator.z_index = 10
		ator.centered = false
		ator.position = Vector2(coluna*largura+largura/2, topo+600 if com_espada else 550)
		ator.offset = Vector2(-280 if fonte == "direita" else -320, -850)
		# Espelhar ao redor da raiz preserva o encaixe e o chão da direita.
		ator.scale = Vector2(-0.6 if direcao == "esquerda" else 0.6, 0.6)
		assert(ator.sprite_frames.get_frame_count(ator.animation) == 4)
		assert(not ator.sprite_frames.get_animation_loop(ator.animation))
		root.add_child(ator)
		if com_espada:
			var equipamento = load("res://ferramentas/personagem/raven_cartoon/camada_espada.gd").new()
			ator.add_child(equipamento)
			equipamento.configurar(ator, fonte)
		atores.append(ator)
	var terminados = [0]
	atores[0].animation_finished.connect(func(): terminados[0] += 1)
	for ator in atores:
		ator.play()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var vistos = {}
	var inicio = Time.get_ticks_msec()
	while terminados[0] < 2 and Time.get_ticks_msec()-inicio < 5000:
		await RenderingServer.frame_post_draw
		var q = atores[0].frame
		for ator in atores:
			assert(ator.frame == q)
		if not vistos.has(q):
			vistos[q] = true
			root.get_texture().get_image().save_png(saida+"quadro_%02d.png" % (q+1))
		if not atores[0].is_playing() and terminados[0] < 2:
			for ator in atores:
				ator.play()
		await process_frame
	assert(vistos.size() == 4 and terminados[0] == 2)
	FileAccess.open(saida+"reproducao.json", FileAccess.WRITE).store_string(JSON.stringify({"direcoes": ["baixo", "direita", "cima", "esquerda"], "esquerda": "direita espelhada ao redor da raiz", "com_espada": com_espada, "tempos_ms": [160, 60, 70, 200], "reproducoes": 2, "sincronizados": true}, "\t"))
	print("ATAQUES: quatro direções sincronizadas, esquerda espelhada da direita,490ms,duas reproduções em save isolado.")
	quit()
