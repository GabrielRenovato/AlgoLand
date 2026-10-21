extends RefCounted
## Compatibilidade dos índices salvos; toda textura vem do corpo e das camadas Raven.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const PECAS_CAVALEIRO := {"elmo":1,"peitoral":2,"luvas":4,"botas":8}
const ARMADURAS_VISUAIS := {
	"armadura_cavaleiro":"res://assets/personagens/conjuntos/carrasco/",
	"armadura_cavaleiro_rubro":"res://assets/personagens/conjuntos/cavaleiro_rubro/",
	"traje_cavalheiro":"res://assets/personagens/conjuntos/cavalheiro/"}
static var _cache_cavaleiro := {}
static var _cache := {}

static func cabelos() -> Array[Dictionary]: return Raven.cabelos()
static func roupas() -> Array[Dictionary]:
	var resultado := Raven.roupas()
	# Índices dos três visuais de conjuntos são preservados para partidas antigas.
	while resultado.size() < 43:
		var i := resultado.size()
		resultado.append({"id":"roupa_%d" % (1+i%8),"nome":Raven.nome_roupa(1+i%8),"grupo":"RAVEN"})
	for id in ARMADURAS_VISUAIS:
		resultado.append({"id":id,"nome":id.to_upper().replace("_"," "),"grupo":"ARMADURA"})
	return resultado
static func total_cabelos() -> int: return cabelos().size()
static func total_roupas() -> int: return roupas().size()
static func indice_cabelo(i: int) -> int: return clampi(i,0,28)
static func indice_roupa(i: int) -> int: return clampi(i,0,total_roupas()-1)
static func roupa_completa(i: int) -> bool: return i>=0 and i<total_roupas()
static func nome_cabelo(i: int) -> String: return Raven.nome_cabelo(i)
static func nome_roupa(i: int) -> String: return roupas()[indice_roupa(i)].nome
static func cabelo_aleatorio(rng: RandomNumberGenerator) -> int: return rng.randi_range(0,28)
static func roupa_aleatoria(rng: RandomNumberGenerator) -> int: return rng.randi_range(1,8)
static func raiz_armadura_visual(i: int) -> String: return ARMADURAS_VISUAIS.get(roupas()[indice_roupa(i)].id,"")
static func material_corpo() -> Material: return Raven.material_corpo()
static func caminho_corpo_nativo(pagina: String) -> String: return Raven.RAIZ+"paginas/corpo_0/"+pagina+".png"
static func corpo(pagina: String, _roupa: int=0, _pecas: int=0, _raizes: Dictionary={}) -> Texture2D:
	return Raven.carregar(caminho_corpo_nativo(pagina))
static func cabelo(i: int, pagina: String, _roupa: int=-1, pecas: int=-1, raizes: Dictionary={}) -> Texture2D:
	if pecas&1 and not raizes.get("elmo","").is_empty(): i=0
	return Raven.carregar(Raven.RAIZ+"paginas/"+("vazio" if i==0 else "cabelo_%d" % indice_cabelo(i))+"/"+pagina+".png")
static func cabelo_refinado(i: int, pagina: String, roupa_atual: int=-1, pecas: int=-1, raizes: Dictionary={}) -> Texture2D:
	return cabelo(i,pagina,roupa_atual,pecas,raizes)
static func roupa(i: int, pagina: String, _pecas: int=-1, _raizes: Dictionary={}) -> Texture2D:
	return roupa_refinada(i,pagina)
static func roupa_refinada(i: int, pagina: String, _pecas: int=-1, _raizes: Dictionary={}) -> Texture2D:
	var roupa_raven := i if i<=8 else 1+i%8
	var chave := "%d:%s" % [roupa_raven,pagina]
	if not _cache.has(chave):
		var imagem := Image.create(512,512,false,Image.FORMAT_RGBA8)
		for peca in Raven.pecas_roupa(roupa_raven):
			var tex := Raven.carregar(Raven.RAIZ+"paginas/"+peca+"/"+pagina+".png")
			imagem.blend_rect(tex.get_image(),Rect2i(0,0,512,512),Vector2i.ZERO)
		_cache[chave] = ImageTexture.create_from_image(imagem)
	return _cache[chave]
static func aplicar_corpo(sprite: Sprite2D,pagina: String,roupa_atual: int,pecas: int,raizes: Dictionary={}) -> void:
	sprite.texture=corpo(pagina,roupa_atual,pecas,raizes)
	sprite.scale=Vector2.ONE
	sprite.material=material_corpo()
static func aplicar_cabelo(sprite: Sprite2D,i: int,pagina: String,roupa_atual: int,pecas: int=-1,raizes: Dictionary={}) -> void:
	sprite.texture=cabelo(i,pagina,roupa_atual,pecas,raizes)
	sprite.scale=Vector2.ONE
	sprite.material=Raven.material_cabelo()
static func aplicar_roupa(sprite: Sprite2D,i: int,pagina: String,pecas: int=-1,raizes: Dictionary={}) -> void:
	sprite.texture=roupa_refinada(i,pagina,pecas,raizes)
	sprite.scale=Vector2.ONE
	sprite.material=material_corpo()
static func aplicar_cartola(_cabelo: Sprite2D,_roupa: Sprite2D,_pagina: String,_indice: int,_pecas: int,_raizes: Dictionary={}) -> void:
	pass
static func peca_refinada(raiz: String,peca: String,pagina: String) -> Texture2D:
	return Raven.carregar(raiz+peca+"/"+pagina+".png")

static func calcular_cobertura(pagina: String, raiz: String) -> PackedByteArray:
	# Lê os bytes RGBA das camadas de uma vez (get_pixel por pixel era o gargalo ao equipar a primeira vez)
	var camadas := {}
	for peca in PECAS_CAVALEIRO:
		var imagem: Image = Raven.carregar(raiz + "%s/%s.png" % [peca, pagina]).get_image()
		if imagem.get_format() != Image.FORMAT_RGBA8:
			imagem.convert(Image.FORMAT_RGBA8)
		camadas[PECAS_CAVALEIRO[peca]] = imagem.get_data()
	var cobertura := PackedByteArray()
	cobertura.resize(512 * 512)
	var donos := PackedByteArray()
	donos.resize(4096)
	var distancias := PackedInt32Array()
	distancias.resize(4096)
	for linha in 8:
		for coluna in 8:
			donos.fill(0)
			distancias.fill(1024)
			var tem_chapa := false
			for y in 64:
				var base_linha := ((linha * 64 + y) * 512 + coluna * 64) * 4 + 3
				for x in 64:
					for bit in camadas:
						if camadas[bit][base_linha + x * 4] > 127:
							donos[y * 64 + x] = bit
							distancias[y * 64 + x] = 0
							tem_chapa = true
			# Célula sem nenhuma chapa: ninguém é dono de nada (o resultado seria todo zero)
			if not tem_chapa:
				continue
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
	return cobertura


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
