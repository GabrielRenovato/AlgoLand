extends "res://codigo/campanha/clareiras_chegada.gd"

## Estrada de abastecimento: pavimento antigo, carreto atacado e fuga até o abrigo.
## Reutiliza somente a montagem modular, peças sazonais e profundidade da clareira.
const PROJETO_ESTRADA := preload("res://codigo/campanha/estrada_carreteiros.json")
const SOLO_ESTRADA := preload("res://codigo/campanha/estrada_solo.gdshader")
var roteiro: Node

func _ready() -> void:
	regiao = "estrada"
	dados = PROJETO_ESTRADA.data.duplicate(true)
	limites = Rect2(-1024,-640,2048,1280)
	margem_obstaculos_navegacao = 0.0
	raio_agente_navegacao = 6.0
	_fichas = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_PECAS))
	var adicionais: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/campanha/estrada_carreteiros/pecas.json"))
	_fichas.merge(adicionais)
	_estacoes = preload("res://codigo/campanha/estacoes_campanha.gd").new()
	_estacoes.name = "Estacoes"
	add_child(_estacoes)
	_montar_tiles()
	_bordas()
	_montar_marcos()
	_montar_floresta()
	_montar_navegacao()
	definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)
	_montar_grama_3d()
	_integrar_percurso.call_deferred()

func _integrar_percurso() -> void:
	if not get_parent().has_method("equipamentos_encontrados"): return
	roteiro = preload("res://codigo/campanha/encontro_estrada.gd").new()
	roteiro.name = "RoteiroEstrada"
	roteiro.terreno = self
	add_child(roteiro)

func _tipo_base(canto: Vector2i) -> int:
	var p := Vector2(canto*16)
	# Ilhas de calçamento quebrado, com os mesmos cantos de transição do solo.
	for i in dados.rota_principal.size()-1:
		var a := _ponto(dados.rota_principal[i])
		var b := _ponto(dados.rota_principal[i+1])
		var proximo := Geometry2D.get_closest_point_to_segment(p,a,b)
		if p.distance_to(proximo)<19 and sin(p.x*.021+p.y*.034)>.12: return PEDRA
	for trecho in dados.trilhas:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_ponto(trecho[0]),_ponto(trecho[1])))<float(trecho[2]): return TERRA
	for clareira in dados.clareiras:
		if ((p-_ponto(clareira[0]))/_ponto(clareira[1])).length_squared()<1: return TERRA
	return GRAMA

func _montar_tiles() -> void:
	chao = TileMapLayer.new()
	chao.name = "Chao"
	chao.z_index = Profundidade.Z_CHAO
	chao.scale = Vector2.ONE/4
	chao.tile_set = load(RAIZ+"tileset.tres").duplicate(true)
	_atlas = chao.tile_set.get_source(0)
	_material = ShaderMaterial.new()
	_material.shader = SOLO_ESTRADA
	_material.set_shader_parameter("origem",limites.position)
	_material.set_shader_parameter("tamanho",limites.size)
	var vazio := Image.create(2,2,false,Image.FORMAT_L8)
	vazio.fill(Color.BLACK)
	_material.set_shader_parameter("mapa_raizes",ImageTexture.create_from_image(vazio))
	_material.set_shader_parameter("marcas_estrada",_marcas_da_viagem())
	chao.material = _material
	chao.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(chao)
	for y in range(-40,40):
		for x in range(-64,64): _atualizar_tile(Vector2i(x,y))

func _marcas_da_viagem() -> ImageTexture:
	# Máscara de sulcos; a textura de terra continua compartilhada e independente.
	var mascara := Image.create(512,320,false,Image.FORMAT_L8)
	for y in 320:
		for x in 512:
			var p := limites.position+Vector2(x*4+2,y*4+2)
			var valor := 0.0
			for i in dados.rota_principal.size()-1:
				var a := _ponto(dados.rota_principal[i])
				var b := _ponto(dados.rota_principal[i+1])
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				valor=maxf(valor,(1.0-smoothstep(1.5,4.5,absf(d-17.0)))*.7)
			for i in dados.rota_refugio.size()-1:
				var a := _ponto(dados.rota_refugio[i])
				var b := _ponto(dados.rota_refugio[i+1])
				var perto := Geometry2D.get_closest_point_to_segment(p,a,b)
				# Passos alternados; não é uma linha sólida apontando para o NPC.
				var passo := fposmod((perto-a).length(),18.0)
				if passo<6 and p.distance_to(perto)<3: valor=maxf(valor,.9)
			mascara.set_pixel(x,y,Color(valor,valor,valor))
	return ImageTexture.create_from_image(mascara)

