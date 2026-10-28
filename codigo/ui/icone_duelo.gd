extends RefCounted
## Duas espadas simétricas, centralizadas pelo desenho, para o acesso ao PvP.
static var _textura: Texture2D
static func obter() -> Texture2D:
	if _textura == null:
		var imagem := Image.new()
		imagem.load_svg_from_string('''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
<g fill="#493629" stroke="#ead5a4" stroke-width="0.6" stroke-linejoin="round">
<g transform="rotate(-45 12 12)"><path d="M12 1 L14 5 V15 H17 V17 H13.5 V21 H14 V23 H10 V21 H10.5 V17 H7 V15 H10 V5 Z"/></g>
<g transform="rotate(45 12 12)"><path d="M12 1 L14 5 V15 H17 V17 H13.5 V21 H14 V23 H10 V21 H10.5 V17 H7 V15 H10 V5 Z"/></g>
</g></svg>''', 2.0)
		_textura = ImageTexture.create_from_image(imagem)
	return _textura
