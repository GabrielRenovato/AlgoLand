extends RefCounted

## O quadrado de item de todas as telas (inventário, equipamento, barra de baixo, bigorna, encantar, venda, cinto de poções, ferramentas da
## fazenda): o sprite de slot do pacote de interface da mochila (craftpix "2 Buttons/17.png", o mesmo dos botões de item da loja), fatiado
## em 9 partes para qualquer tamanho. A cor (raridade, ferramenta em uso) tinge o sprite: a faixa clara fica na cor e o interior escurece junto.

const Raridades := preload("res://codigo/dados/raridades.gd")
const SPRITE_SLOT := preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/2 Buttons/17.png")
## O desenho ocupa só esta parte da imagem de 21x21 (o resto é transparente)
const REGIAO := Rect2(1, 1, 19, 17)
## Contorno, faixa clara e o chanfro do canto: não esticam
const MARGEM := 4.0

## O quadrado do slot, tingido com `cor` (branco = o sprite como é)
static func caixa(cor: Color = Color.WHITE) -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	estilo.texture = SPRITE_SLOT
	estilo.region_rect = REGIAO
	estilo.texture_margin_left = MARGEM
	estilo.texture_margin_top = MARGEM
	estilo.texture_margin_right = MARGEM
	estilo.texture_margin_bottom = MARGEM
	estilo.modulate_color = cor
	return estilo

## O quadrado na cor da raridade do item (comum: o sprite como é)
static func caixa_raridade(raridade: String) -> StyleBoxTexture:
	return caixa(Color.WHITE if raridade == "comum" else cor_da_raridade(raridade))

## A cor que tinge o sprite: a da raridade um pouco mais clara, porque o tingimento multiplica a faixa (que já é cinza) e a escureceria
static func cor_da_raridade(raridade: String) -> Color:
	return Raridades.cor(raridade).lightened(0.25)

# --- Moldura das barras de baixo (arena e fazenda) ------------------------------------------------------------------

## A moldura da tela do inventário: o mesmo quadro da mesma folha de interface (craftpix TileMap). Ele tem uma faixa de título de 16 em cima,
## que numa barra não tem função: as barras usam o quadro com a borda de baixo espelhada no lugar da faixa
const FOLHA_INTERFACE := preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/1 Interface/TileMap.png")
const REGIAO_QUADRO := Rect2i(96, 64, 48, 48)
const ALTURA_FAIXA_TITULO := 16
## Espessura da borda do quadro (contorno, faixa clara, contorno e chanfro)
const BORDA_MOLDURA := 6
## Espaço entre a borda e as casas (para elas não encostarem na moldura)
const FOLGA_MOLDURA := 3

static var _moldura_cache: Texture2D = null

## O painel das barras de baixo: a moldura do inventário sem a faixa de título
static func moldura_barra() -> StyleBoxTexture:
	var moldura := StyleBoxTexture.new()
	moldura.texture = _moldura_sem_titulo()
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_texture_margin(lado, BORDA_MOLDURA)
		moldura.set_content_margin(lado, BORDA_MOLDURA + FOLGA_MOLDURA)
	return moldura

## O quadro sem a faixa de título: as BORDA_MOLDURA linhas de baixo do quadro, espelhadas, viram o topo, e o resto é o quadro a partir de
## onde a faixa termina. São os pixels do próprio sprite; montado uma vez só
static func _moldura_sem_titulo() -> Texture2D:
	if _moldura_cache != null:
		return _moldura_cache
	var folha := FOLHA_INTERFACE.get_image()
	if folha.is_compressed():
		folha.decompress()
	folha.convert(Image.FORMAT_RGBA8)
	var quadro := folha.get_region(REGIAO_QUADRO)
	var largura := quadro.get_width()
	var altura_resto := quadro.get_height() - ALTURA_FAIXA_TITULO
	var nova := Image.create(largura, BORDA_MOLDURA + altura_resto, false, Image.FORMAT_RGBA8)
	for y in BORDA_MOLDURA:
		for x in largura:
			nova.set_pixel(x, y, quadro.get_pixel(x, quadro.get_height() - 1 - y))
	nova.blit_rect(quadro, Rect2i(0, ALTURA_FAIXA_TITULO, largura, altura_resto), Vector2i(0, BORDA_MOLDURA))
	_moldura_cache = ImageTexture.create_from_image(nova)
	return _moldura_cache
