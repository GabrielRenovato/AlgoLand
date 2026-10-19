extends TextureRect

## Conjunto original do mapa: nove silhuetas sem molduras, em atlas 3x3 com transparencia.
var tipo := "casa"
const ATLAS := preload("res://assets/ui/mapa_mundi/servicos.png")
const CELULAS := {
	"casa":Vector2i(0,0), "martelo":Vector2i(1,0), "livro":Vector2i(2,0),
	"moeda":Vector2i(0,1), "cura":Vector2i(1,1), "cama":Vector2i(2,1),
	"horta":Vector2i(0,2), "estrela":Vector2i(1,2), "peixe":Vector2i(2,2),
}
static var _texturas: Dictionary = {}
func _ready() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_IGNORE
	if not _texturas.has(tipo):
		var celula: Vector2i = CELULAS.get(tipo,Vector2i.ZERO)
		var tamanho := ATLAS.get_size()
		var inicio := Vector2i((Vector2(celula)*tamanho/3).floor())
		var fim := Vector2i((Vector2(celula+Vector2i.ONE)*tamanho/3).floor())
		var regiao := Rect2i(inicio,fim-inicio)
		# Mede a silhueta dentro da celula: os diferentes formatos usam o mesmo tamanho visual.
		var desenho := ATLAS.get_image().get_region(regiao).get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = ATLAS
		atlas.region = Rect2(Rect2i(inicio+desenho.position,desenho.size))
		_texturas[tipo] = atlas
	texture = _texturas[tipo]
