extends Node2D

## Geometrias próprias com arte sazonal já integrada à cidade/fazenda.
## Grade 16px e transições por cantos iguais a ferramentas/cidade/terreno_vila.py.
signal estacao_mudou(indice: int)
const LAYOUT := preload("res://codigo/campanha/regioes_iniciais.json")
const NOMES := ["primavera","verao","outono","inverno"]
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Terra := preload("res://codigo/cenario/terra_mascarada.gd")
@export var regiao := "chegada"
var dados: Dictionary
var limites := Rect2()
var chao: TileMapLayer
var obstaculos: Array[Rect2] = []
var navegacao: NavigationRegion2D
var estacao_atual := -1
var _sazonais: Array[Dictionary] = []
var _terra := Terra.new()
var _estacoes: Node
var _reparo: Node2D
var _chao_detalhado: Node2D
var margem_obstaculos_navegacao := 6.0
var raio_agente_navegacao := 7.0

func _ready() -> void:
	dados = LAYOUT.data[regiao].duplicate(true)
	var tamanho := Vector2(dados.tamanho[0],dados.tamanho[1])
	limites = Rect2(-tamanho/2,tamanho)
	_estacoes = Node.new()
	_estacoes.name = "Estacoes"
	_estacoes.set_script(preload("res://codigo/campanha/estacoes_campanha.gd"))
	add_child(_estacoes)
	_montar_chao()
	_bordas()
	_paisagem()
	for item in dados.get("props",[]):
		_natureza(item[0],_ponto(item[1]))
	for ponto in dados.get("arvores",[]):
		_natureza("carvalho",_ponto(ponto))
	for casa in dados.get("casas",[]):
		_casa(casa[0],_ponto(casa[1]))
	for id in dados.alvos:
		var item: Dictionary = dados.alvos[id]
		if item.has("prop"):
			_decoracao(item.prop,_ponto(item.p)+Vector2(0,-24))
	if regiao == "pomar": _montar_pomar()
	_montar_navegacao()
	definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)

## Chão do padrão antigo (Wang 4×6 da vila original); regiões no padrão modular sobrescrevem.
func _montar_chao() -> void:
	chao = TileMapLayer.new()
	chao.name = "Chao"
	chao.z_index = Profundidade.Z_CHAO
	chao.tile_set = preload("res://recursos/cidade/tileset_terreno.tres").duplicate(true)
	add_child(chao)
	for y in range(int(limites.position.y/16),int(limites.end.y/16)):
		for x in range(int(limites.position.x/16),int(limites.end.x/16)):
			var cantos := [_terreno(Vector2(x,y)*16),_terreno(Vector2(x+1,y)*16),_terreno(Vector2(x,y+1)*16),_terreno(Vector2(x+1,y+1)*16)]
			var tile := _tile(cantos)
			chao.set_cell(Vector2i(x,y),tile[0],Vector2i(tile[1],tile[2]))
	var agua := TileMapLayer.new()
	agua.name = "SuperficieAgua"
	agua.tile_set = chao.tile_set
	add_child(agua)
	_chao_detalhado = preload("res://codigo/campanha/chao_campanha.gd").new()
	_chao_detalhado.name = "ChaoDetalhado"
	add_child(_chao_detalhado)
	_chao_detalhado.configurar(chao,agua)
	_terra.configurar(chao,{0:"cidade/%s_grama_terra",2:"cidade/%s_terra_pedra"})

func _ponto(valor: Array) -> Vector2:
	return Vector2(valor[0],valor[1])

func _ao_dia(_dia: int) -> void:
	definir_estacao(Calendario.estacao())

func _terreno(p: Vector2) -> String:
	var aberto := false
	for trecho in dados.trilhas:
		if Geometry2D.get_closest_point_to_segment(p,_ponto(trecho[0]),_ponto(trecho[1])).distance_to(p)<float(trecho[2]):
			aberto = true
	for clareira in dados.clareiras:
		var d := (p-_ponto(clareira[0]))/_ponto(clareira[1])
		if d.length_squared()<1: aberto = true
	if regiao == "pomar":
		var pontos := [Vector2(-64,-144),Vector2(48,-160),Vector2(128,-152),Vector2(240,-176),Vector2(320,-176)]
		for i in pontos.size()-1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,pontos[i],pontos[i+1]))<10:
				aberto = true
	return ("pedra" if regiao == "vila" else "terra") if aberto else "grama"

