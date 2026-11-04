extends "res://codigo/campanha/terreno_campanha.gd"

## Terreno editável por cantos de 16px e peças físicas independentes.
## Nenhuma imagem do mapa completo participa da renderização.
signal objeto_removido(id: String)
signal terreno_alterado(celula: Vector2i, tipo: int)
signal abertura_bau_concluida
enum EstadoBau { FECHADO, ABRINDO, ABERTO }
var estado_bau := EstadoBau.FECHADO
var quadro_bau := 0
var _tempo_bau := 0.0
var _ficha_bau: Dictionary
const RAIZ := "res://assets/cenario/campanha/clareiras_modulares/"
const BAU_ANIMADO := RAIZ+"bau_animado.json"
const CAMINHO_PECAS := RAIZ+"pecas.json"
const MATERIAL_TERRENO := preload("res://codigo/campanha/terreno_modular.gdshader")
const GRAMA := 0
const TERRA := 1
const PEDRA := 2
const AGUA := 3
var _fichas: Dictionary
var _pecas: Dictionary = {}
var _cantos: Dictionary = {}
var _tipos_base: Dictionary = {}
var _corpos_agua: Array[Dictionary] = []
var _material: ShaderMaterial
var _atlas: TileSetAtlasSource
var modo_modular := true
var _grama_3d: Node2D
const PaletaAgua := preload("res://codigo/campanha/paleta_agua.gd")
var _tempo_rio := 0.0

func _ready() -> void:
	margem_obstaculos_navegacao = 0.0
	raio_agente_navegacao = 6.0
	dados = LAYOUT.data[regiao].duplicate(true)
	limites = Rect2(Vector2(-768,-512),Vector2(1536,1024))
	_fichas = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_PECAS))
	_ficha_bau = JSON.parse_string(FileAccess.get_file_as_string(BAU_ANIMADO))
	_estacoes = preload("res://codigo/campanha/estacoes_campanha.gd").new()
	_estacoes.name = "Estacoes"
	add_child(_estacoes)
	_montar_tiles()
	_bordas()
	_colisoes_agua()
	_montar_marcos()
	_montar_floresta()
	_montar_navegacao()
	definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)
	_montar_grama_3d()

## A água do estágio 1 é a mesma do moinho: leito de pedras e estrias que seguem o sentido do rio.
func _preparar_rio_moinho() -> void:
	var campo := Image.create(192,128,false,Image.FORMAT_RGBA8)
	for y in 128:
		for x in 192:
			var p := limites.position+Vector2(x*8+4,y*8+4)
			var direcao := Vector2.ZERO
			var profundidade := 0.0
			for trecho in dados.rios:
				var a := _da_imagem(_ponto(trecho[0]))
				var b := _da_imagem(_ponto(trecho[1]))
				var raio := float(trecho[2])
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				direcao += (b-a).normalized()*pow(maxf(1.0-d/(raio+16.0),0.0),3.0)
				profundidade = maxf(profundidade,1.0-d/raio)
			if direcao.length_squared() < 0.001: direcao = Vector2.RIGHT
			direcao = direcao.normalized()
			campo.set_pixel(x,y,Color(direcao.x*0.5+0.5,direcao.y*0.5+0.5,clampf(profundidade,0.0,1.0),1.0))
	_material.set_shader_parameter("rio_do_moinho",true)
	_material.set_shader_parameter("campo_corrente",ImageTexture.create_from_image(campo))
	_material.set_shader_parameter("agua_tons",PaletaAgua.TONS[clampi(Calendario.estacao(),0,3)])

func _montar_grama_3d() -> void:
	if is_instance_valid(_grama_3d): return
	var grama := preload("res://codigo/cenario/grama_3d_no_mapa.gd").new()
	grama.name = "Grama3D"
	grama.terreno = self
	grama.consultar_grama = func(p: Vector2) -> float:
		return grama.peso_modular(p,_tipo_canto)
	add_child(grama)
	_grama_3d = grama
	grama.definir_estacao(estacao_atual)
	for registro in _pecas.values():
		if registro.tipo in ["carvalho","jovem","pinheiro","arbustos"]:
			grama._montar_frente_base(registro)

