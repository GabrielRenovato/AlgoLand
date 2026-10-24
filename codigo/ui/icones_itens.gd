extends RefCounted

const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const CoresArmas := preload("res://codigo/dados/cores_armas_raven.gd")

const ARMAS_RAVEN := ["espada_basica","espada_gemea","machado","lanca_basica","arco_curto","escudo_basico"]
const ARMAS_LEGADAS := ["maca","arco_curvo","arco_longo"]
const ARMAS := {}
const COLUNAS_ARMAS := 8
const LINHAS_ARMAS := 8
const ALJAVA := "res://assets/personagens/raven_fantasy/icones/aljava_basica.png"
const QUADRO_ALJAVA := Rect2i(0,0,7,18)
const ARMADURAS := {
	"cabeca_basica": "sprite_armadura_cabeca",
	"armadura_basica": "sprite_armadura_corpo",
	"luvas_basicas": "sprite_armadura_luvas",
	"botas_basicas": "sprite_armadura_botas",
}

# AreaAtaque e AttackTimer tambem estao no grupo "character"
static func obter_jogador(arvore: SceneTree) -> Node:
	# Slot montado fora da árvore (a mochila preenche antes de entrar na cena): sem jogador para consultar
	if arvore == null:
		return null
	for no in arvore.get_nodes_in_group("character"):
		if no is CharacterBody2D:
			return no
	return null

static var _icones_vara: Dictionary = {}

## Ícone da vara no tom do nível (a mesma mistura de cor_vara.gdshader: o brilho do desenho vira a cor do nível)
static func icone_vara(nivel: int) -> Texture2D:
	var chave := clampi(nivel, 1, 5)
	if not _icones_vara.has(chave):
		var imagem: Image = preload("res://assets/pesca/vara.png").get_image()
		imagem.convert(Image.FORMAT_RGBA8)
		var cor: Color = preload("res://codigo/pesca/varas.gd").CORES[chave - 1]
		for y in imagem.get_height():
			for x in imagem.get_width():
				var pixel := imagem.get_pixel(x, y)
				if pixel.a <= 0.0:
					continue
				var luz := maxf(pixel.r, maxf(pixel.g, pixel.b))
				imagem.set_pixel(x, y, Color(lerpf(pixel.r, cor.r * luz, 0.85), lerpf(pixel.g, cor.g * luz, 0.85),
						lerpf(pixel.b, cor.b * luz, 0.85), pixel.a))
		_icones_vara[chave] = ImageTexture.create_from_image(imagem)
	return _icones_vara[chave]

static func obter(item: DadosItem, arvore: SceneTree) -> Texture2D:
	if item == null:
		return null
	if item.categoria == "comida":
		return preload("res://codigo/dados/refeicoes.gd").icone(item.conteudo())
	if item.categoria == "receita":
		return load("res://assets/ui/coletaveis/receita.png")
	if item.categoria == "produto":
		return load("res://assets/cenario/fazenda/galinheiro/%s.png" % ("racao" if item.conteudo() == "feno" else "ovo"))
	if item.categoria == "material":
		return load("res://assets/ui/coletaveis/%s.png" % item.conteudo())
	if item.categoria == "colheita":
		return IconesFazenda.item_colhido(item.conteudo())
	if item.categoria == "pocao":
		return preload("res://codigo/dados/pocoes.gd").icone(item.conteudo())
	if item.categoria == "peixe":
		return preload("res://codigo/pesca/peixes.gd").icone(item.peixe())
	if item.categoria == "vara":
		return icone_vara(item.nivel)
	# Ferramentas e sementes da fazenda: o mesmo ícone da barra (saco de semente, enxada, regador, mão)
	if item.categoria == "ferramenta" or item.categoria == "semente":
		return IconesFazenda.da_ferramenta(item.tipo)
	var conjunto := Conjuntos.de_tipo(item.tipo)
	if conjunto != null:
		var peca: String = conjunto.TIPOS[item.tipo]["peca"]
		return _recortar(load(conjunto.RAIZ_SPRITES + "%s/andar.png" % peca), Rect2i(0, 0, 64, 64))
	if item.tipo == "aljava_basica":
		# Ícone individual do acessório, compartilhado com a camada Raven.
		return load(ALJAVA)
	if item.tipo in ARMAS_RAVEN or item.tipo in ARMAS_LEGADAS:
		return obter_arma(item.tipo, arvore, item.nivel)
	if ARMAS.get(item.tipo, {}).has("pasta_icone"):
		return load(ARMAS[item.tipo]["pasta_icone"] % clampi(item.nivel, 1, 5))
	if ARMAS.has(item.tipo):
		return obter_arma(item.tipo, arvore, item.nivel)
	if ARMADURAS.has(item.tipo):
		return load("res://assets/personagens/raven_fantasy/icones/%s.png" % item.tipo)
	var jogador := obter_jogador(arvore)
	if ARMADURAS.has(item.tipo) and jogador != null:
		var sprite_armadura: Sprite2D = jogador.get(ARMADURAS[item.tipo])
		if sprite_armadura != null and sprite_armadura.texture != null:
			var tamanho := Vector2i(sprite_armadura.texture.get_size()) / Vector2i(sprite_armadura.hframes,sprite_armadura.vframes)
			return _recortar(sprite_armadura.texture, Rect2i(sprite_armadura.get_frame_coords()*tamanho,tamanho))
	return null

static func obter_arma(tipo: String, arvore: SceneTree, nivel: int = 1) -> Texture2D:
	if tipo in ARMAS_RAVEN or tipo in ARMAS_LEGADAS:
		return CoresArmas.icone(tipo,nivel)
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
