extends NavigationRegion2D

## Monta a malha de navegação dos inimigos de chão quando a cena carrega: a área da arena (LimiteArena)
## menos todos os obstáculos sólidos (lago, árvores soltas, pedras, tocos, barraca, fogueira...).
## Assim o mapa pode ser regerado/editado sem precisar "assar" a navegação no editor.

## Folga em volta dos obstáculos: metade do maior corpo de inimigo de chão (gremlin/caranguejo ~22 px) com sobra
const RAIO_AGENTE := 14.0
const LADOS_CIRCULO := 10

@export var limite: NodePath = ^"../LimiteArena/Contorno"
@export var obstaculos: Array[NodePath] = [^"../Obstaculos", ^"../BarracaAberta/Colisao", ^"../Fogueira", ^"../BarraFechada/1"]

func _ready() -> void:
	var contorno := get_node_or_null(limite) as CollisionPolygon2D
	if contorno == null:
		return
	var geometria := NavigationMeshSourceGeometryData2D.new()
	geometria.add_traversable_outline(_para_local(contorno, contorno.polygon))
	for caminho in obstaculos:
		var no := get_node_or_null(caminho)
		if no:
			_coletar(no, geometria)
	var malha := NavigationPolygon.new()
	malha.agent_radius = RAIO_AGENTE
	NavigationServer2D.bake_from_source_geometry_data(malha, geometria)
	navigation_polygon = malha

func _coletar(no: Node, geometria: NavigationMeshSourceGeometryData2D) -> void:
	if no is CollisionPolygon2D:
		geometria.add_obstruction_outline(_para_local(no, no.polygon))
	elif no is CollisionShape2D and no.shape:
		var pontos := _pontos_da_forma(no.shape)
		if not pontos.is_empty():
			geometria.add_obstruction_outline(_para_local(no, pontos))
	elif no is TileMapLayer:
		_coletar_tiles(no, geometria)
	for filho in no.get_children():
		_coletar(filho, geometria)

func _coletar_tiles(camada: TileMapLayer, geometria: NavigationMeshSourceGeometryData2D) -> void:
	if camada.tile_set == null or camada.tile_set.get_physics_layers_count() == 0:
		return
	for celula in camada.get_used_cells():
		var dados := camada.get_cell_tile_data(celula)
		if dados == null:
			continue
		var centro := camada.map_to_local(celula)
		for i in dados.get_collision_polygons_count(0):
			var pontos := PackedVector2Array()
			for p in dados.get_collision_polygon_points(0, i):
				pontos.append(centro + p)
			geometria.add_obstruction_outline(_para_local(camada, pontos))

func _pontos_da_forma(forma: Shape2D) -> PackedVector2Array:
	if forma is RectangleShape2D:
		var m: Vector2 = forma.size * 0.5
		return PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	var raio := 0.0
	if forma is CircleShape2D:
		raio = forma.radius
	elif forma is CapsuleShape2D:
		raio = maxf(forma.radius, forma.height * 0.5)
	if raio <= 0.0:
		return PackedVector2Array()
	var pontos := PackedVector2Array()
	for i in LADOS_CIRCULO:
		pontos.append(Vector2.from_angle(TAU * i / LADOS_CIRCULO) * raio)
	return pontos

func _para_local(no: Node2D, pontos: PackedVector2Array) -> PackedVector2Array:
	return (global_transform.affine_inverse() * no.global_transform) * pontos