func _da_imagem(p: Vector2) -> Vector2:
	return p+limites.position

func _tipo_canto(canto: Vector2i) -> int:
	if _cantos.has(canto): return int(_cantos[canto])
	if not _tipos_base.has(canto): _tipos_base[canto] = _tipo_base(canto)
	return int(_tipos_base[canto])

func _tipo_base(canto: Vector2i) -> int:
	var p := Vector2(canto*16)
	for trecho in dados.rios:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_da_imagem(_ponto(trecho[0])),_da_imagem(_ponto(trecho[1]))))<float(trecho[2]): return AGUA
	if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_da_imagem(Vector2(1280,330)),_da_imagem(Vector2(1536,20))))<48: return PEDRA
	for trecho in dados.trilhas:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_ponto(trecho[0]),_ponto(trecho[1])))<float(trecho[2]): return TERRA
	for clareira in dados.clareiras:
		if ((p-_ponto(clareira[0]))/_ponto(clareira[1])).length_squared()<1: return TERRA
	return GRAMA

func _atualizar_tile(celula: Vector2i) -> void:
	var indice := _tipo_canto(celula)+(_tipo_canto(celula+Vector2i.RIGHT)<<2)+(_tipo_canto(celula+Vector2i.DOWN)<<4)+(_tipo_canto(celula+Vector2i.ONE)<<6)
	chao.set_cell(celula,0,Vector2i(indice%16,indice/16))

func _montar_tiles() -> void:
	chao = TileMapLayer.new()
	chao.name = "Chao"
	chao.z_index = Profundidade.Z_CHAO
	chao.scale = Vector2.ONE/4
	chao.tile_set = load(RAIZ+"tileset.tres").duplicate(true)
	_atlas = chao.tile_set.get_source(0)
	_material = ShaderMaterial.new()
	_material.shader = MATERIAL_TERRENO
	_material.set_shader_parameter("origem",limites.position)
	_material.set_shader_parameter("tamanho",limites.size)
	_material.set_shader_parameter("mapa_raizes",_campo_raizes())
	chao.material = _material
	if regiao == "chegada": _preparar_rio_moinho()
	chao.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(chao)
	for y in range(-32,32):
		for x in range(-48,48): _atualizar_tile(Vector2i(x,y))

func _campo_raizes() -> ImageTexture:
	var imagem := Image.create(96,64,false,Image.FORMAT_L8)
	var origem := _da_imagem(Vector2(855,235))
	for y in 64:
		for x in 96:
			var p := limites.position+Vector2(x*16,y*16)
			var distancia := p.distance_to(origem)
			var trilha := p.distance_to(Geometry2D.get_closest_point_to_segment(p,origem,_da_imagem(Vector2(650,760))))
			var valor := maxf(1.0-distancia/560,0.0)*maxf(1.0-trilha/160,0.0)
			# Pistas no chão precisam existir onde a missão permite investigar.
			for id in ["sulcos_chegada","raizes_despertas"]:
				var pista := _ponto(dados.alvos[id].p)
				valor=maxf(valor,1.0-smoothstep(24.0,56.0,p.distance_to(pista)))
			imagem.set_pixel(x,y,Color(valor,valor,valor))
	return ImageTexture.create_from_image(imagem)

func _sobre_ponte(p: Vector2) -> bool:
	for ponte in dados.pontes:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,_da_imagem(_ponto(ponte[0])),_da_imagem(_ponto(ponte[1]))))<float(ponte[2]): return true
	return false

func _colisoes_agua() -> void:
	for registro in _corpos_agua:
		obstaculos.erase(registro.ret)
		if is_instance_valid(registro.corpo): registro.corpo.queue_free()
	_corpos_agua.clear()
	# A máscara visual mistura quatro cantos; amostrar a mesma mistura em 4px,
	# em vez de bloquear o tile inteiro pela classificação de apenas um canto.
	for y in range(-128,128):
		var inicio := 10000
		for x in range(-192,193):
			var p := Vector2(x*4+2,y*4+2)
			var fechado := x<192 and peso_agua(p)>=0.4 and not _sobre_ponte(p)
			if fechado and inicio==10000: inicio=x
			if not fechado and inicio!=10000:
				var ret := Rect2(inicio*4,y*4,(x-inicio)*4,4)
				_colisao(ret)
				_corpos_agua.append({"ret":ret,"corpo":get_child(-1)})
				inicio=10000

