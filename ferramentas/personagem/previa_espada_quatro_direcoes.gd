extends SceneTree
## Normaliza cada fonte pela pose de guarda e ancora pela sola, sem cortar arma.
const FONTES := ["espada-frente-v1-original.png", "espada-direita-v1-original.png", "espada-costas-v5-original.png", "espada-esquerda-v2-original.png"]
const NOMES := ["frente", "direita", "costas", "esquerda"]

func quente(c: Color) -> bool:
	return c.a >= 0.5 and c.r > 0.03 and c.r > c.g * 1.15 and c.b < c.r * 0.85

func limpar_vizinhos(imagem: Image) -> Image:
	# A geração deixa fragmentos de efeitos do quadro vizinho nos limites.
	# Conserva a silhueta conectada do ator/arma e remove somente peças soltas.
	var largura := imagem.get_width()
	var vistos := PackedByteArray()
	vistos.resize(largura * imagem.get_height())
	var maior: Array[Vector2i] = []
	for y in imagem.get_height():
		for x in largura:
			var indice := y * largura + x
			if vistos[indice] != 0 or imagem.get_pixel(x, y).a < 0.5:
				continue
			var componente: Array[Vector2i] = [Vector2i(x, y)]
			vistos[indice] = 1
			var cursor := 0
			while cursor < componente.size():
				var ponto := componente[cursor]
				cursor += 1
				for deslocamento in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var vizinho: Vector2i = ponto + deslocamento
					if vizinho.x < 0 or vizinho.x >= largura or vizinho.y < 0 or vizinho.y >= imagem.get_height():
						continue
					var outro := vizinho.y * largura + vizinho.x
					if vistos[outro] == 0 and imagem.get_pixelv(vizinho).a >= 0.5:
						vistos[outro] = 1
						componente.append(vizinho)
			if componente.size() > maior.size():
				maior = componente
	var limpa := Image.create(largura, imagem.get_height(), false, Image.FORMAT_RGBA8)
	for ponto in maior:
		limpa.set_pixelv(ponto, imagem.get_pixelv(ponto))
	return limpa

func sola(quadro: Image) -> Vector2:
	var fundo := 0
	for y in range(quadro.get_height() / 2, quadro.get_height()):
		var pontos := 0
		for x in quadro.get_width():
			if quente(quadro.get_pixel(x, y)):
				pontos += 1
		if pontos >= 6:
			fundo = y
	var minimo := quadro.get_width()
	var maximo := -1
	for y in range(maxi(0, fundo - 16), fundo + 1):
		for x in quadro.get_width():
			if quente(quadro.get_pixel(x, y)):
				minimo = mini(minimo, x)
				maximo = maxi(maximo, x)
	assert(maximo >= minimo)
	return Vector2((minimo + maximo) / 2.0, fundo + 1)

func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var saida := raiz.path_join("arte/previas/personagens/base_vila_estudo/espada_quatro_direcoes")
	DirAccess.make_dir_recursive_absolute(saida)
	var fontes: Array[Image] = []
	var escalas: Array[float] = []
	for arquivo in FONTES:
		var imagem := Image.load_from_file(raiz.path_join("arte/fontes/personagens/base_vila_estudo/" + arquivo))
		imagem.convert(Image.FORMAT_RGBA8)
		for y in imagem.get_height():
			for x in imagem.get_width():
				var cor := imagem.get_pixel(x, y)
				cor.a = 1.0 if cor.a >= 0.5 else 0.0
				imagem.set_pixel(x, y, cor)
		fontes.append(imagem)
		var guarda := imagem.get_region(Rect2i(0, 0, imagem.get_width() / 8, imagem.get_height()))
		escalas.append(93.0 / (sola(guarda).y - guarda.get_used_rect().position.y))
	for coluna in 8:
		var conjunto := Image.create(1024, 256, false, Image.FORMAT_RGBA8)
		for direcao in 4:
			var imagem := fontes[direcao]
			var inicio := imagem.get_width() * coluna / 8
			var fim := imagem.get_width() * (coluna + 1) / 8
			var quadro := imagem.get_region(Rect2i(inicio, 0, fim - inicio, imagem.get_height()))
			# No ataque norte o aço e o rastro passam acima da cabeça e podem
			# estar separados por transparência; não descartá-los como fragmentos.
			if direcao != 2:
				quadro = limpar_vizinhos(quadro)
			var apoio := sola(quadro)
			var area := quadro.get_used_rect()
			var recorte := quadro.get_region(area)
			var escala := escalas[direcao]
			recorte.resize(maxi(1, roundi(area.size.x * escala)), maxi(1, roundi(area.size.y * escala)), Image.INTERPOLATE_NEAREST)
			var previa := Image.create(256, 256, false, Image.FORMAT_RGBA8)
			var destino := Vector2i(roundi(128 + (area.position.x - apoio.x) * escala), roundi(190 + (area.position.y - apoio.y) * escala))
			assert(destino.x >= 0 and destino.y >= 0 and destino.x + recorte.get_width() <= 256 and destino.y + recorte.get_height() <= 256)
			previa.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), destino)
			previa.save_png(saida.path_join("%s_%d.png" % [NOMES[direcao], coluna]))
			conjunto.blit_rect(previa, Rect2i(0, 0, 256, 256), Vector2i(direcao * 256, 0))
		conjunto.save_png(saida.path_join("conjunto_%d.png" % coluna))
	print("32 quadros exportados: frente, direita, costas e esquerda; solas alinhadas e armas sem recorte.")
	quit()
