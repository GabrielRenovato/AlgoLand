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
static var _campos: Dictionary = {}
static var _detalhados: Dictionary = {}
static var _campos_detalhados: Dictionary = {}

## O acabamento 4x usa o mesmo contorno e relevo seco/molhado da versão lógica.
static func textura_detalhada(estacao: int, molhado: bool, celula: Vector2i, ligacoes: int, regadas: int, atlas: Vector2i) -> Texture2D:
	var base := textura(estacao,molhado,celula,ligacoes,regadas,atlas,false)
	var chave := base.get_instance_id()
	if _detalhados.has(chave): return _detalhados[chave]
	if not _campos_detalhados.has(estacao):
		_campos_detalhados[estacao]=load("res://assets/cenario/fazenda/natureza_detalhada/%s/terra.png" % ["primavera","verao","outono","inverno"][estacao]).get_image()
	var campo: Image=_campos_detalhados[estacao]
	var logica:=base.get_image()
	var imagem:=Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var px:=x/4
			var py:=y/4
			var cor:=logica.get_pixel(px,py)
			if cor.a<.01: continue
			var antigo: Color=_campos[estacao].get_pixel(posmod(celula.x*16+px,128),posmod(celula.y*16+py,128))
			var relevo:=clampf(cor.r/maxf(antigo.r,.01),.30,1.15)
			var nova:=campo.get_pixel(posmod(celula.x*64+x,512),posmod(celula.y*64+y,512))*relevo
			nova.a=cor.a
			imagem.set_pixel(x,y,nova)
	var resultado:=ImageTexture.create_from_image(imagem)
	_detalhados[chave]=resultado
	return resultado

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
	var fase := posmod(celula.x,8) + posmod(celula.y,8)*8
	var chave := Vector4i(combinacao * 2 + int(tiny), atlas.x, atlas.y, fase)
	if _texturas.has(chave):
		return _texturas[chave]
	if _seca == null:
		_seca = SECA.get_image()
		_molhada = MOLHADA.get_image()
		if _seca.is_compressed():
			_seca.decompress()
		if _molhada.is_compressed():
			_molhada.decompress()
	if not tiny and not _campos.has(estacao):
		_campos[estacao] = load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % ["spring","summer","autumn","winter"][estacao]).get_image()
		if _campos[estacao].is_compressed(): _campos[estacao].decompress()
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
			if not tiny:
				var base: Color = _campos[estacao].get_pixel(posmod(celula.x*16+x,128),posmod(celula.y*16+y,128))
				# Mantém a textura lavrada seca/molhada, com a cor e fase do solo novo.
				cor = base * clampf(cor.r*1.5+0.1,0.40,0.90)
				cor.a = 1.0
			# Relevo discreto só no contorno externo, nunca nas emendas do canteiro.
			if not _cobre_pixel(x, y - 1, ligacoes):
				cor = cor.darkened(0.18)
			elif not _cobre_pixel(x, y + 1, ligacoes):
				cor = cor.lightened(0.10)
			elif not _cobre_pixel(x - 1, y, ligacoes) or not _cobre_pixel(x + 1, y, ligacoes):
				cor = cor.darkened(0.10)
			imagem.set_pixel(x, y, cor * TONS[estacao] if tiny else cor)
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
