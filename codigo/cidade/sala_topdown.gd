extends Node2D

## Planta da casa montada com recortes nativos de 16 px dos interiores locais PixelLab.
## A casa é uma lista de áreas de chão (cômodos e corredores), cada uma com o próprio tom de piso; o que não é
## chão fica de fora, escuro. As paredes saem do contorno, numa grade de 8 px: onde o chão não tem nada acima
## aparece a face de madeira (32 px) com o topo em corte; nos lados e embaixo, só o topo em corte (8 px). Dois
## cômodos lado a lado dividem uma parede de 8 px; um embaixo do outro precisam de 40 px entre si, o espaço da
## face. Portas são corredores que atravessam esse espaço. As faixas são recortadas, nunca esticadas.
const FOLHA := preload("res://assets/cenario/substitutos/interiores/madeira.png")
const CELULA := 8
## Linhas da folha de cada tom de piso
const PISOS := {"escuro": [2, 2], "medio": [5, 6], "claro": [9, 10]}
var geometria: Dictionary
var casa: String
var _mapa: Dictionary

func configurar(dados: Dictionary, identidade: String) -> void:
	geometria = dados
	casa = identidade
	_mapa = mapa(dados)
	z_index = -999
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

## Grade de 8 px da casa: 1 onde há chão
static func mapa(dados: Dictionary) -> Dictionary:
	var colunas := int(ceil(float(dados["recorte"][2]) / CELULA))
	var linhas := int(ceil(float(dados["recorte"][3]) / CELULA))
	var chao := PackedByteArray()
	chao.resize(colunas * linhas)
	for area in dados["areas"]:
		var r: Array = area["retangulo"]
		for cy in range(int(r[1]) / CELULA, (int(r[1]) + int(r[3])) / CELULA):
			for cx in range(int(r[0]) / CELULA, (int(r[0]) + int(r[2])) / CELULA):
				if cx >= 0 and cy >= 0 and cx < colunas and cy < linhas:
					chao[cy * colunas + cx] = 1
	return {"colunas": colunas, "linhas": linhas, "chao": chao}

static func e_chao(m: Dictionary, cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= m["colunas"] or cy >= m["linhas"]:
		return false
	return m["chao"][cy * m["colunas"] + cx] == 1

## Tudo o que não é chão, em retângulos: faixas de cada linha, juntadas com as iguais da linha de baixo
static func solidos(dados: Dictionary) -> Array[Rect2]:
	var m := mapa(dados)
	var abertos := {}
	var saida: Array[Rect2] = []
	for cy in m["linhas"] + 1:
		var faixas := {}
		var cx := 0
		while cy < m["linhas"] and cx < m["colunas"]:
			if e_chao(m, cx, cy):
				cx += 1
				continue
			var inicio := cx
			while cx < m["colunas"] and not e_chao(m, cx, cy):
				cx += 1
			faixas[Vector2i(inicio, cx)] = true
		for chave in abertos.keys():
			if not faixas.has(chave):
				var r: Rect2 = abertos[chave]
				saida.append(r)
				abertos.erase(chave)
		for chave in faixas:
			if abertos.has(chave):
				abertos[chave].size.y += CELULA
			else:
				abertos[chave] = Rect2(chave.x * CELULA, cy * CELULA, (chave.y - chave.x) * CELULA, CELULA)
	return saida

func _recorte(destino: Vector2i, origem: Vector2i, tamanho: Vector2i) -> void:
	draw_texture_rect_region(FOLHA, Rect2(Vector2(destino), Vector2(tamanho)), Rect2(Vector2(origem), Vector2(tamanho)))

func _piso(area: Rect2i, tom: String = "medio") -> void:
	var linhas: Array = PISOS.get(tom, PISOS["medio"])
	for y in range(0, area.size.y, 16):
		for x in range(0, area.size.x, 16):
			var coluna := posmod((area.position.x + x) / 16 * 7 + (area.position.y + y) / 16 * 3, 5)
			var linha: int = linhas[posmod((x + y) / 16, 2)]
			_recorte(area.position + Vector2i(x, y), Vector2i(coluna, linha) * 16, Vector2i(mini(16, area.size.x - x), mini(16, area.size.y - y)))

func _faixa_horizontal(x: int, y: int, largura: int) -> void:
	for dx in range(0, largura, 16):
		_recorte(Vector2i(x + dx, y), Vector2i(400 + (dx / 16 % 5) * 16, 224), Vector2i(mini(16, largura - dx), 8))

func _faixa_vertical(x: int, y: int, altura: int) -> void:
	for dy in range(0, altura, 16):
		_recorte(Vector2i(x, y + dy), Vector2i(496, 224), Vector2i(8, mini(16, altura - dy)))

## Face de madeira (duas linhas) entre x0 e x1, com o chão em y
func _face(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1, 16):
		for linha in 2:
			_recorte(Vector2i(x, y - 32 + linha * 16), Vector2i(17 + posmod((x - x0) / 16, 5), 14 + linha) * 16, Vector2i(mini(16, x1 - x), 16))

func _chao(cx: int, cy: int) -> bool:
	return e_chao(_mapa, cx, cy)

func _draw() -> void:
	if geometria == null or geometria.is_empty():
		return
	for area in geometria["areas"]:
		var r: Array = area["retangulo"]
		_piso(Rect2i(r[0], r[1], r[2], r[3]), area.get("piso", "medio"))
	var colunas: int = _mapa["colunas"]
	var linhas: int = _mapa["linhas"]
	var topos := []
	var cortes := []
	# Bordas de cima (face + topo) e de baixo (só o topo em corte), em trechos contínuos
	for cy in linhas:
		for borda in [-1, 1]:
			var cx := 0
			while cx < colunas:
				if not (_chao(cx, cy) and not _chao(cx, cy + borda)):
					cx += 1
					continue
				var inicio := cx
				while cx < colunas and _chao(cx, cy) and not _chao(cx, cy + borda):
					cx += 1
				if borda < 0:
					_face(inicio * CELULA, cx * CELULA, cy * CELULA)
					topos.append([inicio * CELULA - 8, cy * CELULA - 36, (cx - inicio) * CELULA + 16])
				else:
					cortes.append([inicio * CELULA - 8, (cy + 1) * CELULA, (cx - inicio) * CELULA + 16])
	# Janelas retas, da mesma folha e no plano da face: [x, y do chão embaixo dela]
	for janela in geometria.get("janelas", []):
		_recorte(Vector2i(int(janela[0]), int(janela[1]) - 32), Vector2i(384, 16), Vector2i(32, 32))
	# Lados: o topo em corte sobe junto da face quando não há chão acima, e desce até o corte de baixo
	for lado in [-1, 1]:
		for cx in colunas:
			var cy := 0
			while cy < linhas:
				if not (_chao(cx, cy) and not _chao(cx + lado, cy)):
					cy += 1
					continue
				var inicio := cy
				while cy < linhas and _chao(cx, cy) and not _chao(cx + lado, cy):
					cy += 1
				var y0 := inicio * CELULA - (36 if not _chao(cx, inicio - 1) else 0)
				var y1 := cy * CELULA + (8 if not _chao(cx, cy) else 0)
				var x := cx * CELULA - 8 if lado < 0 else (cx + 1) * CELULA
				_faixa_vertical(x, y0, y1 - y0)
	for faixa in topos + cortes:
		_faixa_horizontal(faixa[0], faixa[1], faixa[2])
