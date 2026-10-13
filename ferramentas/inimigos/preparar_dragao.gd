extends SceneTree

const PAGINAS := ["movimento", "sopro", "cauda", "asas", "voo", "patada"]
const CELULA := 128
const PALETA := ["20121e", "361823", "54202a", "79252a", "a3332a", "ce4932", "e36c3d", "f39252", "422537", "643247", "874458", "ac6264", "593821", "81522b", "ae793c", "d7a858", "f1ce7b", "ffeba6", "f9f3cf", "eab448", "788238", "b6ba49"]

func _initialize() -> void:
	var fontes := {}
	var maior_lado := 1
	for pagina in PAGINAS:
		var versao := "_v3.png" if pagina == "cauda" else "_v2.png"
		if pagina in ["voo", "patada"]:
			versao = "_v1.png"
		var imagem := Image.load_from_file("res://inimigos/dragao_vermelho/fontes/" + pagina + versao)
		if imagem == null or imagem.is_empty():
			push_error("Fonte de animação ausente: " + pagina)
			quit(1)
			return
		fontes[pagina] = imagem
		maior_lado = maxi(maior_lado, maxi(roundi(imagem.get_width() / 6.0), roundi(imagem.get_height() / 4.0)))
	var fator := 120.0 / maior_lado
	for pagina in PAGINAS:
		var imagem: Image = fontes[pagina]
		var folha := Image.create(6 * CELULA, 4 * CELULA, false, Image.FORMAT_RGBA8)
		for linha in 4:
			for coluna in 6:
				var inicio := Vector2i(roundi(coluna * imagem.get_width() / 6.0), roundi(linha * imagem.get_height() / 4.0))
				var fim := Vector2i(roundi((coluna + 1) * imagem.get_width() / 6.0), roundi((linha + 1) * imagem.get_height() / 4.0))
				var quadro := imagem.get_region(Rect2i(inicio, fim - inicio))
				quadro.resize(maxi(1, roundi(quadro.get_width() * fator)), maxi(1, roundi(quadro.get_height() * fator)), Image.INTERPOLATE_NEAREST)
				for y in quadro.get_height():
					for x in quadro.get_width():
						var pixel := quadro.get_pixel(x, y)
						if pixel.a < 0.5:
							quadro.set_pixel(x, y, Color.TRANSPARENT)
							continue
						var melhor := Color.BLACK
						var menor := INF
						for html in PALETA:
							var cor := Color.html(html)
							var distancia := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
							if distancia < menor:
								melhor = cor
								menor = distancia
						quadro.set_pixel(x, y, melhor)
				# O desenho ampliado pode atravessar a borda da célula vizinha.
				# Extrair somente a silhueta principal evita importar pontas de outras poses.
				quadro = extrair_silhueta(quadro)
				var posicao := Vector2i((CELULA - quadro.get_width()) / 2, CELULA - quadro.get_height() - 4)
				folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i(coluna * CELULA, linha * CELULA) + posicao)
		folha.save_png("res://inimigos/dragao_vermelho/" + pagina + ".png")
		print("Dragão: ", pagina, " ", folha.get_size())
	quit()

static func extrair_silhueta(quadro: Image) -> Image:
	var largura := quadro.get_width()
	var altura := quadro.get_height()
	var visitados := PackedByteArray()
	visitados.resize(largura * altura)
	var principal := PackedInt32Array()
	for y in altura:
		for x in largura:
			var indice := y * largura + x
			if visitados[indice] or quadro.get_pixel(x, y).a == 0:
				continue
			var grupo := PackedInt32Array([indice])
			visitados[indice] = 1
			var cursor := 0
			while cursor < grupo.size():
				var atual := grupo[cursor]
				cursor += 1
				var origem := Vector2i(atual % largura, atual / largura)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var ponto := origem + Vector2i(dx, dy)
						if ponto.x < 0 or ponto.y < 0 or ponto.x >= largura or ponto.y >= altura:
							continue
						var vizinho := ponto.y * largura + ponto.x
						if not visitados[vizinho] and quadro.get_pixelv(ponto).a > 0:
							visitados[vizinho] = 1
							grupo.append(vizinho)
			if grupo.size() > principal.size():
				principal = grupo
	var resultado := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	for indice in principal:
		var ponto := Vector2i(indice % largura, indice / largura)
		resultado.set_pixelv(ponto, quadro.get_pixelv(ponto))
	return resultado
