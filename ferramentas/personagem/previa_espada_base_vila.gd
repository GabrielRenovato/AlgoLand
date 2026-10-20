extends SceneTree
## Prévia do estudo com durações originais do ataque lateral CraftPix.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var fonte := Image.load_from_file(raiz.path_join("arte/fontes/personagens/base_vila_estudo/espada-direita-v1-original.png"))
	fonte.convert(Image.FORMAT_RGBA8)
	for y in fonte.get_height():
		for x in fonte.get_width():
			var cor := fonte.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= 0.5 else 0.0
			fonte.set_pixel(x, y, cor)
	var pasta := raiz.path_join("arte/previas/personagens/base_vila_estudo/espada_direita")
	DirAccess.make_dir_recursive_absolute(pasta)
	# Referência corporal do primeiro quadro: 189px -> 93px na prévia3x.
	var escala := 93.0 / 189.0
	for i in 8:
		var inicio := fonte.get_width() * i / 8
		var fim := fonte.get_width() * (i + 1) / 8
		var quadro := fonte.get_region(Rect2i(inicio, 0, fim - inicio, fonte.get_height()))
		var minimo := quadro.get_width()
		var maximo := -1
		# Guia da sola: usa somente pixels quentes da bota, nunca aço/rastro.
		for y in range(478, 499):
			for x in quadro.get_width():
				var c := quadro.get_pixel(x, y)
				if c.a >= 0.5 and c.r > c.g * 1.15 and c.b < c.r * 0.85:
					minimo = mini(minimo, x)
					maximo = maxi(maximo, x)
		assert(maximo >= minimo)
		var pivo := (minimo + maximo) / 2.0
		var area := quadro.get_used_rect()
		var recorte := quadro.get_region(area)
		recorte.resize(maxi(1, roundi(area.size.x * escala)), maxi(1, roundi(area.size.y * escala)), Image.INTERPOLATE_NEAREST)
		var previa := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		previa.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(roundi(128 + (area.position.x - pivo) * escala), roundi(190 + (area.position.y - 498) * escala)))
		previa.save_png(pasta.path_join("quadro_%d.png" % i))
	print("Oito quadros, escala única e chão y190; tempos CraftPix 500ms + 7x100ms.")
	quit()