func peso_agua(p: Vector2) -> float:
	var celula := Vector2i((p/16).floor())
	var uv := p/16-Vector2(celula)
	var pesos := [(1-uv.x)*(1-uv.y),uv.x*(1-uv.y),(1-uv.x)*uv.y,uv.x*uv.y]
	var tipos := [_tipo_canto(celula),_tipo_canto(celula+Vector2i.RIGHT),_tipo_canto(celula+Vector2i.DOWN),_tipo_canto(celula+Vector2i.ONE)]
	var canais := [0.0,0.0,0.0,0.0]
	for i in 4: canais[tipos[i]]+=pesos[i]
	var total := 0.0
	for i in 4:
		canais[i]=pow(maxf(canais[i]-.18,0),2)
		total+=canais[i]
	return canais[AGUA]/maxf(total,.001)

func _objeto(id: String, tipo: String, posicao_imagem: Vector2, largura: float, base: Vector2, ponte := false) -> void:
	var ponto := _da_imagem(posicao_imagem)
	var sprite := Sprite2D.new()
	sprite.name = id
	sprite.position = ponto
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_as_relative = false
	var recuo := -8.0 if tipo in ["carvalho","jovem","pinheiro","pedras"] else 0.0
	# Flores e pedras soltas abaixo do painel não são a linha dos pilares.
	if tipo=="estela": recuo=-20.0
	sprite.z_index = Profundidade.Z_CHAO+2 if ponte else Profundidade.z_de(ponto.y+recuo)
	add_child(sprite)
	var registro := {"id":id,"tipo":tipo,"sprite":sprite,"largura":largura,"ponto":ponto,"colisoes":[],"ponte":ponte}
	if base.length_squared()>0:
		var ret := Rect2(ponto-Vector2(base.x/2,base.y),base)
		_colisao(ret)
		registro.colisoes.append({"ret":ret,"corpo":get_child(-1)})
	_pecas[id] = registro

func _montar_marcos() -> void:
	_objeto("poste_resgate","poste_resgate",Vector2(310,820),42,Vector2(12,9))
	_objeto("bau_resgate","bau_resgate",Vector2(390,820),50,Vector2(46,28))
	_objeto("arco_estrada","arco",Vector2(1375,236),156,Vector2.ZERO)
	# A estrada sobe para nordeste: o plano do arco cruza a outra diagonal.
	_pecas.arco_estrada["espelhado"] = true
	for base in [Vector2(-44,-27),Vector2(43,-11)]:
		var p := _da_imagem(Vector2(1375,236)+base)
		var ret := Rect2(p-Vector2(13,8),Vector2(26,16))
		_colisao(ret)
		_pecas.arco_estrada.colisoes.append({"ret":ret,"corpo":get_child(-1)})
	for i in 3:
		_objeto("muro_alcova_"+str(i),"muro",Vector2(100+i*62,235),68,Vector2(62,15))
	for par in [["pilar_alcova",Vector2(80,300)],["marco_saida",Vector2(1290,250)]]:
		_objeto(par[0],"pilar",par[1],36,Vector2(20,15))
	_objeto("ponte_tronco","ponte",Vector2(282,530),120,Vector2.ZERO,true)
	_objeto("painel_ruinas","estela",Vector2(155,280),85,Vector2(68,19))
	# Bases escalonadas da parede e dos pilares; o sprite alto não vira um muro invisível.
	for base in [Rect2(-28,-34,55,20),Rect2(-39,-32,15,20),Rect2(25,-35,16,23)]:
		var ret := Rect2(_pecas.painel_ruinas.ponto+base.position,base.size)
		_colisao(ret)
		_pecas.painel_ruinas.colisoes.append({"ret":ret,"corpo":get_child(-1)})
	_objeto("suprimentos_resgate","suprimentos",Vector2(340,810),43,Vector2(32,16))
	_objeto("tronco_atalho","tronco",Vector2(1050,560),92,Vector2(74,12))
	for i in dados.rios.size():
		var trecho: Array = dados.rios[i]
		var a := _ponto(trecho[0])
		var b := _ponto(trecho[1])
		var normal := (b-a).normalized().orthogonal()
		for lado in [-1,1]:
			var p: Vector2 = a.lerp(b,.48)+normal*(float(trecho[2])+18)*lado
			# Reservar também as cabeceiras: uma pedra na margem fechava a entrada.
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(215,402),Vector2(350,538)))<38: continue
			_objeto("pedras_rio_%d_%d" % [i,lado],"pedras",p,38,Vector2(24,14))
	for i in 6:
		_objeto("pedras_trilha_"+str(i),"pedras",[Vector2(540,760),Vector2(970,600),Vector2(1190,600),Vector2(1260,310),Vector2(690,345),Vector2(160,740)][i],40,Vector2(18,10))
	_objeto("toco_chegada","toco",Vector2(90,880),34,Vector2(15,8))
	_objeto("toco_trilha","toco",Vector2(635,695),32,Vector2(15,8))

