extends SceneTree
## Comparação renderizada das fontes reais, sem redesenhar os quadros aprovados.
const SAIDA = "res://arte/previas/personagens/raven_cartoon/ataques_quatro_direcoes_com_espada/motor/comparacao/"
const TEMPOS = [1.6, 0.6, 0.7, 2.0]

func _initialize():
	rodar.call_deferred()

func rotulo(texto: String, posicao: Vector2, largura: float, tamanho: int):
	var label = Label.new()
	label.position = posicao
	label.size = Vector2(largura, 36)
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", Color("454440"))
	root.add_child(label)

func quadros_mana(textura: Texture2D, linha: int, coluna: int = 0) -> SpriteFrames:
	var quadros = SpriteFrames.new()
	quadros.set_animation_speed("default", 10.0)
	quadros.set_animation_loop("default", false)
	for q in 4:
		var recorte = AtlasTexture.new()
		recorte.atlas = textura
		recorte.region = Rect2((q+coluna)*64, linha*64, 64, 64)
		quadros.add_frame("default", recorte, TEMPOS[q])
	return quadros

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var golpe2 = "--golpe2" in OS.get_cmdline_user_args()
	var coluna_mana = 4 if golpe2 else 0
	var prefixo = "ataque2_" if golpe2 else "ataque_"
	var saida = "res://arte/previas/personagens/raven_cartoon/combo_golpe2/motor/comparacao/" if golpe2 else SAIDA
	root.content_scale_size = Vector2i(1920, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1050, 700)
	var fundo = ColorRect.new()
	fundo.size = Vector2(1920, 1280)
	fundo.color = Color("ece7d8")
	root.add_child(fundo)
	var corpo_mana = load("res://assets/personagens/raven_cartoon/comparacao_mana_corpo.png")
	var espada_mana = load("res://assets/personagens/raven_cartoon/comparacao_mana_espada.png")
	var atores = []
	var armas = []
	for i in 4:
		var direcao = ["baixo", "direita", "cima", "esquerda"][i]
		var linha_mana = {"baixo": 0, "cima": 1, "direita": 2, "esquerda": 3}[direcao]
		var fonte = "direita" if direcao == "esquerda" else direcao
		var origem = Vector2((i % 2)*960, (i / 2)*640)
		rotulo(direcao.to_upper()+(" · GOLPE 2" if golpe2 else ""), origem+Vector2(24, 20), 912, 27)
		rotulo("MANA SEED", origem+Vector2(32, 65), 440, 22)
		rotulo("RAVEN", origem+Vector2(500, 65), 420, 22)
		var mana = AnimatedSprite2D.new()
		mana.sprite_frames = quadros_mana(corpo_mana, linha_mana, coluna_mana)
		mana.centered = false
		mana.offset = Vector2(-32, -44)
		mana.position = origem+Vector2(270, 470)
		mana.scale = Vector2.ONE*8
		mana.z_index = 10
		mana.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(mana)
		var arma = Sprite2D.new()
		arma.centered = false
		arma.offset = mana.offset
		mana.add_child(arma)
		var quadros_arma = quadros_mana(espada_mana, linha_mana, coluna_mana)
		armas.append([mana, arma, quadros_arma, linha_mana])
		atores.append(mana)
		var raven = AnimatedSprite2D.new()
		raven.sprite_frames = load("res://assets/personagens/raven_cartoon/"+prefixo+fonte+"_sem_arma.tres")
		raven.animation = prefixo+fonte
		raven.centered = false
		raven.offset = Vector2(-280 if fonte == "direita" else -320, -850)
		raven.position = origem+Vector2(730, 470)
		raven.scale = Vector2(-0.4 if direcao == "esquerda" else 0.4, 0.4)
		raven.z_index = 10
		raven.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(raven)
		var equipamento = load("res://ferramentas/personagem/raven_cartoon/camada_espada.gd").new()
		raven.add_child(equipamento)
		equipamento.configurar(raven, fonte, 2 if golpe2 else 1)
		atores.append(raven)
	rotulo("4 fases sincronizadas · 160 / 60 / 70 / 200 ms · rastro branco nas duas versões", Vector2(24, 1230), 1872, 20)
	# A arma do Mana Seed usa os pixels originais e a ordem documentada pelo autor.
	var atualizar_armas = func():
		for entrada in armas:
			var q = entrada[0].frame
			entrada[1].texture = entrada[2].get_frame_texture("default", q)
			entrada[1].z_index = 1 if not golpe2 and entrada[3] >= 2 and q == 1 else -1
	for entrada in armas:
		entrada[0].frame_changed.connect(atualizar_armas)
	atualizar_armas.call()
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
	FileAccess.open(saida+"reproducao.json", FileAccess.WRITE).store_string(JSON.stringify({"fontes_mana": "ONE3, corpo e espada originais, linhas 0/2/1/3", "coluna_inicial": coluna_mana, "golpe": 2 if golpe2 else 1, "camada_espada": "atrás em todos os quadros" if golpe2 else "atrás; à frente somente na fase 2 dos perfis", "rastro_raven": "à frente da espada", "tempos_ms": [160, 60, 70, 200], "reproducoes": 2, "atores_sincronizados": 8}, "\t"))
	print("COMPARAÇÃO: oito atores sincronizados, quatro direções com espada, duas reproduções em save isolado.")
	quit()
