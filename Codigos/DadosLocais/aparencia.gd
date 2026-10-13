extends RefCounted

## Cabelos e roupas do personagem: a lista (na ordem em que o save guarda o índice) e a textura de cada peça em cada "página" de animação.
##
## O jogador é desenhado em camadas (corpo, roupa, cabelo...) e cada animação usa uma folha própria, porque o corpo muda de pose:
##   andar (correr/parado), fazenda (enxada, regador, colher), forja e sentado (página 4 do Character Base),
##   espada e lança (golpes), reacao_um_mao / reacao_lanca / reacao_arco (sacar, esquiva, ferido, aparar) e arco_p2 / arco_p3 (disparo).
## As peças ANTIGAS (cabelos bob1 e dap1; roupas íntima, cueca, camponês e lenhador) existem em todas as páginas, nas pastas de sempre de
## CharacterSprites/. As peças NOVAS (CharacterSprites/Aparencia/) vêm dos pacotes só nas páginas andar, fazenda e página 4 (forja e sentado).
## Nas páginas de combate (onde os pacotes de arte não trazem as peças novas):
##   - cabelos novos: folhas SINTETIZADAS por ferramentas/personagem/importar_aparencia.gd (o cabelo de pé do estilo novo posto na cabeça,
##     onde o bob1 está em cada quadro), então o personagem não troca de cabelo ao golpear;
##   - roupas novas: a roupa antiga de forma mais parecida serve de molde (única arte de golpe que existe) e é RECOLORIDA com as cores da nova pelo
##     mesmo programa (roupas/<id>_<pagina>.png; o molde de cada uma está em aparencia_combate.gd). A forma é a do molde, as cores são as da nova.
## Índices antigos nunca mudam, para os saves valerem: as peças novas ficam depois.
##
## Uso: Aparencia.cabelo(indice, "andar"), Aparencia.roupa(indice, "espada"), Aparencia.nomes_cabelos()...

const Carrasco := preload("res://Codigos/DadosLocais/conjunto_carrasco.gd")
const PadraoArmadura := preload("res://Codigos/DadosLocais/padrao_armadura.gd")
const Combate := preload("res://Codigos/DadosLocais/aparencia_combate.gd")
const CartolaSobreCabelo := preload("res://Codigos/Jogador/cartola_sobre_cabelo.gd")

const RAIZ := "res://CharacterSprites/"
const PASTA_NOVAS := "res://CharacterSprites/Aparencia/"
## Prévias cosméticas: sem drops, status ou bônus de conjunto.
const ARMADURAS_VISUAIS := {
	"armadura_cavaleiro": "res://CharacterSprites/ArmaduraCavaleiro/",
	"armadura_cavaleiro_rubro": "res://CharacterSprites/Conjuntos/cavaleiro_rubro/",
	"traje_cavalheiro": "res://CharacterSprites/Conjuntos/cavalheiro/",
}

const PAGINAS_ANDAR := ["andar", "fazenda", "forja", "sentado"]
const PAGINAS_COMBATE := ["espada", "lanca", "reacao_um_mao", "reacao_lanca", "reacao_arco", "arco_p2", "arco_p3"]
## Página do pacote Mana Seed de cada página nossa, no nome dos arquivos novos (forja e sentado são quadros diferentes da mesma folha)
const PAGINA_DO_ARQUIVO := {"andar": "p1", "fazenda": "p2", "forja": "p4", "sentado": "p4"}

static var _cabelos: Array[Dictionary] = []
static var _roupas: Array[Dictionary] = []
const PECAS_CAVALEIRO := {"elmo": 1, "peitoral": 2, "luvas": 4, "botas": 8}
static var _cache_cavaleiro: Dictionary = {}
static var _cobertura_cavaleiro: Dictionary = {}

# --- A lista ---------------------------------------------------------------------------------------------------

## Cada item: {"id", "nome", "grupo", "legado" (número 1-based nos arquivos antigos, 0 se for nova), "combate" (roupas novas: índice da roupa antiga
## que a substitui nas páginas de combate)}
static func cabelos() -> Array[Dictionary]:
	if _cabelos.is_empty():
		_cabelos = [
			_item("bob1", "BOB CURTO", "CURTO", 1),
			_item("dap1", "RABICO", "PRESO", 2),
			_novo("bob2", "BOB LONGO", "CURTO", {}),
			_novo("flat", "MILITAR", "CURTO", {}),
			_novo("fro1", "BLACK POWER", "VOLUME", {}),
			_novo("pon1", "COQUE ALTO", "PRESO", {}),
			_novo("spk2", "ESPETADO", "VOLUME", {}),
		]
	return _cabelos

