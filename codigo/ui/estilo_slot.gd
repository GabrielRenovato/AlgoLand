extends RefCounted

## O quadrado de item de todas as telas (inventário, equipamento, barra de baixo, bigorna, encantar, venda, cinto de poções, ferramentas da
## fazenda): o sprite de slot do conjunto Bosque, fatiado
## em 9 partes para qualquer tamanho. A cor (raridade, ferramenta em uso) tinge o sprite: a faixa clara fica na cor e o interior escurece junto.

const Raridades := preload("res://codigo/dados/raridades.gd")
const SPRITE_SLOT := preload("res://assets/ui/bosque/slot.png")
## Quadro nativo completo, com cantos alinhados em todos os tamanhos.
const REGIAO := Rect2(0, 0, 24, 24)
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

## Espessura da borda do quadro (contorno, faixa clara, contorno e chanfro)
const BORDA_MOLDURA := 6
## Espaço entre a borda e as casas (para elas não encostarem na moldura)
const FOLGA_MOLDURA := 3

## O painel das barras de baixo: a moldura do inventário sem a faixa de título
static func moldura_barra() -> StyleBoxTexture:
	var moldura := StyleBoxTexture.new()
	moldura.texture = _moldura_sem_titulo()
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_texture_margin(lado, BORDA_MOLDURA)
		moldura.set_content_margin(lado, BORDA_MOLDURA + FOLGA_MOLDURA)
	return moldura

## A moldura simétrica mantém os mesmos cantos dos painéis grandes.
static func _moldura_sem_titulo() -> Texture2D:
	return preload("res://assets/ui/bosque/painel.png")
