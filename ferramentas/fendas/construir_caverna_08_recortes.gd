extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_recortada/"

func _initialize() -> void:
	construir.call_deferred()

func adicionar(no: Node,pai: Node,raiz: Node) -> void:
	pai.add_child(no)
	no.owner = raiz

func construir() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"andar_08.json"))
	var terreno := Node2D.new()
	terreno.name = "PreviaCavernaAndar08"
	terreno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terreno.set_meta("planta",8)
	terreno.set_meta("limites",Rect2(dados.limites[0],dados.limites[1],dados.limites[2],dados.limites[3]))
	var mapa := TileMapLayer.new()
	mapa.name = "Caverna"
	mapa.material = CanvasItemMaterial.new()
	mapa.tile_set = load(BASE+"caverna.tres")
	adicionar(mapa,terreno,terreno)
	for c: Array in dados.celulas:
		var indice: int = c[2]
		mapa.set_cell(Vector2i(c[0],c[1]),0,Vector2i(indice%64,indice/64),0)
	var setores := Node2D.new()
	setores.name = "Setores"
	adicionar(setores,terreno,terreno)
	for setor: Dictionary in dados.setores:
		var marcador := Marker2D.new()
		marcador.name = setor.id
		marcador.position = Vector2(setor.centro[0],setor.centro[1])
		adicionar(marcador,setores,terreno)
	var livres := {}
	for c: Array in dados.livres:livres[Vector2i(c[0],c[1])] = true
	var corpo := StaticBody2D.new()
	corpo.name = "LimitesVisuais"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	adicionar(corpo,terreno,terreno)
	var x0: int = dados.limites[0]/8
	var y0: int = dados.limites[1]/8
	var x1: int = x0+dados.limites[2]/8
	var y1: int = y0+dados.limites[3]/8
	for y in range(y0,y1):
		var x := x0
		while x<x1:
			if livres.has(Vector2i(x,y)):
				x += 1
				continue
			var inicio := x
			while x<x1 and not livres.has(Vector2i(x,y)):x += 1
			var forma := RectangleShape2D.new()
			forma.size = Vector2((x-inicio)*8,8)
			var colisao := CollisionShape2D.new()
			colisao.shape = forma
			colisao.position = Vector2((inicio+x)*4,y*8+4)
			adicionar(colisao,corpo,terreno)
	var nav := NavigationPolygon.new()
	nav.agent_radius = 8
	var geometria := NavigationMeshSourceGeometryData2D.new()
	# Unir as faixas antes do bake evita milhares de polígonos minúsculos nas rotas longas.
	for y in range(y0,y1):
		var x := x0
		while x<x1:
			if not livres.has(Vector2i(x,y)):
				x += 1
				continue
			var inicio := x
			while x<x1 and livres.has(Vector2i(x,y)):x += 1
			geometria.add_traversable_outline(PackedVector2Array([Vector2(inicio*8,y*8),Vector2(x*8,y*8),Vector2(x*8,y*8+8),Vector2(inicio*8,y*8+8)]))
	NavigationServer2D.bake_from_source_geometry_data(nav,geometria)
	var regiao := NavigationRegion2D.new()
	regiao.name = "Navegacao"
	regiao.navigation_polygon = nav
	adicionar(regiao,terreno,terreno)
	var cena := PackedScene.new()
	assert(cena.pack(terreno)==OK)
	assert(ResourceSaver.save(cena,"res://cenas/fendas/previa_caverna_08.tscn")==OK)
	print("CAVERNA08: planta original, atlas de recortes, dez marcadores, colisões e navegação")
	terreno.free()
	quit()
