extends RefCounted

## Registro de poses inteiras por medida rígida; não deforma nem gira membros.
static func largura_cabeca(imagem: Image) -> int:
	var limites := imagem.get_used_rect()
	var linha := limites.position.y + roundi(limites.size.y * 0.1)
	var esquerda := imagem.get_width()
	var direita := 0
	for x in range(limites.position.x, limites.end.x):
		if imagem.get_pixel(x, linha).a > 0:
			esquerda = mini(esquerda, x)
			direita = maxi(direita, x)
	return maxi(1, direita - esquerda + 1)

static func limpar(imagem: Image) -> void:
	imagem.convert(Image.FORMAT_RGBA8)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			imagem.set_pixel(x, y, Color.TRANSPARENT if cor.a < 0.5 else Color(cor.r, cor.g, cor.b, 1.0))
	# Descarta apenas resíduos de outra célula, mantendo o maior corpo conectado.
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var dados := imagem.get_data()
	var visitados := PackedByteArray()
	visitados.resize(largura * altura)
	var maior := PackedInt32Array()
	for inicio in largura * altura:
		if visitados[inicio] or dados[inicio * 4 + 3] == 0:
			continue
		var fila := PackedInt32Array([inicio])
		visitados[inicio] = 1
		var leitura := 0
		while leitura < fila.size():
			var atual := fila[leitura]
			leitura += 1
			var x := atual % largura
			var y := atual / largura
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
						continue
					var vizinho := ny * largura + nx
					if not visitados[vizinho] and dados[vizinho * 4 + 3] > 0:
						visitados[vizinho] = 1
						fila.append(vizinho)
		if fila.size() > maior.size():
			maior = fila
	visitados.fill(0)
	for indice in maior:
		visitados[indice] = 1
	for i in largura * altura:
		if not visitados[i] and dados[i * 4 + 3] > 0:
			imagem.set_pixel(i % largura, i / largura, Color.TRANSPARENT)

static func registrar(origem: Image, escala: float, cabeca_x: float, chao: float) -> Image:
	var limites := origem.get_used_rect()
	var linha := limites.position.y + roundi(limites.size.y * 0.1)
	var soma := 0.0
	var quantidade := 0
	for x in range(limites.position.x, limites.end.x):
		if origem.get_pixel(x, linha).a > 0:
			soma += x
			quantidade += 1
	var centro := soma / maxi(quantidade, 1)
	var posicao := Vector2i(roundi(cabeca_x * 16 - centro * escala), roundi(chao * 16 - limites.end.y * escala))
	var recorte := origem.duplicate() as Image
	recorte.resize(roundi(recorte.get_width() * escala), roundi(recorte.get_height() * escala), Image.INTERPOLATE_NEAREST)
	var tela := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	tela.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), posicao)
	return tela
