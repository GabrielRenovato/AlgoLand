extends RefCounted

## Uma fase espacial para todo o campo; divisões16px não cortam o material em retalhos aleatórios.
const FOLHAS := [
	preload("res://assets/cenario/substitutos/grama_continua/spring.png"),
	preload("res://assets/cenario/substitutos/grama_continua/summer.png"),
	preload("res://assets/cenario/substitutos/grama_continua/autumn.png"),
	preload("res://assets/cenario/substitutos/grama_continua/winter.png"),
]
var _camada: TileMapLayer
var _fonte: TileSetAtlasSource
var _id := -1
var _celulas: Array[Dictionary] = []

func configurar(terreno: Node) -> void:
	_camada = terreno.get_node_or_null("Chao") as TileMapLayer
	if _camada == null or _camada.tile_set == null: return
	var conjunto := _camada.tile_set
	if conjunto.get_physics_layers_count() > 0 or conjunto.get_navigation_layers_count() > 0: return
	for celula in _camada.get_used_cells():
		var atlas := _camada.get_cell_atlas_coords(celula)
		var id := _camada.get_cell_source_id(celula)
		var origem := conjunto.get_source(id) as TileSetAtlasSource
		if origem == null or not "substitutos" in origem.texture.resource_path: continue
		var banco := -1
		if atlas.x == 0 and atlas.y >= 1 and atlas.y <= 5:
			banco = 0
		elif atlas.x >= 0 and atlas.x <= 3 and atlas.y in [6,7]:
			banco = 1+atlas.x+(atlas.y-6)*4
		if banco >= 0:
			_celulas.append({"celula":celula,"id":id,"atlas":atlas,"alternativa":_camada.get_cell_alternative_tile(celula),"banco":banco,"camada":_camada})
	var topo := terreno.get_node_or_null("Penhasco") as TileMapLayer
	if topo != null and topo.tile_set == conjunto:
		for celula in topo.get_used_cells():
			var atlas := topo.get_cell_atlas_coords(celula)
			if atlas.x in [7,8] and atlas.y >= 0 and atlas.y <= 3:
				_celulas.append({"celula":celula,"id":topo.get_cell_source_id(celula),"atlas":atlas,"alternativa":topo.get_cell_alternative_tile(celula),"banco":0,"camada":topo})
	if _celulas.is_empty(): return
	# Reutiliza a fonte ao reentrar no mapa; não acumula atlas no TileSet compartilhado.
	for i in conjunto.get_source_count():
		var existente_id := conjunto.get_source_id(i)
		var existente := conjunto.get_source(existente_id) as TileSetAtlasSource
		if existente != null and existente.texture != null and "/grama_continua/" in existente.texture.resource_path:
			_fonte = existente
			_id = existente_id
			return
	_fonte = TileSetAtlasSource.new()
	_fonte.texture = FOLHAS[0]
	_fonte.texture_region_size = Vector2i(16,16)
	for y in 72:
		for x in 8: _fonte.create_tile(Vector2i(x,y))
	_id = conjunto.get_next_source_id()
	conjunto.add_source(_fonte,_id)

func aplicar(estacao: int, ativo: bool) -> void:
	if _fonte == null: return
	_fonte.texture = FOLHAS[estacao]
	for dados in _celulas:
		var celula: Vector2i = dados.celula
		var camada: TileMapLayer = dados.camada
		if ativo:
			camada.set_cell(celula,_id,Vector2i(posmod(celula.x,8),posmod(celula.y,8)+dados.banco*8))
		else:
			camada.set_cell(celula,dados.id,dados.atlas,dados.alternativa)
