extends RefCounted

## Separa a terra da grama nos tiles mistos do atlas sazonal da fazenda.
## A paleta vem dos tiles de terra pura da própria folha, sem estimar por brilho ou matiz.
const LADO := 16
const FOLHAS: Array[Texture2D] = [
	preload("res://assets/cenario/Seasonal Forest/arena/spring.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/summer.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/autumn.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/winter.png"),
]
const CENTROS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
static var _imagens: Dictionary = {}
static var _paletas: Dictionary = {}

static func cobre_pixel(estacao: int, atlas: Vector2i, x: int, y: int) -> bool:
	if atlas.x < 0 or atlas.y < 0 or x < 0 or y < 0 or x >= LADO or y >= LADO:
		return false
	if not _imagens.has(estacao):
		var imagem := FOLHAS[estacao].get_image()
		if imagem.is_compressed():
			imagem.decompress()
		_imagens[estacao] = imagem
		var paleta := {}
		for centro in CENTROS:
			for cy in LADO:
				for cx in LADO:
					paleta[imagem.get_pixel(centro.x * LADO + cx, centro.y * LADO + cy).to_rgba32()] = true
		_paletas[estacao] = paleta
	var folha: Image = _imagens[estacao]
	var ponto := atlas * LADO + Vector2i(x, y)
	if ponto.x >= folha.get_width() or ponto.y >= folha.get_height():
		return false
	return _paletas[estacao].has(folha.get_pixelv(ponto).to_rgba32())
