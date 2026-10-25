extends RefCounted
## Catálogo único do personagem Raven: camadas, ações e prévias.
const RAIZ := "res://assets/personagens/raven_fantasy/"
const PaletaRaven := preload("res://codigo/dados/paleta_raven.gd")
const ACOES_FAZENDA := ["plantar","colher"]
const Corrida := preload("res://codigo/dados/corrida_raven.gd")
const PECAS := ["calca_marrom","calca_jeans","camisa_azul","camisa_verde","botas","luvas","capa"]
static var _cache: Dictionary = {}
static var _acoes: Array = []

static func carregar(caminho: String) -> Texture2D:
	if not _cache.has(caminho): _cache[caminho] = load(caminho)
	return _cache[caminho]

static func cabelos() -> Array[Dictionary]:
	var itens: Array[Dictionary] = [{"id":"sem_cabelo","nome":"SEM CABELO","grupo":"RAVEN"}]
	for i in 28: itens.append({"id":"cabelo_%d" % (i+1),"nome":"CABELO %02d" % (i+1),"grupo":"RAVEN"})
	return itens

static func roupas() -> Array[Dictionary]:
	var itens: Array[Dictionary] = [{"id":"base","nome":"CORPO BASE","grupo":"RAVEN"}]
	for capa in 2:
		for jeans in 2:
			for verde in 2:
				itens.append({"id":"roupa_%d" % itens.size(),"nome":("VERDE" if verde else "AZUL")+" / "+("JEANS" if jeans else "MARROM")+(" / CAPA" if capa else ""),"grupo":"RAVEN"})
	return itens

static func indice_cabelo(i: int) -> int: return clampi(i,0,28)
static func indice_roupa(i: int) -> int: return clampi(i,0,8)
static func roupa_completa(i: int) -> bool: return i >= 0 and i <= 8
static func nome_cabelo(i: int) -> String: return cabelos()[indice_cabelo(i)].nome
static func nome_roupa(i: int) -> String: return roupas()[indice_roupa(i)].nome
static func cabelo_aleatorio(rng: RandomNumberGenerator) -> int: return rng.randi_range(0,28)
static func roupa_aleatoria(rng: RandomNumberGenerator) -> int: return rng.randi_range(0,8)
static func material_corpo() -> ShaderMaterial:
	return _material_acabamento(false)

static func _material_acabamento(tingir: bool) -> ShaderMaterial:
	var chave := "material_cabelo" if tingir else "material_acabamento"
	if not _cache.has(chave):
		var origem := PackedColorArray()
		var destino := PackedColorArray()
		for cor: String in PaletaRaven.CORES:
			origem.append(Color.html(cor))
			destino.append(Color.html(PaletaRaven.CORES[cor]))
		var material := ShaderMaterial.new()
		material.shader = preload("res://codigo/jogador/acabamento_raven.gdshader")
		material.set_shader_parameter("cores_origem",origem)
		material.set_shader_parameter("cores_destino",destino)
		material.set_shader_parameter("quantidade_cores",origem.size())
		material.set_shader_parameter("tingir_cabelo",tingir)
		_cache[chave] = material
	return _cache[chave]

static func corpo(_pagina: String, pele: int = 0, _pecas: int = 0) -> Texture2D:
	return carregar(RAIZ+"previas/corpo_%d.png" % clampi(pele,0,2))

static func cabelo(i: int, _pagina: String, _roupa: int = 0) -> Texture2D:
	return carregar(RAIZ+"previas/"+("vazio" if i == 0 else "cabelo_%d" % indice_cabelo(i))+".png")

static func cabelo_refinado(i: int, pagina: String, vestimenta: int = 0) -> Texture2D:
	return cabelo(i,pagina,vestimenta)

static func pecas_roupa(i: int) -> Array[String]:
	if indice_roupa(i) == 0: return []
	var n := indice_roupa(i)-1
	var pecas: Array[String] = ["calca_jeans" if (n/2)%2 else "calca_marrom","camisa_verde" if n%2 else "camisa_azul","botas","luvas"]
	if n >= 4: pecas.append("capa")
	return pecas

static func roupa_refinada(i: int, _pagina: String) -> Texture2D:
	var chave := "roupa_previa_%d" % indice_roupa(i)
	if not _cache.has(chave):
		var imagem := Image.create(512,512,false,Image.FORMAT_RGBA8)
		for peca in pecas_roupa(i):
			imagem.blend_rect(carregar(RAIZ+"previas/"+peca+".png").get_image(),Rect2i(0,0,512,512),Vector2i.ZERO)
		_cache[chave] = ImageTexture.create_from_image(imagem)
	return _cache[chave]