static func roupas() -> Array[Dictionary]:
	if _roupas.is_empty():
		_roupas = [
			_item("undi", "ROUPA INTIMA", "BASICA", 1),
			_item("boxr", "CUECA", "BASICA", 2),
		]
		# camponês: arquivos antigos 3 a 7 = pfpn v05..v01; lenhador: 8 a 12 = fstr v01..v05
		for i in 5:
			_roupas.append(_item("pfpn_v0%d" % (5 - i), "CAMPONES %d" % (i + 1), "CAMPONES", 3 + i))
		for i in 5:
			_roupas.append(_item("fstr_v0%d" % (i + 1), "LENHADOR %d" % (i + 1), "LENHADOR", 8 + i))
		for i in 5:
			_roupas.append(_novo("pfdr_v0%d" % (i + 1), "VESTIDO %d" % (i + 1), "VESTIDO", Combate.ROUPAS))
		for i in 5:
			_roupas.append(_novo("angl_v0%d" % (i + 1), "PESCADOR %d" % (i + 1), "PESCADOR", Combate.ROUPAS))
		for i in 5:
			_roupas.append(_novo("bksm_v0%d" % (i + 1), "FERREIRO %d" % (i + 1), "FERREIRO", Combate.ROUPAS))
		for i in 5:
			_roupas.append(_novo("alch_v0%d" % (i + 1), "ALQUIMISTA %d" % (i + 1), "ALQUIMISTA", Combate.ROUPAS))
		var cores_capa := ["v01", "v03", "v05", "v07", "v09"]
		for i in 5:
			_roupas.append(_novo("capal_%s" % cores_capa[i], "CAPA LONGA %d" % (i + 1), "CAPA", Combate.ROUPAS))
		for i in 5:
			_roupas.append(_novo("capam_%s" % cores_capa[i], "CAPA CURTA %d" % (i + 1), "CAPA", Combate.ROUPAS))
		_roupas.append(_novo("armadura_teste", "PEITORAL E BOTAS (TESTE)", "ARMADURA", {}))
		_roupas.append(_novo("armadura_cavaleiro", "CAVALEIRO DE ACO", "ARMADURA", {}))
		_roupas.append(_novo("armadura_cavaleiro_rubro", "CAVALEIRO RUBRO (VISUAL)", "ARMADURA", {}))
		_roupas.append(_novo("traje_cavalheiro", "MORDOMO (VISUAL)", "ARMADURA", {}))
	return _roupas

static func _item(id: String, nome: String, grupo: String, legado: int) -> Dictionary:
	return {"id": id, "nome": nome, "grupo": grupo, "legado": legado, "combate": -1}

static func _novo(id: String, nome: String, grupo: String, tabela: Dictionary) -> Dictionary:
	return {"id": id, "nome": nome, "grupo": grupo, "legado": 0, "combate": int(tabela.get(id, 2))}

static func total_cabelos() -> int:
	return cabelos().size()

static func total_roupas() -> int:
	return roupas().size()

## Índice válido (peças que não existem mais, de um save antigo, caem na primeira)
static func indice_cabelo(indice: int) -> int:
	return indice if indice >= 0 and indice < total_cabelos() else 0

static func indice_roupa(indice: int) -> int:
	return indice if indice >= 0 and indice < total_roupas() else 0

static func nome_cabelo(indice: int) -> String:
	return String(cabelos()[indice_cabelo(indice)]["nome"])

static func nome_roupa(indice: int) -> String:
	return String(roupas()[indice_roupa(indice)]["nome"])

static func raiz_armadura_visual(indice: int) -> String:
	return ARMADURAS_VISUAIS.get(roupas()[indice_roupa(indice)]["id"], "")

