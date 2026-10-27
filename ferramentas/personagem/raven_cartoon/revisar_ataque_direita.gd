extends SceneTree
const SAIDA = "res://arte/previas/personagens/raven_cartoon/ataque_direita/motor/"

func _initialize():
	rodar.call_deferred()

func rotulo(texto: String, x: float, largura: float):
	var label = Label.new()
	label.position = Vector2(x, 24)
	label.size = Vector2(largura, 36)
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("454440"))
	root.add_child(label)

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var direcao = "baixo" if "--baixo" in OS.get_cmdline_user_args() else "direita"
	if "--cima" in OS.get_cmdline_user_args():
		direcao = "cima"
	var nome = "ataque_" + direcao
	var saida = SAIDA.replace("ataque_direita", nome)
	var comparar_mana = "--comparar-mana" in OS.get_cmdline_user_args()
	if comparar_mana:
		saida += "comparacao/"
	root.size = Vector2i(1120, 720)
	var fundo = ColorRect.new()
	fundo.size = Vector2(1120, 720)
	fundo.color = Color("ece7d8")
	root.add_child(fundo)
	rotulo("MANA SEED" if comparar_mana else "MODELO", 24, 360)
	rotulo("ATAQUE " + direcao.to_upper() + " · SEM ARMA", 440, 656)
	var modelo = Sprite2D.new()
	var vista = {"baixo": "frente", "cima": "costas", "direita": "perfil"}[direcao]
	modelo.texture = load("res://assets/personagens/raven_cartoon/referencia_" + vista + "_ataque.png")
	modelo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modelo.position = Vector2(210, 650)
	modelo.offset = Vector2(-200, -790)
	modelo.centered = false
	modelo.scale = Vector2(0.7, 0.7)
	root.add_child(modelo)
	var referencia_animada: AnimatedSprite2D
	if comparar_mana:
		assert(direcao in ["cima", "baixo", "direita"])
		modelo.visible = false
		referencia_animada = AnimatedSprite2D.new()
		var quadros_mana = SpriteFrames.new()
		quadros_mana.add_animation(nome)
		quadros_mana.set_animation_speed(nome, 10.0)
		quadros_mana.set_animation_loop(nome, false)
		var textura_mana = load("res://arte/fontes/personagens/raven_cartoon/" + nome + "/referencia_mana_seed_corpo_nativo.png")
		for q in 4:
			var recorte = AtlasTexture.new()
			recorte.atlas = textura_mana
			recorte.region = Rect2(q*64, 0, 64, 64)
			quadros_mana.add_frame(nome, recorte, [1.6, 0.6, 0.7, 2.0][q])
		referencia_animada.sprite_frames = quadros_mana
		referencia_animada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		referencia_animada.position = Vector2(210, 650)
		referencia_animada.offset = Vector2(-32, -44)
		referencia_animada.centered = false
		referencia_animada.scale = Vector2(14.0, 14.0)
		root.add_child(referencia_animada)
	var ator = AnimatedSprite2D.new()
	ator.sprite_frames = load("res://assets/personagens/raven_cartoon/" + nome + "_sem_arma.tres")
	ator.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ator.position = Vector2(715, 650)
	ator.offset = Vector2(-280 if direcao == "direita" else -320, -850)
	ator.centered = false
	ator.scale = Vector2(0.7, 0.7)
	root.add_child(ator)
	assert(ator.sprite_frames.get_frame_count(nome) == 4)
	assert(not ator.sprite_frames.get_animation_loop(nome))
	var terminados = [0]
	ator.animation_finished.connect(func(): terminados[0] += 1)
	ator.play(nome)
	if comparar_mana:
		referencia_animada.play(nome)
	var vistos = {}
	var tempos = []
	var anterior = -1
	var inicio = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	while terminados[0] < 2 and Time.get_ticks_msec()-inicio < 5000:
		await RenderingServer.frame_post_draw
		var q = ator.frame
		if q != anterior:
			tempos.append([q, Time.get_ticks_msec()-inicio])
			anterior = q
		if not vistos.has(q):
			vistos[q] = true
			root.get_texture().get_image().save_png(saida+"quadro_%02d.png" % (q+1))
		if not ator.is_playing() and terminados[0] < 2:
			ator.play(nome)
			if comparar_mana:
				referencia_animada.play(nome)
		await process_frame
	assert(vistos.size() == 4 and terminados[0] == 2)
	FileAccess.open(saida+"reproducao.json", FileAccess.WRITE).store_string(JSON.stringify({"direcao": direcao, "quadros": 4, "duracoes_ms": [160, 60, 70, 200], "reproducoes": 2, "comparacao": "Mana Seed" if comparar_mana else "modelo canônico", "trocas": tempos}, "\t"))
	var comparacao = "Mana Seed" if comparar_mana else "modelo canônico"
	print("ATAQUE CARTOON " + direcao + ": quatro tempos sem arma,490ms,duas reproduções e " + comparacao + " lado a lado em save isolado.")
	quit()