func _tile(cantos: Array) -> Array:
	# Máscara NO, NE, SO, SE da biblioteca Wang 4×6 usada na cidade.
	if cantos.all(func(c): return c == cantos[0]):
		return [0,0,4] if cantos[0] == "grama" else ([1,0,5] if cantos[0] == "pedra" else [0,0,5])
	var superior := "pedra" if "pedra" in cantos else "terra"
	var fonte := 1 if superior == "pedra" else 0
	var mascara := 0
	for i in 4:
		if cantos[i] == superior: mascara |= 1<<(3-i)
	return [fonte,mascara%4,mascara/4]

func _colisao(retangulo: Rect2) -> void:
	obstaculos.append(retangulo)
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = retangulo.size
	forma.shape = caixa
	forma.position = retangulo.get_center()
	corpo.add_child(forma)
	add_child(corpo)

func _colisao_poligono(pontos: PackedVector2Array) -> void:
	if pontos.size() < 3:return
	var limites_poligono := Rect2(pontos[0],Vector2.ZERO)
	for ponto in pontos:
		limites_poligono=limites_poligono.expand(ponto)
	# A caixa mantém a navegação e os pontos seguros conservadores; a física usa o contorno real.
	obstaculos.append(limites_poligono)
	var corpo := StaticBody2D.new()
	corpo.name="ColisaoPoligono"
	corpo.collision_layer=64
	corpo.collision_mask=0
	var forma := CollisionPolygon2D.new()
	forma.name="Forma"
	forma.build_mode=CollisionPolygon2D.BUILD_SOLIDS
	forma.polygon=pontos
	corpo.add_child(forma)
	add_child(corpo)

func _bordas() -> void:
	_colisao(Rect2(limites.position-Vector2(16,16),Vector2(limites.size.x+32,16)))
	_colisao(Rect2(Vector2(limites.position.x,limites.end.y),Vector2(limites.size.x,16)))
	_colisao(Rect2(limites.position-Vector2(16,0),Vector2(16,limites.size.y)))
	_colisao(Rect2(Vector2(limites.end.x,limites.position.y),Vector2(16,limites.size.y)))

func _paisagem() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = regiao.hash()
	for y in range(int(limites.position.y)+56,int(limites.end.y)-8,80):
		for x in range(int(limites.position.x)+40,int(limites.end.x)-8,88):
			var ponto := Vector2(x+rng.randi_range(-12,12),y+rng.randi_range(-8,8))
			if _terreno(ponto) != "grama": continue
			if regiao == "vila" and ponto.length()<420: continue
			if regiao == "pomar" and absf(ponto.x)<350 and absf(ponto.y)<230:continue
			var perto := false
			for item in dados.alvos.values():
				if ponto.distance_to(_ponto(item.p))<65:perto=true
			if ponto.distance_to(_ponto(dados.entrada))<100:perto=true
			if perto:continue
			_natureza("pinheiro" if rng.randf()<0.25 else "carvalho",ponto)

