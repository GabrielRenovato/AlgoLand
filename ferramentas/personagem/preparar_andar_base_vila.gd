extends SceneTree
## Normaliza o estudo e exporta quadros para revisão do ciclo em GIF.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var pasta := raiz.path_join("arte/fontes/personagens/base_vila_estudo")
	var destino := raiz.path_join("arte/previas/personagens/base_vila_estudo")
	DirAccess.make_dir_recursive_absolute(destino)
	var origem := Image.load_from_file(pasta.path_join("andar-v1-original.png"))
	origem.convert(Image.FORMAT_RGBA8)
	for y in origem.get_height():
		for x in origem.get_width():
			var cor := origem.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= 0.5 else 0.0
			origem.set_pixel(x, y, cor)
	var bandas := [Vector2i(51, 266), Vector2i(301, 516), Vector2i(553, 768), Vector2i(789, 1000)]
	var folha := Image.create(384, 256, false, Image.FORMAT_RGBA8)
	var escala := 31.0 / 215.0
	for linha in 4:
		for coluna in 6:
			var quadro := origem.get_region(Rect2i(coluna * 256, bandas[linha].x, 256, bandas[linha].y - bandas[linha].x))
			var area := quadro.get_used_rect()
			assert(area.has_area())
			var recorte := quadro.get_region(area)
			recorte.resize(maxi(1, roundi(area.size.x * escala)), maxi(1, roundi(area.size.y * escala)), Image.INTERPOLATE_NEAREST)
			# Mesmo centro de célula, escala e chão; não recentralizar cada pose.
			var posicao := Vector2i(roundi(32 + (area.position.x - 128) * escala), roundi(44 - (215 - area.position.y) * escala))
			folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(coluna * 64, linha * 64) + posicao)
	folha.save_png(pasta.path_join("andar-v1-64.png"))
	for coluna in 6:
		var previa := Image.create(256, 64, false, Image.FORMAT_RGBA8)
		for linha in 4:
			previa.blit_rect(folha, Rect2i(coluna * 64, linha * 64, 64, 64), Vector2i(linha * 64, 0))
		previa.resize(768, 192, Image.INTERPOLATE_NEAREST)
		previa.save_png(destino.path_join("andar_quadro_%d.png" % coluna))
	print("24 poses normalizadas e seis quadros de prévia; ordem: baixo, direita, cima, esquerda.")
	quit()
