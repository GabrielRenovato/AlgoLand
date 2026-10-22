extends Node2D

## Planta física preservada em grade8px; materiais pintados4× e paredes em corte.
## A casa é uma lista de áreas de chão (cômodos e corredores), cada uma com o próprio tom de piso; o que não é
## chão fica de fora, escuro. As paredes saem do contorno, numa grade de 8 px: onde o chão não tem nada acima
## aparece a face de reboco e vigas (32 px) com o topo em corte; nos lados e embaixo, só o topo em corte (8 px). Dois
## cômodos lado a lado dividem uma parede de 8 px; um embaixo do outro precisam de 40 px entre si, o espaço da
## face. Portas são corredores que atravessam esse espaço. As faixas são recortadas, nunca esticadas.
const Biblioteca := preload("res://codigo/cidade/interiores_detalhados.gd")
const CELULA := 8
var FOLHA: Texture2D
var _pisos: Dictionary = {}
var _materiais: Dictionary = {}
var _estacao := -1
var geometria: Dictionary
var casa: String
var _mapa: Dictionary

func configurar(dados: Dictionary, identidade: String) -> void:
	geometria = dados
	casa = identidade
	_mapa = mapa(dados)
	z_index = -999
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _ready() -> void:
	_atualizar_materiais()

func _process(_delta: float) -> void:
	_atualizar_materiais()

func _atualizar_materiais() -> void:
	var atual := Biblioteca.estacao(self)
	if atual == _estacao:
		return
	_estacao = atual
	var pasta: String = Biblioteca.RAIZ + "materiais/" + ["primavera", "verao", "outono", "inverno"][atual] + "/"
	for nome in ["parede", "horizontal", "vertical", "janela"]:
		_materiais[nome] = load(pasta + nome + ".png")
	for tom in ["escuro", "medio", "claro"]:
		_pisos[tom] = load(pasta + "piso_" + tom + ".png")
	FOLHA = _pisos["medio"]
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

func _regiao(textura: Texture2D, destino: Vector2i, origem: Vector2i, tamanho: Vector2i) -> void:
	draw_texture_rect_region(textura, Rect2(Vector2(destino), Vector2(tamanho)), Rect2(Vector2(origem * 4), Vector2(tamanho * 4)))

func _piso(area: Rect2i, tom: String = "medio") -> void:
	var y := area.position.y
	while y < area.end.y:
		var altura := mini(128 - posmod(y, 128), area.end.y - y)
		var x := area.position.x
		while x < area.end.x:
			var largura := mini(128 - posmod(x, 128), area.end.x - x)
			_regiao(_pisos.get(tom, FOLHA), Vector2i(x, y), Vector2i(posmod(x, 128), posmod(y, 128)), Vector2i(largura, altura))
			x += largura
		y += altura

func _faixa_horizontal(x: int, y: int, largura: int) -> void:
	var dx := 0
	while dx < largura:
		var origem := posmod(x + dx, 64)
		var trecho := mini(64 - origem, largura - dx)
		_regiao(_materiais["horizontal"], Vector2i(x + dx, y), Vector2i(origem, 0), Vector2i(trecho, 8))
		dx += trecho
	draw_line(Vector2(x, y + 0.25), Vector2(x + largura, y + 0.25), Color("4a2b16"), 0.5)
	draw_line(Vector2(x, y + 7.75), Vector2(x + largura, y + 7.75), Color("4a2b16"), 0.5)

func _faixa_vertical(x: int, y: int, altura: int) -> void:
	var dy := 0
	while dy < altura:
		var origem := posmod(y + dy, 64)
		var trecho := mini(64 - origem, altura - dy)
		_regiao(_materiais["vertical"], Vector2i(x, y + dy), Vector2i(0, origem), Vector2i(8, trecho))
		dy += trecho
	draw_line(Vector2(x + 0.25, y), Vector2(x + 0.25, y + altura), Color("4a2b16"), 0.5)
	draw_line(Vector2(x + 7.75, y), Vector2(x + 7.75, y + altura), Color("4a2b16"), 0.5)

## Face de reboco e vigas entre x0 e x1, com o chão em y
func _face(x0: int, x1: int, y: int) -> void:
	var x := x0
	while x < x1:
		var origem := posmod(x, 64)
		var largura := mini(64 - origem, x1 - x)
		_regiao(_materiais["parede"], Vector2i(x, y - 32), Vector2i(origem, 0), Vector2i(largura, 32))
		x += largura

func _chao(cx: int, cy: int) -> bool:
	return e_chao(_mapa, cx, cy)

func _draw() -> void:
	if geometria == null or geometria.is_empty() or _materiais.is_empty():
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
	# Janelas no plano da face, com quatro pixels de margem: [x, y do chão].
	for janela in geometria.get("janelas", []):
		draw_texture_rect(_materiais["janela"], Rect2(int(janela[0]) + 4, int(janela[1]) - 28, 24, 24), false)
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
