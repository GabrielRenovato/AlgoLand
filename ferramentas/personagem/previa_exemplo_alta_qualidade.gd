extends SceneTree

const RAIZ := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const SAIDA := "res://arte/previas/personagens/exemplo_alta_qualidade/"
const QUADROS_TEMPORARIOS := "/tmp/algoland-personagem-movimento/"
## Divide a duração do antigo quadro 6 para encaixar a transição sem desacelerar o ciclo.
const DURACOES_CORRIDA := [80, 80, 80, 80, 80, 80, 40, 40, 80]

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Prévia exige projeto com save isolado.")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(160, 90)
	DirAccess.make_dir_recursive_absolute(QUADROS_TEMPORARIOS)
	for arquivo in DirAccess.get_files_at(QUADROS_TEMPORARIOS):
		if arquivo.begins_with("comparacao_") and arquivo.ends_with(".png"):
			DirAccess.remove_absolute(QUADROS_TEMPORARIOS + arquivo)
	var cena := Node2D.new()
	root.add_child(cena)
	var fundo := ColorRect.new()
	fundo.size = Vector2(160, 90)
	fundo.color = Color("26343b")
	cena.add_child(fundo)
	var sprites: Array[Sprite2D] = []
	for i in 2:
		var titulo := Label.new()
		titulo.position = Vector2(i * 80, 9)
		titulo.size = Vector2(80, 16)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", 10)
		titulo.text = "ANDANDO" if i == 0 else "CORRENDO"
		cena.add_child(titulo)
		var linha := Line2D.new()
		linha.points = PackedVector2Array([Vector2(i * 80 + 9, 75), Vector2(i * 80 + 71, 75)])
		linha.width = 0.3
		linha.default_color = Color("6f898a")
		cena.add_child(linha)
		var sprite := Sprite2D.new()
		sprite.texture = load(RAIZ + ("andar.png" if i == 0 else "correr.png"))
		sprite.hframes = 2
		sprite.vframes = 3 if i == 0 else 5
		sprite.centered = false
		sprite.offset = Vector2(-512, -704)
		sprite.scale = Vector2.ONE * 1.4 / 16.0
		sprite.position = Vector2(40 + i * 80, 75)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cena.add_child(sprite)
		sprites.append(sprite)
	for quadro in 9:
		for i in sprites.size():
			sprites[i].frame = quadro % (6 if i == 0 else 9)
		await process_frame
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		if quadro < 6:
			imagem.get_region(Rect2i(0, 0, 480, 540)).save_png(SAIDA + "andar_%d.png" % quadro)
		imagem.get_region(Rect2i(480, 0, 480, 540)).save_png(SAIDA + "correr_%d.png" % quadro)
		if quadro == 0:
			imagem.save_png(SAIDA + "comparacao.png")
	# 1,92 s: dois ciclos de andar e três de correr, incluindo a emenda final/inicial.
	for quadro in 96:
		var tempo := quadro * 0.02
		sprites[0].frame = floori((tempo + 0.00001) / 0.16) % 6
		sprites[1].frame = _quadro_corrida(roundi(tempo * 1000.0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(QUADROS_TEMPORARIOS + "comparacao_%03d.png" % quadro)
	print("EXEMPLO RENDERIZADO: seis poses de andar e nove de correr, comparação em 96 quadros.")
	cena.queue_free()
	await process_frame
	quit()

func _quadro_corrida(tempo_ms: int) -> int:
	var instante := posmod(tempo_ms, 640)
	for i in DURACOES_CORRIDA.size():
		if instante < DURACOES_CORRIDA[i]:
			return i
		instante -= DURACOES_CORRIDA[i]
	return 0
