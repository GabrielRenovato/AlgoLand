extends RefCounted

## Troca apenas pixels de terra; ids, índices Wang, guia e geometrias permanecem.
const SHADER := preload("res://codigo/cenario/terra_mascarada.gdshader")
const NOMES := ["spring","summer","autumn","winter"]
var _fontes: Array[Dictionary] = []

func configurar(camada: TileMapLayer, familias: Dictionary, limitar_tiles: Array = []) -> void:
	if camada == null or camada.tile_set == null: return
	for id in familias:
		var fonte := camada.tile_set.get_source(id) as TileSetAtlasSource
		if fonte == null: continue
		var material := ShaderMaterial.new()
		material.shader = SHADER
		camada.get_node("/root/TilesRefinados").registrar_material(material)
		var tiles: Array[Dictionary] = []
		for i in fonte.get_tiles_count():
			var atlas := fonte.get_tile_id(i)
			if not limitar_tiles.is_empty() and not atlas in limitar_tiles: continue
			var dados := fonte.get_tile_data(atlas,0)
			tiles.append({"dados":dados,"material":dados.material})
		_fontes.append({"fonte":fonte,"familia":familias[id],"material":material,"tiles":tiles,"padding":fonte.use_texture_padding})

func aplicar(estacao: int, ativo := true) -> void:
	for dados in _fontes:
		var fonte: TileSetAtlasSource = dados.fonte
		var material: ShaderMaterial = dados.material
		if ativo:
			material.set_shader_parameter("campo_terra",load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % NOMES[estacao]))
			material.set_shader_parameter("mascara_terra",load("res://assets/cenario/substitutos/terra_mascarada/%s.png" % (dados.familia % NOMES[estacao])))
		# Sem padding, o UV da máscara coincide com o atlas. Filtro nearest.
		fonte.use_texture_padding = false if ativo else dados.padding
		for tile in dados.tiles:
			tile.dados.material = material if ativo else tile.material
