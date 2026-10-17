extends RefCounted

## Os mesmos glifos nos botões virtuais e nos avisos de interação.
const FOLHA := "res://assets/ui/Cute RPG - Icons (1)/Cute RPG - Icons/32x32/CuteRPG_Icons01.png"
const INTERAGIR := Vector2i(15,5)
static var _cache := {}

static func glifo(celula: Vector2i) -> Texture2D:
	if _cache.has(celula):
		return _cache[celula]
	var folha: Texture2D = load(FOLHA)
	var imagem := folha.get_image().get_region(Rect2i(celula*32+Vector2i(4,4),Vector2i(24,24)))
	imagem.convert(Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var cor := imagem.get_pixel(x,y)
			imagem.set_pixel(x,y,Color.WHITE if cor.a > 0.5 and minf(cor.r,minf(cor.g,cor.b)) > 0.9 else Color(1,1,1,0))
	_cache[celula] = ImageTexture.create_from_image(imagem)
	return _cache[celula]
