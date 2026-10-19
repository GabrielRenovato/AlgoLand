extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_recortada/"

func _initialize() -> void:
	construir.call_deferred()

func construir() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"mapa.json"))
	var fonte := TileSetAtlasSource.new()
	fonte.texture = load(BASE+"atlas.png")
	fonte.texture_region_size = Vector2i(16,16)
	fonte.margins = Vector2i(1,1)
	fonte.separation = Vector2i(2,2)
	for indice in int(dados.unicos):
		fonte.create_tile(Vector2i(indice%64,indice/64))
	var conjunto := TileSet.new()
	conjunto.resource_name = "Caverna_recortes_fieis"
	conjunto.tile_size = Vector2i(16,16)
	conjunto.add_source(fonte,0)
	var celulas := {}
	for celula: Array in dados.celulas:
		celulas[Vector2i(celula[0],celula[1])] = int(celula[2])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE+"padroes"))
	for nome: String in dados.padroes:
		var ret: Array = dados.padroes[nome]
		var padrao := TileMapPattern.new()
		padrao.resource_name = nome
		for y in range(ret[1]/16,ret[3]/16):
			for x in range(ret[0]/16,ret[2]/16):
				var indice: int = celulas[Vector2i(x,y)]
				padrao.set_cell(Vector2i(x-ret[0]/16,y-ret[1]/16),0,Vector2i(indice%64,indice/64),0)
		assert(ResourceSaver.save(padrao,BASE+"padroes/"+nome+".tres")==OK)
		conjunto.add_pattern(padrao)
	assert(ResourceSaver.save(conjunto,BASE+"caverna.tres")==OK)
	var raiz := Node2D.new()
	raiz.name = "CavernaRecortada"
	raiz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.set_meta("origem", "estudo_gaias_navel_v2.png")
	raiz.set_meta("uso", "Arte recortada para montagem manual; sem autotile ou física")
	var mapa := TileMapLayer.new()
	mapa.name = "Caverna"
	# Mantém as cores escolhidas: o autoload de acabamento só modifica nós sem material.
	mapa.material = CanvasItemMaterial.new()
	mapa.tile_set = conjunto
	mapa.collision_enabled = false
	mapa.navigation_enabled = false
	raiz.add_child(mapa)
	mapa.owner = raiz
	for celula: Array in dados.celulas:
		var indice: int = celula[2]
		mapa.set_cell(Vector2i(celula[0],celula[1]),0,Vector2i(indice%64,indice/64))
	var cena := PackedScene.new()
	assert(cena.pack(raiz)==OK)
	assert(ResourceSaver.save(cena,"res://cenas/fendas/caverna_recortada.tscn")==OK)
	print("CAVERNA RECORTADA: ",dados.celulas.size()," células16; ",conjunto.get_patterns_count()," padrões nativos registrados no TileSet")
	raiz.free()
	quit()
