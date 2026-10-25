extends RefCounted
## Porte adaptado das posições gravadas pelo autor no AnimationPlayer Mana Seed.
## O objeto continua separado do corpo, da roupa e do cabelo.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
static var _dados: Dictionary = {}
static var _texturas: Dictionary = {}

static func pose(tipo: String, acao: String, direcao: int, quadro: int) -> Dictionary:
	if _dados.is_empty():
		_dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_fantasy/porte_costas.json"))
	var estados: Dictionary = _dados.armas[tipo]
	return estados.running[direcao][quadro] if acao == "correr" else estados.idle[direcao][0]

static func textura(tipo: String) -> Texture2D:
	if not _texturas.has(tipo):
		if _dados.is_empty(): pose(tipo,"parado",0,0)
		var caixa: Array = _dados.armas[tipo].caixa
		var atlas := AtlasTexture.new()
		atlas.atlas = Raven.folha("ferramentas",tipo)
		atlas.region = Rect2(caixa[0],caixa[1],caixa[2],caixa[3])
		atlas.filter_clip = true
		_texturas[tipo] = atlas
	return _texturas[tipo]

## Mesmo tamanho e pivô da arma inteira; só o couro do cabo sobe diante do elmo.
static func textura_cabo(tipo: String) -> Texture2D:
	var chave := "cabo:"+tipo
	if not _texturas.has(chave):
		var imagem := textura(tipo).get_image()
		imagem.convert(Image.FORMAT_RGBA8)
		for y in imagem.get_height():
			for x in imagem.get_width():
				if imagem.get_pixel(x,y) != Color("745c42"):
					imagem.set_pixel(x,y,Color.TRANSPARENT)
		_texturas[chave] = ImageTexture.create_from_image(imagem)
	return _texturas[chave]