## O elmo substitui a silhueta da cabeça; a pele antiga não exige alargar a chapa.
static func corpo(pagina: String, indice_roupa_atual: int, pecas: int, raizes: Dictionary = {}) -> Texture2D:
	var raiz := String(raizes.get("elmo", raiz_armadura_visual(indice_roupa_atual)))
	if (pecas & 1) != 0 and not raiz.is_empty():
		var caminho := raiz + "corpo_sem_cabeca/" + pagina + ".png"
		var cadastro: String = raiz + "definicao.gd"
		var mascara_ativa := false
		if ResourceLoader.exists(cadastro):
			var definicao: GDScript = load(cadastro)
			mascara_ativa = bool(definicao.get_script_constant_map().get("SUBSTITUIR_CABECA", false))
		if mascara_ativa and ResourceLoader.exists(caminho):
			return _carregar(caminho)
	return _carregar(RAIZ + PadraoArmadura.CORPOS[pagina])

## Escolhe uma peça ao acaso (botão ALEATORIO da criação de personagem)
static func cabelo_aleatorio(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, total_cabelos() - 1)

static func roupa_aleatoria(rng: RandomNumberGenerator) -> int:
	# a roupa íntima e a cueca são só a base: sorteia entre as vestidas
	var candidatos: Array[int] = []
	for i in range(2, total_roupas()):
		if roupas()[i]["grupo"] != "ARMADURA":
			candidatos.append(i)
	return candidatos[rng.randi_range(0, candidatos.size() - 1)]

# --- As texturas -----------------------------------------------------------------------------------------------

static func cabelo(indice: int, pagina: String, indice_vestimenta: int = -1, pecas: int = -1, raizes: Dictionary = {}) -> Texture2D:
	if pecas < 0:
		pecas = 15 if indice_vestimenta >= 0 and not raiz_armadura_visual(indice_vestimenta).is_empty() else 0
	if (pecas & PECAS_CAVALEIRO["elmo"]) != 0:
		var raiz := String(raizes.get("elmo", raiz_armadura_visual(indice_vestimenta) if indice_vestimenta >= 0 else ""))
		if not raiz.is_empty() and ResourceLoader.exists(raiz + "definicao.gd"):
			var definicao: GDScript = load(raiz + "definicao.gd")
			if definicao.get_script_constant_map().get("MODO_VISUAL", "armadura") == "tecido":
				return _cabelo_sob_cartola(indice, pagina, raiz)
		return _carregar(Carrasco.RAIZ_SPRITES + "cabelo_oculto.png")
	var item := cabelos()[indice_cabelo(indice)]
	if int(item["legado"]) > 0:
		return _carregar(_caminho_legado_cabelo(int(item["legado"]), pagina))
	if pagina in PAGINA_DO_ARQUIVO:
		return _carregar("%scabelos/%s_%s.png" % [PASTA_NOVAS, item["id"], PAGINA_DO_ARQUIVO[pagina]])
	# página de combate: a folha sintetizada para o estilo (<id>_<pagina>.png)
	return _carregar("%scabelos/%s_%s.png" % [PASTA_NOVAS, item["id"], pagina])

## Mantém o cabelo e sua cor escolhidos pelo jogador somente fora da cartola.
static func _cabelo_sob_cartola(indice: int, pagina: String, raiz: String) -> Texture2D:
	var chave := "cabelo_cartola:%s:%s:%d" % [raiz, pagina, indice]
	if _cache_cavaleiro.has(chave):
		return _cache_cavaleiro[chave]
	var imagem := cabelo(indice, pagina, -1, 0).get_image().duplicate()
	var cartola := _carregar(raiz + "elmo/" + pagina + ".png").get_image()
	for linha in 8:
		for coluna in 8:
			var origem := Vector2i(coluna * 64, linha * 64)
			var limites := limites_cabelo_cartola(cartola.get_region(Rect2i(origem, Vector2i(64, 64))))
			for y in 64:
				for x in 64:
					var ponto := origem + Vector2i(x, y)
					# Estilos volumosos também ficam dentro da copa, sem atravessar seu topo.
					if y < limites[x] or cartola.get_pixelv(ponto).a > 0.5:
						imagem.set_pixelv(ponto, Color.TRANSPARENT)
	var textura := ImageTexture.create_from_image(imagem)
	_cache_cavaleiro[chave] = textura
	return textura

## Cada coluna termina na borda real da aba, sem criar uma faixa de pele exposta.
static func limites_cabelo_cartola(cartola: Image) -> Array[int]:
	var limites: Array[int] = []
	var fundo := cartola.get_used_rect().end.y
	for x in 64:
		var limite := fundo
		for y in range(63, -1, -1):
			if cartola.get_pixel(x, y).a > 0.5:
				limite = y + 1
				break
		limites.append(limite)
	return limites

