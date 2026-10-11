extends RefCounted

const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")

const COLUNAS_ARMAS := 8
const LINHAS_ARMAS := 8
const ARMAS := {
	"espada_basica": {"sprite": "sprite_espada", "frame": 42, "alternativa": "res://CharacterSprites/Arms/swords/Sword_1.png"},
	"espada_gemea": {"frame": 42, "alternativa": "res://CharacterSprites/Arms/espada_gemea/base_1.png"},
	"machado": {"frame": 42, "alternativa": "res://CharacterSprites/Arms/machado/base_1.png"},
	"maca": {"frame": 42, "alternativa": "res://CharacterSprites/Arms/maca/base_1.png"},
	"arco_curto": {"pasta_icone": "res://CharacterSprites/Arco/arcos/icone_bo02_%d.png"},
	"arco_curvo": {"pasta_icone": "res://CharacterSprites/Arco/arcos/icone_bo01_%d.png"},
	"arco_longo": {"pasta_icone": "res://CharacterSprites/Arco/arcos/icone_bo03_%d.png"},
	"lanca_basica": {"sprite": "sprite_lanca", "frame": 13, "alternativa": "res://CharacterSprites/Arms/spears/spear_1.png"},
	"escudo_basico": {"sprite": "sprite_escudo", "frame": 32, "alternativa": "res://CharacterSprites/Arms/shields/shield_1.png"},
}
const ALJAVA := "res://CharacterSprites/Arco/carregando/aljava.png"
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
	if item.tipo == "aljava_basica":
		return load(ALJAVA)
	if ARMAS.get(item.tipo, {}).has("pasta_icone"):
		return load(ARMAS[item.tipo]["pasta_icone"] % clampi(item.nivel, 1, 5))
	if ARMAS.has(item.tipo):
		return obter_arma(item.tipo, arvore, item.nivel)
	var jogador := obter_jogador(arvore)
	if ARMADURAS.has(item.tipo) and jogador != null:
		var sprite_armadura: Sprite2D = jogador.get(ARMADURAS[item.tipo])
		if sprite_armadura != null and sprite_armadura.texture != null:
			return _recortar(sprite_armadura.texture, Rect2i(Vector2i.ZERO, Vector2i(sprite_armadura.texture.get_size())))
	return null

static func obter_arma(tipo: String, arvore: SceneTree, nivel: int = 1) -> Texture2D:
	if not ARMAS.has(tipo):
		return null
	var definicao: Dictionary = ARMAS[tipo]
	if definicao.has("pasta_icone"):
		return load(definicao["pasta_icone"] % 1)
	# A textura vem dos dados do nível do item, não dos sprites do jogador (que podem mostrar outra coisa,
	# como a aljava no nó do escudo enquanto o arco está equipado)
	var textura: Texture2D = null
	var banco := Equipamentos.new()
	var dados_nivel: Dictionary = banco.obter_dados_nivel_arma(tipo, nivel)
	banco.free()
	if dados_nivel.get("textura") is Texture2D:
		textura = dados_nivel["textura"]
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
