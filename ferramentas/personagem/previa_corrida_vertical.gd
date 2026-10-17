extends SceneTree

const RAIZ := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const SAIDA := "res://arte/previas/personagens/exemplo_alta_qualidade/corrida_vertical/"
const TEMPORARIOS := "/tmp/algoland-corrida-vertical/"
const DURACOES := preload("res://codigo/jogador/heroi_gerado.gd").DURACOES_CORRIDA
const DURACOES_BAIXO := preload("res://codigo/jogador/heroi_gerado.gd").DURACOES_CORRIDA_BAIXO

func _initialize() -> void:
	_rodar.call_deferred()

func _quadro(tempo_ms: int, baixo := false) -> int:
	var instante := posmod(tempo_ms, 640)
	var duracoes: Array = DURACOES_BAIXO if baixo else DURACOES
	for i in duracoes.size():
		if instante < duracoes[i]:
			return i
		instante -= duracoes[i]
	return 0

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	DirAccess.make_dir_recursive_absolute(TEMPORARIOS)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(160, 90)
	var cena := Node2D.new()
	root.add_child(cena)
	var fundo := ColorRect.new()
	fundo.size = Vector2(160, 90)
	fundo.color = Color("26343b")
	cena.add_child(fundo)
	var sprites: Array[Sprite2D] = []
	for i in 2:
		var rotulo := Label.new()
		rotulo.text = "BAIXO" if i == 0 else "CIMA"
		rotulo.position = Vector2(i * 80, 9)
		rotulo.size = Vector2(80, 16)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.add_theme_font_size_override("font_size", 10)
		cena.add_child(rotulo)
		var linha := Line2D.new()
		linha.points = PackedVector2Array([Vector2(i * 80 + 9, 75), Vector2(i * 80 + 71, 75)])
		linha.width = 0.3
		linha.default_color = Color("6f898a")
		cena.add_child(linha)
		var sprite := Sprite2D.new()
		sprite.texture = load(RAIZ + ("correr_baixo.png" if i == 0 else "correr_cima.png"))
		sprite.hframes = 2
		sprite.vframes = 5
		sprite.centered = false
		sprite.offset = Vector2(-512, -704)
		sprite.position = Vector2(40 + i * 80, 75)
		sprite.scale = Vector2.ONE * 1.4 / 16.0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cena.add_child(sprite)
		sprites.append(sprite)
	for i in 9:
		for sprite in sprites:
			sprite.frame = i
		await process_frame
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		imagem.get_region(Rect2i(0, 0, 480, 540)).save_png(SAIDA + "baixo_%d.png" % i)
		imagem.get_region(Rect2i(480, 0, 480, 540)).save_png(SAIDA + "cima_%d.png" % i)
	for i in 32:
		for indice in sprites.size():
			sprites[indice].frame = _quadro(i * 20, indice == 0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(TEMPORARIOS + "quadro_%02d.png" % i)
	print("CORRIDA VERTICAL: duas direções, nove poses cada, ciclo completo de 640 ms renderizado.")
	cena.queue_free()
	await process_frame
	quit()
