extends SceneTree

## Constrói uma cena editável: TileMapLayers reais, atlas16, colisão e navegação.
const DESTINO := "res://assets/cenario/fendas/gruta_nascente/"
var terreno: Node2D

func _initialize() -> void:
	construir.call_deferred()

func adicionar(no: Node, pai: Node) -> void:
	pai.add_child(no)
	no.owner = terreno

func construir() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESTINO + "mapa.json"))
	terreno = Node2D.new()
	terreno.name = "GrutaDaNascente"
	terreno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var textura := load(DESTINO + "base.png") as Texture2D
	var fonte := TileSetAtlasSource.new()
	fonte.texture = textura
	fonte.texture_region_size = Vector2i(16, 16)
	for y in 32:
		for x in 16:
			fonte.create_tile(Vector2i(x, y))
	var conjunto := TileSet.new()
	conjunto.resource_local_to_scene = true
	conjunto.tile_size = Vector2i(16, 16)
	conjunto.add_source(fonte, 0)
	for nome in ["Chao", "Agua"]:
		var camada := TileMapLayer.new()
		camada.name = nome
		camada.tile_set = conjunto
		camada.z_index = 0 if nome == "Chao" else 1
		adicionar(camada, terreno)
	for celula: Dictionary in dados.celulas:
		var posicao := Vector2i(celula.posicao[0], celula.posicao[1])
		var atlas := Vector2i(celula.atlas[0], celula.atlas[1])
		(terreno.get_node(celula.camada) as TileMapLayer).set_cell(posicao, 0, atlas)
	var objetos := Node2D.new()
	objetos.name = "Objetos"
	objetos.z_index = 2
	objetos.y_sort_enabled = true
	adicionar(objetos, terreno)
	var navegaveis := {}
	for ponto: Array in dados.navegaveis_8px:
		navegaveis[Vector2i(ponto[0], ponto[1])] = true
	for instancia: Dictionary in dados.instancias:
		var definicao: Dictionary = {}
		for candidato: Dictionary in dados.objetos:
			if candidato.nome == instancia.nome:
				definicao = candidato
		var objeto := Node2D.new()
		objeto.name = instancia.nome
		objeto.position = Vector2(instancia.posicao[0], instancia.posicao[1])
		adicionar(objeto, objetos)
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(definicao.regiao[0], definicao.regiao[1], definicao.regiao[2], definicao.regiao[3])
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = atlas
		sprite.centered = false
		sprite.position = -Vector2(definicao.pivo[0], definicao.pivo[1])
		adicionar(sprite, objeto)
		if instancia.nome != "nascente":
			# Somente a base sólida; haste, luz e sombra não bloqueiam a passagem.
			var base := Rect2(objeto.position - Vector2(10, 6), Vector2(20, 6))
			for y in range(floori(base.position.y/8), ceili(base.end.y/8)):
				for x in range(floori(base.position.x/8), ceili(base.end.x/8)):
					navegaveis.erase(Vector2i(x, y))
	var limites := StaticBody2D.new()
	limites.name = "Colisoes"
	limites.collision_layer = 1
	limites.collision_mask = 0
	adicionar(limites, terreno)
	for y in 56:
		var x := 0
		while x < 80:
			if navegaveis.has(Vector2i(x, y)):
				x += 1
				continue
			var inicio := x
			while x < 80 and not navegaveis.has(Vector2i(x, y)):
				x += 1
			var forma := RectangleShape2D.new()
			forma.size = Vector2((x-inicio)*8, 8)
			var colisao := CollisionShape2D.new()
			colisao.shape = forma
			colisao.position = Vector2((inicio+x)*4, y*8+4)
			adicionar(colisao, limites)
	var malha := NavigationPolygon.new()
	malha.agent_radius = 4
	var vertices := PackedVector2Array()
	var indices := {}
	var poligonos: Array[PackedInt32Array] = []
	for ponto: Vector2i in navegaveis:
		var poligono := PackedInt32Array()
		for deslocamento in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			var vertice: Vector2i = ponto + deslocamento
			if not indices.has(vertice):
				indices[vertice] = vertices.size()
				vertices.append(Vector2(vertice)*8)
			poligono.append(indices[vertice])
		poligonos.append(poligono)
	malha.vertices = vertices
	for poligono in poligonos:
		malha.add_polygon(poligono)
	var regiao := NavigationRegion2D.new()
	regiao.name = "Navegacao"
	regiao.navigation_polygon = malha
	adicionar(regiao, terreno)
	var entrada := Marker2D.new()
	entrada.name = "Entrada"
	entrada.position = Vector2(320, 408)
	adicionar(entrada, terreno)
	terreno.set_meta("estudo_visual", "Versão única solicitada; sem troca sazonal")
	terreno.set_meta("grade", 16)
	terreno.set_meta("tamanho", Vector2i(640, 448))
	var cena := PackedScene.new()
	assert(cena.pack(terreno) == OK)
	assert(ResourceSaver.save(cena, "res://cenas/fendas/gruta_nascente.tscn") == OK)
	print("GRUTA CONSTRUIDA: ", dados.celulas.size(), " células; ", navegaveis.size(), " células físicas livres; atlas16")
	terreno.free()
	quit()
