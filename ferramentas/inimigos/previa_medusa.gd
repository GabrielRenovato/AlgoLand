extends SceneTree

const PAGINAS := ["movimento", "garras", "cauda", "bote", "olhar"]
const NOMES := ["Deslizamento", "Garras", "Varrida de cauda", "Bote", "Olhar petrificante"]
const AVISOS := [0.0, 0.45, 0.7, 0.8, 1.2]
const DURACOES := [0.0, 0.4, 0.5, 0.65, 0.45]
const SAIDA := "res://arte/previas/inimigos/medusa/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1020)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new()
	fundo.size = vp.size
	fundo.color = Color("242a2d")
	vp.add_child(fundo)
	var corpos: Array[Sprite2D] = []
	for i in PAGINAS.size():
		var titulo := Label.new()
		titulo.text = NOMES[i]
		titulo.position = Vector2(16, i * 172 + 6)
		titulo.add_theme_font_size_override("font_size", 16)
		vp.add_child(titulo)
		for direcao in 4:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/inimigos/medusa/" + PAGINAS[i] + ".png")
			sprite.hframes = 6
			sprite.vframes = 4
			sprite.scale = Vector2.ONE
			sprite.position = Vector2(100 + direcao * 172, i * 172 + 90)
			vp.add_child(sprite)
			corpos.append(sprite)
	var efeitos: Array[Sprite2D] = []
	for i in 5:
		var nome: String = ["garras", "cauda", "bote", "olhar", "petrificacao"][i]
		var titulo := Label.new()
		titulo.text = nome.to_upper()
		titulo.position = Vector2(12 + i * 142, 870)
		titulo.add_theme_font_size_override("font_size", 13)
		vp.add_child(titulo)
		var efeito := Sprite2D.new()
		efeito.texture = load("res://assets/efeitos/medusa/" + nome + ".png")
		efeito.hframes = 6
		efeito.position = Vector2(70 + i * 142, 955)
		vp.add_child(efeito)
		efeitos.append(efeito)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for quadro in 60:
		var tempo := quadro * 0.05
		for i in 5:
			var indice := int(tempo / 0.12) % 6
			if i > 0:
				var ciclo := fposmod(tempo, float(AVISOS[i]) + float(DURACOES[i]) + 0.5)
				indice = mini(2, int(ciclo / float(AVISOS[i]) * 3)) if ciclo < float(AVISOS[i]) else (mini(4, 3 + int((ciclo - float(AVISOS[i])) / float(DURACOES[i]) * 2)) if ciclo < float(AVISOS[i]) + float(DURACOES[i]) else 5)
			for direcao in 4:
				corpos[i * 4 + direcao].frame = direcao * 6 + indice
		for efeito in efeitos:
			efeito.frame = int(tempo * 10) % 6
		await process_frame
		await RenderingServer.frame_post_draw
		var imagem := vp.get_texture().get_image()
		imagem.save_png(SAIDA + "quadro_%03d.png" % quadro)
		if quadro == 20:
			imagem.save_png(SAIDA + "animacoes.png")
	vp.queue_free()
	await process_frame
	quit()