func _montar_floresta() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 371804
	var pontos: Array[Vector2] = []
	for i in 1700:
		if pontos.size()>=155: break
		var p := Vector2(rng.randf_range(25,1510),rng.randf_range(55,1030))
		var mundo := _da_imagem(p)
		if _tipo_canto(Vector2i((mundo/16).floor()))!=GRAMA: continue
		var na_margem := false
		for deslocamento in [Vector2(-26,-12),Vector2(26,-12),Vector2(0,-30),Vector2(0,12)]:
			if peso_agua(mundo+deslocamento)>.05: na_margem=true
		if na_margem: continue
		# Preservar a leitura dos marcos sem copas aleatórias na frente.
		if Rect2(60,190,230,240).has_point(p) or Rect2(280,780,160,170).has_point(p): continue
		if pontos.any(func(outro):return outro.distance_to(p)<64): continue
		var perto := false
		for alvo in dados.alvos.values():
			if mundo.distance_to(_ponto(alvo.p))<80: perto=true
		if mundo.distance_to(_ponto(dados.entrada))<95: perto=true
		for registro in _pecas.values():
			if registro.tipo in ["carvalho","jovem","pinheiro"]: continue
			if mundo.distance_to(registro.ponto)<maxf(40,registro.largura*.65): perto=true
		if perto: continue
		pontos.append(p)
		var tipo := "pinheiro" if rng.randf()<.16 else ("jovem" if rng.randf()<.3 else "carvalho")
		_objeto("arvore_"+str(pontos.size()),tipo,p,rng.randf_range(86,116),Vector2(20,22))
	for i in 48:
		var p := Vector2(rng.randf_range(15,1520),rng.randf_range(20,1020))
		if _tipo_canto(Vector2i((_da_imagem(p)/16).floor()))!=GRAMA: continue
		_objeto("arbustos_"+str(i),"arbustos",p,rng.randf_range(34,52),Vector2.ZERO)

func definir_estacao(indice: int) -> void:
	estacao_atual = clampi(indice,0,3)
	_estacoes.estacao_atual = estacao_atual
	var nome: String = NOMES[estacao_atual]
	for tipo in ["grama","pedra","agua"]:
		_material.set_shader_parameter(tipo,load(RAIZ+nome+"/"+tipo+".png"))
	_material.set_shader_parameter("raizes",load(RAIZ+nome+"/terra_raizes.png"))
	if regiao == "chegada": _material.set_shader_parameter("agua_tons",PaletaAgua.TONS[estacao_atual])
	_material.set_shader_parameter("terra",load("res://assets/cenario/fazenda/natureza_detalhada/%s/terra.png" % nome))
	for registro in _pecas.values():
		var ficha: Dictionary = _fichas[registro.tipo]
		var dados_peca: Dictionary = ficha.variantes[nome]
		var primavera: Dictionary = ficha.variantes.primavera
		var escala: float = float(registro.largura)/float(primavera.largura_visivel)*float(primavera.quadro[0])/float(dados_peca.quadro[0])
		registro.sprite.texture = load(dados_peca.textura)
		registro.sprite.offset = -Vector2(dados_peca.pivo[0],dados_peca.pivo[1])
		registro.sprite.scale = Vector2(-escala,escala) if registro.get("espelhado",false) else Vector2.ONE*escala
	_aplicar_quadro_bau()
	estacao_mudou.emit(estacao_atual)