static func compor_cabelo_cartola(cabelo_textura: Texture2D, cartola_textura: Texture2D, cor: Color) -> Texture2D:
	var chave := "cabeca_cartola:%d:%d:%s" % [cabelo_textura.get_instance_id(), cartola_textura.get_instance_id(), cor.to_html()]
	if _cache_cavaleiro.has(chave):
		return _cache_cavaleiro[chave]
	var imagem: Image = cabelo_textura.get_image().duplicate()
	for y in 512:
		for x in 512:
			var pixel := imagem.get_pixel(x, y)
			if pixel.a > 0:
				imagem.set_pixel(x, y, pixel * cor)
	imagem.blend_rect(cartola_textura.get_image(), Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	var textura := ImageTexture.create_from_image(imagem)
	_cache_cavaleiro[chave] = textura
	return textura

## Camada irmã do cabelo: a cor escolhida para o cabelo não tinge a cartola.
static func aplicar_cartola(cabelo_sprite: Sprite2D, roupa_sprite: Sprite2D, pagina: String, indice: int, pecas: int, raizes: Dictionary = {}) -> void:
	if cabelo_sprite == null or roupa_sprite == null:
		return
	var pai := roupa_sprite.get_parent()
	if pai == null:
		return
	var camada = pai.get_node_or_null("CartolaSobreCabelo")
	var raiz := String(raizes.get("elmo", raiz_armadura_visual(indice)))
	var ativa := false
	if (pecas & 1) != 0 and not raiz.is_empty() and ResourceLoader.exists(raiz + "definicao.gd"):
		var definicao: GDScript = load(raiz + "definicao.gd")
		ativa = definicao.get_script_constant_map().get("MODO_VISUAL", "armadura") == "tecido"
	if not ativa:
		cabelo_sprite.self_modulate = Color.WHITE
		if camada != null:
			camada.texture = null
			camada.hide()
			camada.cabelo = null
		return
	if camada == null:
		camada = CartolaSobreCabelo.new()
		camada.name = "CartolaSobreCabelo"
		pai.add_child(camada)
	camada.cabelo = cabelo_sprite
	camada.roupa = roupa_sprite
	camada.texture = compor_cabelo_cartola(cabelo_sprite.texture, _carregar(raiz + "elmo/" + pagina + ".png"), cabelo_sprite.modulate)
	# Uma única camada desenha a cabeça vestida; a animação ainda controla o
	# sprite original, mas ele não desenha cabelo duplicado sobre o chapéu.
	cabelo_sprite.self_modulate = Color(1, 1, 1, 0)
	camada.sincronizar()

static func roupa(indice: int, pagina: String, pecas: int = -1, raizes: Dictionary = {}) -> Texture2D:
	if not raizes.is_empty():
		return compor_pecas_armadura(pagina, indice, raizes)
	var item := roupas()[indice_roupa(indice)]
	var raiz := raiz_armadura_visual(indice)
	if not raiz.is_empty():
		if pecas < 0:
			pecas = 15
		return compor_armadura(pagina, pecas & 15, 2, raiz)
	if pecas > 0:
		return _compor_cavaleiro(pagina, pecas & 15, indice_roupa(indice))
	if item["id"] == "armadura_teste":
		return _carregar("res://CharacterSprites/ArmaduraTeste/%s.png" % pagina)
	if int(item["legado"]) > 0:
		return _carregar(_caminho_legado_roupa(int(item["legado"]), pagina))
	if pagina in PAGINA_DO_ARQUIVO:
		return _carregar("%sroupas/%s_%s.png" % [PASTA_NOVAS, item["id"], PAGINA_DO_ARQUIVO[pagina]])
	# página de combate: a folha recolorida a partir do molde (<id>_<pagina>.png)
	return _carregar("%sroupas/%s_%s.png" % [PASTA_NOVAS, item["id"], pagina])

## As quatro folhas independentes podem ser combinadas sem alterar a grade da animação.
static func _compor_cavaleiro(pagina: String, pecas: int, indice_base: int = 2) -> Texture2D:
	return compor_armadura(pagina, pecas, indice_base, Carrasco.RAIZ_SPRITES)

## Mesmo encaixe para futuros sets. A raiz segue a estrutura validada pelo padrão de armaduras.
static func compor_armadura(pagina: String, pecas: int, indice_base: int, raiz: String) -> Texture2D:
	# O set completo substitui a roupa inteira, inclusive capas e mangas mais largas.
	if pecas == 15:
		return _carregar(raiz + "%s.png" % pagina)
	if pecas == 0:
		return roupa(indice_base, pagina)
	var chave := raiz + pagina + ":" + str(pecas) + ":" + str(indice_base)
	if _cache_cavaleiro.has(chave):
		return _cache_cavaleiro[chave]
	var imagem: Image = roupa(indice_base, pagina).get_image().duplicate()
	var cobertura := _cobertura_das_pecas(pagina, raiz)
	# Para peças parciais, retira a parte correspondente da roupa de baixo antes de sobrepor a chapa.
	# A cobertura inclui suas bordas externas; usar só o alfa da chapa deixava riscos de outras roupas.
	for y in imagem.get_height():
		for x in imagem.get_width():
			if (cobertura[y * imagem.get_width() + x] & pecas) != 0:
				imagem.set_pixel(x, y, Color.TRANSPARENT)
	for peca in ["peitoral", "botas", "luvas", "elmo"]:
		if (pecas & PECAS_CAVALEIRO[peca]) != 0:
			var camada := _carregar(raiz + "%s/%s.png" % [peca, pagina]).get_image()
			imagem.blend_rect(camada, Rect2i(Vector2i.ZERO, camada.get_size()), Vector2i.ZERO)
	var textura := ImageTexture.create_from_image(imagem)
	_cache_cavaleiro[chave] = textura
	return textura

## Cada entrada aponta uma peça para a pasta do seu conjunto, permitindo misturar sets.
static func compor_pecas_armadura(pagina: String, indice_base: int, raizes: Dictionary) -> Texture2D:
	if raizes.is_empty():
		return roupa(indice_base, pagina)
	var bits := 0
	var raiz_unica := ""
	var misturado := false
	var chave := "misto:" + pagina + ":" + str(indice_base)
	for peca in ["peitoral", "botas", "luvas", "elmo"]:
		if not raizes.has(peca):
			continue
		var raiz: String = raizes[peca]
		bits |= int(PECAS_CAVALEIRO[peca])
		chave += ":" + peca + "=" + raiz
		if raiz_unica.is_empty():
			raiz_unica = raiz
		elif raiz != raiz_unica:
			misturado = true
	if bits == 0:
		return roupa(indice_base, pagina)
	if not misturado:
		return compor_armadura(pagina, bits, indice_base, raiz_unica)
	if _cache_cavaleiro.has(chave):
		return _cache_cavaleiro[chave]
	var imagem: Image = Image.create(512, 512, false, Image.FORMAT_RGBA8) if bits == 15 else roupa(indice_base, pagina).get_image().duplicate()
	# Limpa a roupa original antes de desenhar qualquer peça.
	for peca in ["peitoral", "botas", "luvas", "elmo"]:
		if not raizes.has(peca):
			continue
		var cobertura := _cobertura_das_pecas(pagina, raizes[peca])
		for y in 512:
			for x in 512:
				if cobertura[y * 512 + x] == PECAS_CAVALEIRO[peca]:
					imagem.set_pixel(x, y, Color.TRANSPARENT)
	for peca in ["peitoral", "botas", "luvas", "elmo"]:
		if raizes.has(peca):
			var camada := _carregar(raizes[peca] + "%s/%s.png" % [peca, pagina]).get_image()
			imagem.blend_rect(camada, Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	var textura := ImageTexture.create_from_image(imagem)
	_cache_cavaleiro[chave] = textura
	return textura

## A peça mais próxima de cada pixel da pose define qual região da roupa ela substitui.
## O cálculo fica limitado à célula 64x64, para um quadro nunca apagar o vizinho.
static func _cobertura_das_pecas(pagina: String, raiz: String = Carrasco.RAIZ_SPRITES) -> PackedByteArray:
	var chave := raiz + pagina
	if _cobertura_cavaleiro.has(chave):
		return _cobertura_cavaleiro[chave]
	var camadas := {}
	for peca in PECAS_CAVALEIRO:
		camadas[PECAS_CAVALEIRO[peca]] = _carregar(raiz + "%s/%s.png" % [peca, pagina]).get_image()
	var cobertura := PackedByteArray()
	cobertura.resize(512 * 512)
	for linha in 8:
		for coluna in 8:
			var donos := PackedByteArray()
			donos.resize(4096)
			var distancias := PackedInt32Array()
			distancias.resize(4096)
			distancias.fill(1024)
			for y in 64:
				for x in 64:
					var i := y * 64 + x
					for bit in camadas:
						if camadas[bit].get_pixel(coluna * 64 + x, linha * 64 + y).a > 0.5:
							donos[i] = bit
							distancias[i] = 0
			# Transformada de distância Manhattan: duas passagens preservam o dono mais próximo.
			for y in 64:
				for x in 64:
					var i := y * 64 + x
					if x > 0 and distancias[i - 1] + 1 < distancias[i]:
						distancias[i] = distancias[i - 1] + 1
						donos[i] = donos[i - 1]
					if y > 0 and distancias[i - 64] + 1 < distancias[i]:
						distancias[i] = distancias[i - 64] + 1
						donos[i] = donos[i - 64]
			for y in range(63, -1, -1):
				for x in range(63, -1, -1):
					var i := y * 64 + x
					if x < 63 and distancias[i + 1] + 1 < distancias[i]:
						distancias[i] = distancias[i + 1] + 1
						donos[i] = donos[i + 1]
					if y < 63 and distancias[i + 64] + 1 < distancias[i]:
						distancias[i] = distancias[i + 64] + 1
						donos[i] = donos[i + 64]
					cobertura[(linha * 64 + y) * 512 + coluna * 64 + x] = donos[i]
	_cobertura_cavaleiro[chave] = cobertura
	return cobertura

static func _carregar(caminho: String) -> Texture2D:
	return load(caminho) as Texture2D

# Pastas de sempre (n = número 1-based nos nomes dos arquivos)
static func _caminho_legado_cabelo(n: int, pagina: String) -> String:
	match pagina:
		"andar":
			return RAIZ + "Hair/hair (%d).png" % n
		"fazenda":
			return RAIZ + "Fazenda/cabelo_%d.png" % n
		"forja", "sentado":
			return RAIZ + "body_smithing/Hair/hair (%d).png" % n
		"espada":
			return RAIZ + "Hair/Attack/slash_1_sword/hair (%d).png" % n
		"lanca":
			return RAIZ + "Hair/Attack/slash_1_spear/hair (%d).png" % n
		"reacao_um_mao":
			return RAIZ + "Reacao/um_mao/cabelo_%d.png" % n
		"reacao_lanca":
			return RAIZ + "Reacao/lanca/cabelo_%d.png" % n
		"reacao_arco":
			return RAIZ + "Reacao/arco/cabelo_%d.png" % n
		"arco_p2":
			return RAIZ + "Arco/cabelo_%d_p2.png" % n
		"arco_p3":
			return RAIZ + "Arco/cabelo_%d_p3.png" % n
	push_error("Aparencia: página de cabelo desconhecida: " + pagina)
	return ""

static func _caminho_legado_roupa(n: int, pagina: String) -> String:
	# Nas pastas dos golpes e da forja os arquivos 1 e 2 estão trocados em relação às outras (1 = cueca, 2 = roupa íntima)
	var invertido := n
	if n == 1:
		invertido = 2
	elif n == 2:
		invertido = 1
	match pagina:
		"andar":
			return RAIZ + "Outfit/outfit (%d).png" % n
		"fazenda":
			return RAIZ + "Fazenda/roupa_%d.png" % n
		"forja":
			return RAIZ + "body_smithing/Outfit/outfit (%d).png" % invertido
		"sentado":
			return RAIZ + "Sentado/roupa_%d.png" % n
		"espada":
			return RAIZ + "Outfit/Attack/slash_1_sword/outfit(%d).png" % invertido
		"lanca":
			return RAIZ + "Outfit/Attack/slash_1_spear/outfit (%d).png" % invertido
		"reacao_um_mao":
			return RAIZ + "Reacao/um_mao/roupa_%d.png" % n
		"reacao_lanca":
			return RAIZ + "Reacao/lanca/roupa_%d.png" % n
		"reacao_arco":
			return RAIZ + "Reacao/arco/roupa_%d.png" % n
		"arco_p2":
			return RAIZ + "Arco/roupa_%d_p2.png" % n
		"arco_p3":
			return RAIZ + "Arco/roupa_%d_p3.png" % n
	push_error("Aparencia: página de roupa desconhecida: " + pagina)
	return ""
