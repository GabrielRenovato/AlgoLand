extends RefCounted

const COLUNAS_ARMAS := 8
const LINHAS_ARMAS := 8
const ARMAS := {
	"espada_basica": {"sprite": "sprite_espada", "frame": 42, "alternativa": "res://CharacterSprites/Arms/swords/Sword_1.png"},
	"lanca_basica": {"sprite": "sprite_lanca", "frame": 13, "alternativa": "res://CharacterSprites/Arms/spears/spear_1.png"},
	"escudo_basico": {"sprite": "sprite_escudo", "frame": 32, "alternativa": "res://CharacterSprites/Arms/shields/shield_1.png"},
}
const ARMADURAS := {
	"cabeca_basica": "sprite_armadura_cabeca",
	"armadura_basica": "sprite_armadura_corpo",
	"luvas_basicas": "sprite_armadura_luvas",
	"botas_basicas": "sprite_armadura_botas",
}

# AreaAtaque e AttackTimer tambem estao no grupo "character"
static func obter_jogador(arvore: SceneTree) -> Node:
	for no in arvore.get_nodes_in_group("character"):
		if no is CharacterBody2D:
			return no
	return null

static func obter(item: DadosItem, arvore: SceneTree) -> Texture2D:
	if item == null:
		return null
	var jogador := obter_jogador(arvore)
	if ARMAS.has(item.tipo):
		var definicao: Dictionary = ARMAS[item.tipo]
		var textura: Texture2D = null
		if jogador != null:
			var sprite: Sprite2D = jogador.get(definicao["sprite"])
			if sprite != null:
				textura = sprite.texture
		if textura == null and ResourceLoader.exists(definicao["alternativa"]):
			textura = load(definicao["alternativa"])
		if textura == null:
			return null
		var tamanho := textura.get_size()
		var largura := int(tamanho.x / float(COLUNAS_ARMAS))
		var altura := int(tamanho.y / float(LINHAS_ARMAS))
		var quadro: int = definicao["frame"]
		var regiao := Rect2i((quadro % COLUNAS_ARMAS) * largura, int(quadro / float(COLUNAS_ARMAS)) * altura, largura, altura)
		return _recortar(textura, regiao)
	if ARMADURAS.has(item.tipo) and jogador != null:
		var sprite_armadura: Sprite2D = jogador.get(ARMADURAS[item.tipo])
		if sprite_armadura != null and sprite_armadura.texture != null:
			return _recortar(sprite_armadura.texture, Rect2i(Vector2i.ZERO, Vector2i(sprite_armadura.texture.get_size())))
	return null

# Os quadros tem muito espaco transparente; recorta ao conteudo para o icone nao ficar minusculo em 14px
static func _recortar(textura: Texture2D, regiao: Rect2i) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2(regiao)
	var imagem := textura.get_image()
	if imagem == null or imagem.is_empty():
		return atlas
	var usado := imagem.get_region(regiao).get_used_rect()
	if usado.size == Vector2i.ZERO:
		return atlas
	atlas.region = Rect2(regiao.position + usado.position, usado.size)
	return atlas
