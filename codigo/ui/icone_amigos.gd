extends RefCounted
## Dois bustos lado a lado, no mesmo traço das espadas do PvP, para o acesso à lista de amigos.
static var _textura: Texture2D
static func obter() -> Texture2D:
	if _textura == null:
		var imagem := Image.new()
		imagem.load_svg_from_string('''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
<g fill="#493629" stroke="#ead5a4" stroke-width="0.6" stroke-linejoin="round">
<circle cx="8" cy="8" r="3.4"/><path d="M1.6 20 C1.6 14.8 4.4 13 8 13 C11.6 13 14.4 14.8 14.4 20 Z"/>
<circle cx="16.4" cy="9" r="3"/><path d="M10.6 20 C10.6 15.6 12.8 14 16.4 14 C20 14 22.4 15.6 22.4 20 Z"/>
</g></svg>''', 2.0)
		_textura = ImageTexture.create_from_image(imagem)
	return _textura