func _natureza(peca: String, ponto: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.position = ponto
	sprite.centered = false
	sprite.scale = Vector2.ONE/4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var arvore := peca in ["carvalho","pinheiro"]
	var tamanho := Vector2(512,512) if arvore or peca in ["jovem","muda"] else Vector2(64,64)
	sprite.offset = Vector2(-tamanho.x/2,-tamanho.y)
	sprite.z_as_relative = false
	sprite.z_index = Profundidade.z_de(ponto.y)
	add_child(sprite)
	_sazonais.append({"sprite":sprite,"peca":peca})
	_colisao(Rect2(ponto-Vector2(9,6),Vector2(18,10)) if arvore else Rect2(ponto-Vector2(6,7),Vector2(12,7)))

func _casa(id: String, ponto: Vector2) -> void:
	# Reutiliza imagem sazonal, âncora e base física da fachada detalhada.
	var medidas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/casas/exteriores.json"))[id]
	var detalhes := preload("res://codigo/cidade/fachadas_detalhadas.gd").dados(id)
	var sprite := Sprite2D.new()
	sprite.position = ponto
	sprite.centered = false
	sprite.offset = -_ponto(medidas.ancora)*4
	sprite.scale = Vector2.ONE/4
	sprite.z_index = Profundidade.z_de(ponto.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_sazonais.append({"sprite":sprite,"texturas":detalhes.texturas})
	for ret in medidas.colisoes:
		_colisao(Rect2(ponto+Vector2(ret[0],ret[1]),Vector2(ret[2]-ret[0],ret[3]-ret[1])))

func _decoracao(id: String, ponto: Vector2) -> void:
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/decoracao/decoracao.json"))
	for item in itens:
		if item.p != id:continue
		var detalhes := preload("res://codigo/cidade/enfeites_detalhados.gd").dados(id)
		if not detalhes.is_empty():item.merge(detalhes,true)
		var sprite := Sprite2D.new()
		sprite.position = ponto
		sprite.centered = false
		var resolucao := float(item.get("resolucao",1))
		sprite.scale = Vector2.ONE/resolucao
		sprite.hframes = int(item.get("quadros",1))
		sprite.offset = Vector2(-float(item.usado[2])/2,-float(item.usado[3]))*resolucao
		sprite.z_index = Profundidade.z_de(ponto.y)
		add_child(sprite)
		_sazonais.append({"sprite":sprite,"texturas":item.texturas})
		_colisao(Rect2(ponto-Vector2(item.col[0]/2.0,item.col[1]),Vector2(item.col[0],item.col[1])))
		return

func _aplicar_chao_estacao() -> void:
	for i in 4:
		var fonte := chao.tile_set.get_source(i) as TileSetAtlasSource
		fonte.texture = load("res://assets/cenario/algoland_original/%s/%s.png" % [NOMES[estacao_atual],["grama_terra","grama_pedra","terra_pedra","grama_agua"][i]])
	_terra.aplicar(estacao_atual)
	_chao_detalhado.aplicar(estacao_atual)

func definir_estacao(indice: int) -> void:
	estacao_atual = clampi(indice,0,3)
	_estacoes.estacao_atual = estacao_atual
	_aplicar_chao_estacao()
	for item in _sazonais:
		item.sprite.texture = load(item.texturas[estacao_atual]) if item.has("texturas") else load("res://assets/cenario/fazenda/natureza_detalhada/%s/%s.png" % [NOMES[estacao_atual],item.peca])
	estacao_mudou.emit(estacao_atual)

func _montar_navegacao() -> void:
	if is_instance_valid(navegacao):
		remove_child(navegacao)
		navegacao.queue_free()
	navegacao = NavigationRegion2D.new()
	navegacao.name = "Navegacao"
	var geometria := NavigationMeshSourceGeometryData2D.new()
	var r := limites.grow(-10)
	geometria.add_traversable_outline(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]))
	for obstaculo in obstaculos:
		if not limites.encloses(obstaculo):continue
		var b := obstaculo.grow(margem_obstaculos_navegacao)
		geometria.add_obstruction_outline(PackedVector2Array([b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]))
	var malha := NavigationPolygon.new()
	malha.agent_radius = raio_agente_navegacao
	NavigationServer2D.bake_from_source_geometry_data(malha,geometria)
	navegacao.navigation_polygon = malha
	add_child(navegacao)
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)

func ponto_livre(ponto: Vector2) -> Vector2:
	if navegacao == null:return ponto
	return NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map,ponto)

func ponto_seguro(ponto: Vector2) -> bool:
	if not limites.grow(-12).has_point(ponto):return false
	for ret in obstaculos:
		if ret.grow(8).has_point(ponto+Vector2(0,11)):return false
	return true

func _peca_cerca(ponto: Vector2, tipo: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.position = ponto
	sprite.centered = false
	sprite.offset = Vector2(-16,-92)
	sprite.scale = Vector2.ONE/4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = Profundidade.z_de(ponto.y)
	add_child(sprite)
	var texturas := []
	for estacao in NOMES:
		texturas.append("res://assets/cenario/cidade/complementos/cercas/%s/%s.png" % [estacao,tipo])
	_sazonais.append({"sprite":sprite,"texturas":texturas})
	return sprite

func _montar_pomar() -> void:
	# As cercas têm vãos de passagem; reparar muda o desenho, sem fechar a rota.
	for id in ["cerca_pomar","barreira_pomar"]:
		var base := _ponto(dados.alvos[id].p)+Vector2(0,-24)
		for x in [-64,-48,-32,16,32,48]:
			_peca_cerca(base+Vector2(x,0),"horizontal")
		_colisao(Rect2(base+Vector2(-64,-4),Vector2(48,4)))
		_colisao(Rect2(base+Vector2(16,-4),Vector2(48,4)))
		for x in [-64,-16,16,64]:
			_peca_cerca(base+Vector2(x,0),"poste")
		if id == "barreira_pomar":
			_reparo = Node2D.new()
			add_child(_reparo)
			for x in [-16,0]:
				var peca := _peca_cerca(base+Vector2(x,0),"horizontal")
				remove_child(peca)
				_reparo.add_child(peca)
			_reparo.hide()
	_natureza("jovem",Vector2(-80,-176))
	_natureza("muda",Vector2(-48,-176))

func aplicar_descobertas(cumpridos: Array) -> void:
	if is_instance_valid(_reparo) and not _reparo.visible and "barreira" in cumpridos:
		_reparo.show()
		var base := _ponto(dados.alvos.barreira_pomar.p)+Vector2(0,-24)
		_colisao(Rect2(base+Vector2(-16,-4),Vector2(32,4)))
		_montar_navegacao()
