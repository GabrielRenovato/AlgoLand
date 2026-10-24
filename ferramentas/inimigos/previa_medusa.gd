extends SceneTree
var _medusa: GDScript
var _poses := preload("res://codigo/inimigos/poses_medusa.gd").new()

const PAGINAS := ["movimento", "garras", "cauda", "bote", "olhar"]
const NOMES := ["Deslizamento", "Garras", "Varrida de cauda", "Bote", "Olhar petrificante"]
const AVISOS := [0.0, 0.45, 0.7, 0.8, 1.2]
const DURACOES := [0.0, 0.4, 0.5, 0.65, 0.45]
const SAIDA := "res://arte/previas/inimigos/medusa/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	_medusa = load("res://codigo/inimigos/medusa.gd")
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
	var animadores: Array = []
	for i in PAGINAS.size():
		var titulo := Label.new()
		titulo.text = NOMES[i]
		titulo.position = Vector2(16, i * 172 + 6)
		titulo.add_theme_font_size_override("font_size", 16)
		vp.add_child(titulo)
		for direcao in 4:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/inimigos/medusa/" + PAGINAS[i] + ".png")
			sprite.hframes = sprite.texture.get_width() / 160
			sprite.vframes = 4
			sprite.scale = Vector2.ONE
			sprite.position = Vector2(100 + direcao * 172, i * 172 + 100)
			vp.add_child(sprite)
			corpos.append(sprite)
			animadores.append(load("res://codigo/inimigos/animacao_fluida_medusa.gd").new())
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
			# Movimento nominal: 78px/s, uma pose a cada 7px percorridos.
			var indice := fposmod(tempo / (7.0 / 78.0), 6.0)
			if i > 0:
				var recuperacao: float = _medusa.RECUPERACOES[PAGINAS[i]]
				var ciclo := fposmod(tempo, float(AVISOS[i]) + float(DURACOES[i]) + recuperacao)
				indice = _medusa.quadro_preparo(ciclo / float(AVISOS[i])) if ciclo < float(AVISOS[i]) else (_medusa.quadro_golpe((ciclo - float(AVISOS[i])) / float(DURACOES[i])) if ciclo < float(AVISOS[i]) + float(DURACOES[i]) else _medusa.quadro_recuperacao((ciclo - float(AVISOS[i]) - float(DURACOES[i])) / recuperacao))
			if _poses.possui(PAGINAS[i]):
				var recuperacao: float = _medusa.RECUPERACOES[PAGINAS[i]]
				var ciclo := fposmod(tempo, float(AVISOS[i]) + float(DURACOES[i]) + recuperacao)
				indice = _poses.preparo(ciclo / float(AVISOS[i])) if ciclo < float(AVISOS[i]) else (_poses.golpe((ciclo - float(AVISOS[i])) / float(DURACOES[i])) if ciclo < float(AVISOS[i]) + float(DURACOES[i]) else _poses.recuperacao((ciclo - float(AVISOS[i]) - float(DURACOES[i])) / recuperacao))
			indice = fposmod(indice, 6.0)
			for direcao in 4:
				if _poses.possui(PAGINAS[i]):
					_poses.aplicar(corpos[i * 4 + direcao], PAGINAS[i], direcao, indice)
					continue
				var colunas := corpos[i * 4 + direcao].texture.get_width() / 160
				corpos[i * 4 + direcao].frame = direcao * colunas + mini(colunas - 1, int(indice * colunas / 6.0))
				animadores[i * 4 + direcao].aplicar(corpos[i * 4 + direcao], PAGINAS[i], fposmod(indice, 1.0))
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
