extends RefCounted

## Recorta personagens completos antes da grade; uma lâmina pode passar da
## margem nominal da célula na fonte, mas nunca é cortada na folha compilada.
static func extrair(fonte: Image, colunas: int, linhas: int, area_minima := 300) -> Dictionary:
	fonte.convert(Image.FORMAT_RGBA8)
	var largura := fonte.get_width()
	var altura := fonte.get_height()
	var dados := fonte.get_data()
	var visitados := PackedByteArray()
	visitados.resize(largura * altura)
	var resultado := {}
	for inicio in largura * altura:
		if visitados[inicio] or dados[inicio * 4 + 3] < 128:
			continue
		var fila := PackedInt32Array([inicio])
		visitados[inicio] = 1
		var indice := 0
		var minimo := Vector2i(largura, altura)
		var maximo := Vector2i.ZERO
		while indice < fila.size():
			var atual := fila[indice]
			indice += 1
			var x := atual % largura
			var y: int = atual / largura
			minimo = Vector2i(mini(minimo.x, x), mini(minimo.y, y))
			maximo = Vector2i(maxi(maximo.x, x), maxi(maximo.y, y))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
						continue
					var vizinho := ny * largura + nx
					if visitados[vizinho] or dados[vizinho * 4 + 3] < 128:
						continue
					visitados[vizinho] = 1
					fila.append(vizinho)
		if fila.size() < area_minima:
			continue
		var centro := (Vector2(minimo) + Vector2(maximo)) * 0.5
		var coluna := clampi(int(centro.x * colunas / largura), 0, colunas - 1)
		var linha := clampi(int(centro.y * linhas / altura), 0, linhas - 1)
		var chave := linha * colunas + coluna
		if resultado.has(chave) and resultado[chave].area >= fila.size():
			continue
		var imagem := Image.create(maximo.x - minimo.x + 1, maximo.y - minimo.y + 1, false, Image.FORMAT_RGBA8)
		for pixel in fila:
			var ponto := Vector2i(pixel % largura, pixel / largura)
			var cor := fonte.get_pixelv(ponto)
			cor.a = 1.0
			imagem.set_pixelv(ponto - minimo, cor)
		resultado[chave] = {"imagem":imagem, "area":fila.size(), "origem":minimo}
	return resultado
