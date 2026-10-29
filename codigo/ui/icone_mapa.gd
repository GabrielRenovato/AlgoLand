extends RefCounted
## Mapa dobrado em três partes com um marcador, no mesmo traço dos ícones de PvP e amigos.
static var _textura: Texture2D
static func obter() -> Texture2D:
	if _textura == null:
		var imagem := Image.new()
		imagem.load_svg_from_string('''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
<g fill="#493629" stroke="#ead5a4" stroke-width="0.6" stroke-linejoin="round">
<path d="M2 5.5 L8 3.5 L16 6 L22 4 L22 18.5 L16 20.5 L8 18 L2 20 Z"/>
</g>
<g stroke="#ead5a4" stroke-width="0.6" fill="none"><path d="M8 3.5 V18"/><path d="M16 6 V20.5"/></g>
<g fill="#ead5a4" stroke="#493629" stroke-width="0.5"><path d="M12 7.2 C9.9 7.2 8.6 8.7 8.6 10.4 C8.6 12.6 12 16 12 16 C12 16 15.4 12.6 15.4 10.4 C15.4 8.7 14.1 7.2 12 7.2 Z"/></g>
<circle cx="12" cy="10.3" r="1.2" fill="#493629"/>
</svg>''', 2.0)
		_textura = ImageTexture.create_from_image(imagem)
	return _textura
