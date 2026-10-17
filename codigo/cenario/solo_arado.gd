extends RefCounted
## A textura preenche o canteiro; o contorno depende das oito células vizinhas.
## Terra seca e molhada compartilham o contorno externo, sem divisórias entre tiles.

const LimitePlantio := preload("res://codigo/cenario/limite_plantio.gd")
const LADO := 16
const SECA := preload("res://assets/cenario/fazenda/terra_arada_seca.png")
const MOLHADA := preload("res://assets/cenario/fazenda/terra_arada_molhada.png")
const VARIANTES := 5
const TONS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.95, 0.87), Color(0.93, 0.82, 0.76), Color(0.82, 0.86, 0.94),
]
const NORTE := 1
const LESTE := 2
const SUL := 4
const OESTE := 8
const NOROESTE := 16
const NORDESTE := 32
const SUDESTE := 64
const SUDOESTE := 128
const DIRECOES: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1),
]
## Recuo em pixels: arredonda os cantos externos sem suavizar o pixel art.
const CANTO := [6, 4, 3, 2, 2, 1, 1, 1]
static var _texturas: Dictionary = {}
static var _seca: Image
static var _molhada: Image

static func vizinhos(solo: Dictionary, celula: Vector2i, apenas_molhados := false) -> int:
	var mascara := 0
	for i in DIRECOES.size():
		var vizinho := celula + DIRECOES[i]
		if solo.has(vizinho) and (not apenas_molhados or bool(solo[vizinho].get("molhado", false))):
			mascara |= 1 << i
	return mascara

static func textura(estacao: int, molhado: bool, celula: Vector2i, ligacoes := 0, regadas := 0, atlas := Vector2i(-1, -1), tiny := false) -> Texture2D:
	var variante := posmod(celula.x * 7 + celula.y * 13, VARIANTES)
	regadas = (regadas & ligacoes) if molhado else 0
	var combinacao := ((((estacao * 2 + int(molhado)) * VARIANTES + variante) * 256 + ligacoes) * 256 + regadas)
	var chave := Vector3i(combinacao * 2 + int(tiny), atlas.x, atlas.y)
	if _texturas.has(chave):
		return _texturas[chave]
	if _seca == null:
		_seca = SECA.get_image()
		_molhada = MOLHADA.get_image()
		if _seca.is_compressed():
			_seca.decompress()
		if _molhada.is_compressed():
			_molhada.decompress()
	var imagem := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	var seca := _seca
	var molhada := _molhada
	if tiny:
		var pasta: String = "res://assets/cenario/fazenda/tiny/" + ["primavera", "verao", "outono", "inverno"][estacao] + "/"
		seca = load(pasta + "arado_seco.png").get_image()
		molhada = load(pasta + "arado_molhado.png").get_image()
	for y in LADO:
		for x in LADO:
			if not _cobre_pixel(x, y, ligacoes):
				continue
			if atlas.x >= 0 and not LimitePlantio.cobre_pixel(estacao, atlas, x, y):
				continue
			var origem_x := posmod(x + variante * 3, LADO)
			var cor := seca.get_pixel(origem_x, y)
			# A mancha molhada também arredonda onde encontra terra ainda seca.
			if molhado and _cobre_pixel(x, y, regadas):
				cor = molhada.get_pixel(origem_x, y)
			# Relevo discreto só no contorno externo, nunca nas emendas do canteiro.
			if not _cobre_pixel(x, y - 1, ligacoes):
				cor = cor.darkened(0.18)
			elif not _cobre_pixel(x, y + 1, ligacoes):
				cor = cor.lightened(0.10)
			elif not _cobre_pixel(x - 1, y, ligacoes) or not _cobre_pixel(x + 1, y, ligacoes):
				cor = cor.darkened(0.10)
			imagem.set_pixel(x, y, cor * TONS[estacao])
	var resultado := ImageTexture.create_from_image(imagem)
	_texturas[chave] = resultado
	return resultado

static func _cobre_pixel(x: int, y: int, ligacoes: int) -> bool:
	# Consultas fora do tile servem para não desenhar relevo numa emenda conectada.
	if x < 0:
		return (ligacoes & OESTE) != 0
	if x >= LADO:
		return (ligacoes & LESTE) != 0
	if y < 0:
		return (ligacoes & NORTE) != 0
	if y >= LADO:
		return (ligacoes & SUL) != 0
	var esquerda := x < LADO / 2
	var cima := y < LADO / 2
	var horizontal := (ligacoes & (OESTE if esquerda else LESTE)) != 0
	var vertical := (ligacoes & (NORTE if cima else SUL)) != 0
	var diagonal := (NOROESTE if esquerda else NORDESTE) if cima else (SUDOESTE if esquerda else SUDESTE)
	var dx := mini(x, LADO - 1 - x)
	var dy := mini(y, LADO - 1 - y)
	# Pequenos recortes quebram as retas longas; a mesma silhueta vale nos dois estados.
	if not horizontal and dx < (2 if y == 5 or y == 11 else 1):
		return false
	if not vertical and dy < (2 if x == 4 or x == 10 else 1):
		return false
	if not horizontal and not vertical:
		return dx >= CANTO[dy]
	if horizontal and vertical and (ligacoes & diagonal) == 0:
		return dx + dy >= 3
	return true