func _no_mundo(id: String, tipo: String, p: Vector2, largura: float, base: Vector2) -> void:
	_objeto(id,tipo,p-limites.position,largura,base)

func _montar_marcos() -> void:
	_no_mundo("carreto_atacado","carreto",Vector2(-300,-35),112,Vector2(76,30))
	_no_mundo("carga_caida","suprimentos",Vector2(-365,28),46,Vector2(30,12))
	_no_mundo("carga_resgatada","suprimentos",Vector2(193,330),36,Vector2(24,10))
	_no_mundo("abrigo_trabalhador","abrigo",Vector2(135,313),148,Vector2.ZERO)
	# Colisões nos apoios traseiros; frente aberta e ponto de conversa acessível.
	for deslocamento in [Vector2(-52,-17),Vector2(52,-17)]:
		var ret := Rect2(Vector2(135,313)+deslocamento-Vector2(6,7),Vector2(12,14))
		_colisao(ret)
		_pecas.abrigo_trabalhador.colisoes.append({"ret":ret,"corpo":get_child(-1)})
	_no_mundo("tronco_fuga","tronco",Vector2(-45,300),88,Vector2(66,12))
	_no_mundo("marco_entrada","pilar",Vector2(-875,365),30,Vector2(16,12))
	_no_mundo("marco_vila","poste_resgate",Vector2(775,-411),38,Vector2(12,9))
	_no_mundo("pedras_curva","pedras",Vector2(-630,230),68,Vector2(40,18))
	_no_mundo("pedras_refugio","pedras",Vector2(245,390),65,Vector2(42,19))
	_no_mundo("pedras_saida","pedras",Vector2(570,-100),76,Vector2(46,22))
	# Restos do antigo acostamento: acompanham a estrada, sem fechar o corredor.
	for i in 5:
		_no_mundo("mureta_"+str(i),"muro",Vector2(-180+i*64,-115),64,Vector2(57,12))
	for inicio in [Vector2(-760,455),Vector2(600,-190)]:
		for i in 8:
			if i==4:continue # Trecho quebrado com abertura real.
			var p: Vector2 = inicio+Vector2(i*16,0)
			_peca_cerca(p,"horizontal")
			_colisao(Rect2(p-Vector2(8,4),Vector2(16,4)))
		for i in [0,3,5,8]:_peca_cerca(inicio+Vector2(i*16-8,0),"poste")

func _montar_floresta() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 814207
	var pontos: Array[Vector2] = []
	for tentativa in 4500:
		if pontos.size()>=255: break
		var p := Vector2(rng.randf_range(-995,995),rng.randf_range(-575,655))
		if _tipo_base(Vector2i((p/16).floor()))!=GRAMA: continue
		if pontos.any(func(outro):return outro.distance_to(p)<65): continue
		var perto := false
		for trecho in dados.trilhas:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_ponto(trecho[0]),_ponto(trecho[1])))<float(trecho[2])+38: perto=true
		for registro in _pecas.values():
			if registro.tipo in ["carvalho","jovem","pinheiro"]: continue
			if p.distance_to(registro.ponto)<maxf(85,registro.largura*.7): perto=true
		if p.distance_to(_ponto(dados.entrada))<105: perto=true
		if perto:continue
		pontos.append(p)
		var tipo := "pinheiro" if rng.randf()<.27 else ("jovem" if rng.randf()<.2 else "carvalho")
		_no_mundo("arvore_"+str(pontos.size()),tipo,p,rng.randf_range(95,132),Vector2(18,14))
	for i in 110:
		var p := Vector2(rng.randf_range(-1000,1000),rng.randf_range(-590,625))
		if _tipo_base(Vector2i((p/16).floor()))!=GRAMA:continue
		var perto := false
		for alvo in dados.alvos.values():
			if p.distance_to(_ponto(alvo.p))<80: perto=true
		if not perto:_no_mundo("arbusto_"+str(i),"arbustos",p,rng.randf_range(30,48),Vector2.ZERO)

func definir_estacao(indice: int) -> void:
	super(indice)
	# Cercas usam o mesmo catálogo sazonal da cidade, fora do atlas de objetos.
	for item in _sazonais: item.sprite.texture=load(item.texturas[estacao_atual])

func _colisoes_agua() -> void:
	# Não há rio neste trecho: água não deve ser acrescentada sem pontes e atlas.
	pass

func alterar_terreno(celula: Vector2i, tipo: int) -> Error:
	if tipo==AGUA:return ERR_UNAVAILABLE
	return super(celula,tipo)
