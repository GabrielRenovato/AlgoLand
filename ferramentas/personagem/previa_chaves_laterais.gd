extends SceneTree
## Exporta os quatro quadros do estudo sem corrigir ou ocultar seus defeitos.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var imagem := Image.load_from_file(raiz.path_join("arte/fontes/personagens/base_vila_estudo/andar-direita-chave-v3.png"))
	imagem.convert(Image.FORMAT_RGBA8)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= 0.5 else 0.0
			imagem.set_pixel(x, y, cor)
	var pasta := raiz.path_join("arte/previas/personagens/base_vila_estudo/chaves_laterais")
	DirAccess.make_dir_recursive_absolute(pasta)
	var altura := imagem.get_used_rect().size.y
	var escala := 93.0 / altura
	var base := imagem.get_used_rect().end.y
	# Guias do quadril medidos na faixa superior dos shorts de cada quadro.
	# A fonte gerada deriva dentro da célula; o centro da célula não é a raiz.
	var quadril_x := [262.0, 271.0, 232.0, 218.0]
	var chao_y := [680.0, 681.0, 681.0, 681.0]
	for i in 4:
		var inicio := i * imagem.get_width() / 4
		var fim := (i + 1) * imagem.get_width() / 4
		var quadro := imagem.get_region(Rect2i(inicio, 0, fim - inicio, imagem.get_height()))
		var area := quadro.get_used_rect()
		var recorte := quadro.get_region(area)
		recorte.resize(maxi(1, roundi(area.size.x * escala)), maxi(1, roundi(area.size.y * escala)), Image.INTERPOLATE_NEAREST)
		var previa := Image.create(192, 192, false, Image.FORMAT_RGBA8)
		previa.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(roundi(96 + (area.position.x - quadril_x[i]) * escala), roundi(140 + (area.position.y - chao_y[i]) * escala)))
		previa.save_png(pasta.path_join("quadro_%d.png" % i))
	print("Quatro quadros exportados com quadril x96 e chão y140; translação da fonte corrigida.")
	quit()
