extends RefCounted

## Usa o desenho de96px inteiro na face do morro. As células e obstáculos mantêm suas posições.
const FOLHAS := [
	preload("res://assets/cenario/substitutos/penhasco/spring.png"),
	preload("res://assets/cenario/substitutos/penhasco/summer.png"),
	preload("res://assets/cenario/substitutos/penhasco/autumn.png"),
	preload("res://assets/cenario/substitutos/penhasco/winter.png"),
]
var _camada: TileMapLayer
var _fonte: TileSetAtlasSource
var _id := -1
var _celulas: Array[Dictionary] = []

func configurar(terreno: Node) -> void:
	_camada = terreno.get_node_or_null("Penhasco") as TileMapLayer
	if _camada == null or _camada.tile_set == null: return
	var conjunto := _camada.tile_set
	# Estes mapas usam polígonos de obstáculos separados. Outros sistemas preservam seus tiles.
	if conjunto.get_physics_layers_count() > 0 or conjunto.get_navigation_layers_count() > 0: return
	for celula in _camada.get_used_cells():
		var atlas := _camada.get_cell_atlas_coords(celula)
		var id := _camada.get_cell_source_id(celula)
		var origem := conjunto.get_source(id) as TileSetAtlasSource
		if origem == null or not "substitutos" in origem.texture.resource_path: continue
		if atlas.x in [7,8] and atlas.y >= 4 and atlas.y <= 7:
			_celulas.append({"celula":celula,"id":id,"atlas":atlas,"alternativa":_camada.get_cell_alternative_tile(celula)})
	if _celulas.is_empty(): return
	_fonte = TileSetAtlasSource.new()
	_fonte.texture = FOLHAS[0]
	_fonte.texture_region_size = Vector2i(16,16)
	for y in 4:
		for x in 6: _fonte.create_tile(Vector2i(x,y))
	_id = conjunto.get_next_source_id()
	conjunto.add_source(_fonte,_id)

func aplicar(estacao: int, ativo: bool) -> void:
	if _fonte == null: return
	_fonte.texture = FOLHAS[estacao]
	for dados in _celulas:
		var celula: Vector2i = dados.celula
		var atlas: Vector2i = dados.atlas
		if ativo:
			_camada.set_cell(celula,_id,Vector2i(posmod(celula.x,6),atlas.y-4))
		else:
			_camada.set_cell(celula,dados.id,atlas,dados.alternativa)
