extends RefCounted

## Terra com fase espacial única no centro e nas bordas; mantém a máscara de cada peça.
const FOLHAS := [
	preload("res://assets/cenario/substitutos/terra_continua/spring.png"),
	preload("res://assets/cenario/substitutos/terra_continua/summer.png"),
	preload("res://assets/cenario/substitutos/terra_continua/autumn.png"),
	preload("res://assets/cenario/substitutos/terra_continua/winter.png"),
]
const CENTROS := [Vector2i(2,1),Vector2i(4,0),Vector2i(4,1),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4)]
const BORDAS := [Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(1,1),Vector2i(3,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(1,3),Vector2i(2,3),Vector2i(1,4),Vector2i(2,4)]
var _mascarada: RefCounted
var _camada: TileMapLayer
var _fonte: TileSetAtlasSource
var _id := -1
var _celulas: Array[Dictionary] = []
var _atlas_originais: Dictionary = {}

func configurar(terreno: Node) -> void:
	_camada = terreno.get_node_or_null("Terra") as TileMapLayer
	if _camada == null or _camada.tile_set == null: return
	var conjunto := _camada.tile_set
	var original := conjunto.get_source(0) as TileSetAtlasSource
	if original != null and not "/substitutos/" in original.texture.resource_path:
		for andar in [1,2,5,8]:
			if "/fendas/andar_%02d/" % andar in original.texture.resource_path:
				_mascarada = preload("res://codigo/cenario/terra_mascarada.gd").new()
				_mascarada.configurar(_camada,{0:"andar_%02d/" % andar + "%s"},CENTROS+BORDAS)
				return
	if conjunto.get_physics_layers_count() > 0 or conjunto.get_navigation_layers_count() > 0: return
	for celula in _camada.get_used_cells():
		var atlas := _camada.get_cell_atlas_coords(celula)
		var id := _camada.get_cell_source_id(celula)
		var origem := conjunto.get_source(id) as TileSetAtlasSource
		if origem == null or not "/substitutos/" in origem.texture.resource_path: continue
		var banco := 0 if atlas in CENTROS else BORDAS.find(atlas)+1
		if banco == 0 and not atlas in CENTROS: continue
		_atlas_originais[celula] = atlas
		_celulas.append({"celula":celula,"id":id,"atlas":atlas,"alternativa":_camada.get_cell_alternative_tile(celula),"banco":banco})
	if _celulas.is_empty(): return
	for i in conjunto.get_source_count():
		var id := conjunto.get_source_id(i)
		var existente := conjunto.get_source(id) as TileSetAtlasSource
		if existente != null and existente.texture != null and "/terra_continua/" in existente.texture.resource_path:
			_fonte = existente
			_id = id
			return
	_fonte = TileSetAtlasSource.new()
	_fonte.texture = FOLHAS[0]
	_fonte.texture_region_size = Vector2i(16,16)
	for y in 104:
		for x in 8: _fonte.create_tile(Vector2i(x,y))
	_id = conjunto.get_next_source_id()
	conjunto.add_source(_fonte,_id)

func aplicar(estacao: int, ativo: bool) -> void:
	if _mascarada != null:
		_mascarada.aplicar(estacao,ativo)
		return
	if _fonte == null: return
	_fonte.texture = FOLHAS[estacao]
	for dados in _celulas:
		var pos: Vector2i = dados.celula
		if ativo:
			_camada.set_cell(pos,_id,Vector2i(posmod(pos.x,8),posmod(pos.y,8)+dados.banco*8))
		else:
			_camada.set_cell(pos,dados.id,dados.atlas,dados.alternativa)

## O plantio consulta a geometria original, independente da fase visual do material.
func atlas_original(celula: Vector2i) -> Vector2i:
	if _camada.get_cell_source_id(celula) == _id and _atlas_originais.has(celula):
		return _atlas_originais[celula]
	return _camada.get_cell_atlas_coords(celula)