static func folha(camada: String, acao: String) -> Texture2D:
	if acao == "correr":
		return carregar(Corrida.RAIZ+camada+".png")
	if acao in ACOES_FAZENDA:
		return carregar(RAIZ+"acoes_fazenda/"+acao+"/"+camada+".png")
	var chave := camada+":"+acao
	if not _cache.has(chave):
		if OS.has_feature("web"):
			# As folhas completas têm 9600 px; WebGL pode aceitar no máximo 8192.
			_cache[chave] = carregar(RAIZ+"web/"+camada+"/"+acao+".png")
			return _cache[chave]
		if _acoes.is_empty(): _acoes = JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"camadas/acoes.json"))
		var atlas := AtlasTexture.new()
		atlas.atlas = carregar(RAIZ+"camadas/"+camada+".png")
		atlas.region = Rect2(0,maxi(0,_acoes.find(acao))*320,320,320)
		atlas.filter_clip = true
		_cache[chave] = atlas
	return _cache[chave]

## Os elmos fechados substituem a cabeça original. O rosto e seu preenchimento
## no peitoral não podem formar riscos nas laterais da chapa aprovada.
static func corpo_com_elmo(pele: int, acao: String, id_elmo: String) -> Texture2D:
	var camada := "corpo_%d" % pele
	if acao!="correr" or id_elmo not in Corrida.ELMOS_RECOLHIDOS:
		return folha(camada,acao)
	var chave := "corpo_elmo_recolhido:"+camada+":"+id_elmo
	if not _cache.has(chave):
		_cache[chave] = _ocultar_cabecas_corrida(folha(camada,acao))
	return _cache[chave]

static func peitoral_com_elmo(caminho: String, acao: String, id_elmo: String) -> Texture2D:
	var fonte := folha_arquivo(caminho,acao)
	if acao!="correr" or id_elmo not in Corrida.ELMOS_RECOLHIDOS:
		return fonte
	var chave := "peitoral_elmo_recolhido:"+caminho
	if not _cache.has(chave):_cache[chave] = _ocultar_cabecas_corrida(fonte)
	return _cache[chave]

static func luvas_com_elmo(caminho: String, acao: String, id_elmo: String) -> Texture2D:
	var fonte := folha_arquivo(caminho,acao)
	if acao!="correr" or id_elmo not in Corrida.ELMOS_RECOLHIDOS:
		return fonte
	var chave := "luvas_elmo_encaixado:"+caminho
	if not _cache.has(chave):_cache[chave] = _ocultar_cabecas_corrida(fonte,false)
	return _cache[chave]

static func _ocultar_cabecas_corrida(fonte: Texture2D, incluir_frente: bool=true) -> Texture2D:
	var imagem := fonte.get_image()
	for q in Corrida.QUADROS:
		if incluir_frente:imagem.fill_rect(Rect2i(q*80,0,80,Corrida.GOLAS_FRENTE[q]),Color.TRANSPARENT)
		# A nuca antiga ocupa 12 px; fora dela há mãos erguidas. Preservar
		# esses pixels em vez de apagar a faixa inteira acima da gola.
		var esquerda: int = q*80+Corrida.CENTROS_CABECA_COSTAS[q]-6
		imagem.fill_rect(Rect2i(esquerda,160,12,Corrida.GOLAS_FRENTE[q]),Color.TRANSPARENT)
	return ImageTexture.create_from_image(imagem)

static func aplicar_roupa(sprite: Sprite2D, i: int, pagina: String) -> void:
	sprite.texture = roupa_refinada(i,pagina)
	sprite.material = material_corpo()
	sprite.scale = Vector2.ONE

static func aplicar_cabelo(sprite: Sprite2D, i: int, pagina: String, vestimenta: int) -> void:
	sprite.texture = cabelo(i,pagina,vestimenta)
	sprite.material = material_cabelo()
	sprite.scale = Vector2.ONE

static func material_cabelo() -> ShaderMaterial:
	return _material_acabamento(true)

static func material_pose(tingir: bool, sentado: bool, direcao: int, acabamento: bool=true, sem_rastro_pesca: bool=false) -> ShaderMaterial:
	var chave := "pose:%s:%s:%d:%s:%s" % [tingir,sentado,direcao,acabamento,sem_rastro_pesca]
	if not _cache.has(chave):
		var mat: ShaderMaterial = _material_acabamento(tingir).duplicate()
		mat.set_shader_parameter("sentado",sentado)
		mat.set_shader_parameter("direcao_sentado",direcao)
		mat.set_shader_parameter("sem_rastro_pesca",sem_rastro_pesca)
		if not acabamento: mat.set_shader_parameter("quantidade_cores",0)
		_cache[chave] = mat
	return _cache[chave]

static func folha_arquivo(caminho: String, acao: String) -> Texture2D:
	if acao in ACOES_FAZENDA or acao == "correr":
		return carregar(caminho.get_basename()+"/"+acao+".png")
	var chave := caminho+":"+acao
	if not _cache.has(chave):
		if OS.has_feature("web"):
			_cache[chave] = carregar(caminho.get_basename()+"/"+acao+".png")
			return _cache[chave]
		if _acoes.is_empty(): _acoes = JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"camadas/acoes.json"))
		var atlas := AtlasTexture.new()
		atlas.atlas = carregar(caminho)
		atlas.region = Rect2(0,maxi(0,_acoes.find(acao))*320,320,320)
		atlas.filter_clip = true
		_cache[chave] = atlas
	return _cache[chave]