## Pontos de integração para corte, remoção de entulho e alterações de solo.
func remover_objeto(id: String) -> Error:
	if not _pecas.has(id): return ERR_DOES_NOT_EXIST
	var registro: Dictionary = _pecas[id]
	for colisao in registro.colisoes:
		obstaculos.erase(colisao.ret)
		colisao.corpo.queue_free()
	registro.sprite.queue_free()
	_pecas.erase(id)
	_montar_navegacao()
	objeto_removido.emit(id)
	return OK

func alterar_terreno(celula: Vector2i, tipo: int) -> Error:
	if tipo<GRAMA or tipo>AGUA or not limites.has_point(Vector2(celula*16)): return ERR_INVALID_PARAMETER
	for delta in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]: _cantos[celula+delta]=tipo
	for y in range(-1,2):
		for x in range(-1,2): _atualizar_tile(celula+Vector2i(x,y))
	_colisoes_agua()
	_montar_navegacao()
	terreno_alterado.emit(celula,tipo)
	return OK

func aplicar_equipamentos_encontrados(equipamentos: Array) -> void:
	# Compatibilidade: saves que já coletaram equipamentos retomam o baú aberto.
	if not equipamentos.is_empty() and estado_bau==EstadoBau.FECHADO: restaurar_bau_aberto()

func restaurar_bau_aberto() -> void:
	estado_bau=EstadoBau.ABERTO
	quadro_bau=3
	_aplicar_quadro_bau()

func abrir_bau() -> Error:
	if estado_bau==EstadoBau.ABRINDO: return ERR_BUSY
	if estado_bau==EstadoBau.ABERTO: return ERR_ALREADY_IN_USE
	estado_bau=EstadoBau.ABRINDO
	_tempo_bau=0
	quadro_bau=0
	_aplicar_quadro_bau()
	return OK

func _process(delta: float) -> void:
	if regiao == "chegada":
		_tempo_rio += delta
		_material.set_shader_parameter("fase_corrente",Vector3(_tempo_rio,_tempo_rio,_tempo_rio))
	if estado_bau!=EstadoBau.ABRINDO: return
	_tempo_bau+=delta
	var proximo := mini(int(_tempo_bau/float(_ficha_bau.duracao_quadro)),3)
	if proximo!=quadro_bau:
		quadro_bau=proximo
		_aplicar_quadro_bau()
	if _tempo_bau>=float(_ficha_bau.duracao_quadro)*4:
		estado_bau=EstadoBau.ABERTO
		abertura_bau_concluida.emit()

func _aplicar_quadro_bau() -> void:
	if not _pecas.has("bau_resgate") or _ficha_bau.is_empty(): return
	var ficha: Dictionary=_ficha_bau.variantes[NOMES[estacao_atual]]
	var sprite: Sprite2D=_pecas.bau_resgate.sprite
	sprite.texture=load(ficha.textura)
	sprite.region_enabled=true
	var tamanho := Vector2(ficha.quadro[0],ficha.quadro[1])
	sprite.region_rect=Rect2(Vector2(quadro_bau%2,quadro_bau/2)*tamanho,tamanho)
	sprite.offset=-Vector2(ficha.pivo[0],ficha.pivo[1])
	sprite.scale=Vector2.ONE*(50.0/float(ficha.largura_corpo))

func atualizar_oclusao(personagem: Node2D, delta: float) -> void:
	# A ordenação continua pelos pés; apenas a folhagem que encobre o ator atenua.
	var cabeca := personagem.global_position+Vector2(0,-13)
	var peito := personagem.global_position+Vector2(0,-3)
	for registro in _pecas.values():
		if not registro.tipo in ["carvalho","jovem","pinheiro","arbustos"]: continue
		var sprite: Sprite2D = registro.sprite
		var encobre := false
		if sprite.z_index>personagem.z_index:
			var area := sprite.get_rect()
			encobre=area.has_point(sprite.to_local(cabeca)) or area.has_point(sprite.to_local(peito))
		sprite.modulate.a=move_toward(sprite.modulate.a,.3 if encobre else 1.0,delta*6)
