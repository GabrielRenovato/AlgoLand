extends NavigationRegion2D

## Monta a malha de navegação dos inimigos de chão quando a cena carrega: a área da arena (LimiteArena)
## menos todos os obstáculos sólidos (lago, árvores soltas, pedras, tocos, barraca, fogueira...).
## Assim o mapa pode ser regerado/editado sem precisar "assar" a navegação no editor.

## Folga em volta dos obstáculos, por tamanho de corpo. O corpo dos inimigos é um retângulo que não gira, então o que conta é a metade do
## lado maior (e a escala: mutantes e chefes são maiores que o inimigo comum). Uma malha só, com a folga do corpo pequeno, deixava os
## grandes encostarem nas árvores e nas pedras e ficarem presos. Cada classe é uma malha em uma camada de navegação (bit 1, 2 e 3);
## o inimigo escolhe a sua em Inimigo-base.gd (classe_de_navegacao)
const RAIOS_AGENTE: Array[float] = [14.0, 21.0, 30.0]
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
	for i in RAIOS_AGENTE.size():
		var malha := NavigationPolygon.new()
		malha.agent_radius = RAIOS_AGENTE[i]
		NavigationServer2D.bake_from_source_geometry_data(malha, geometria)
		malha = _triangular(malha)
		if i == 0:
			navigation_layers = 1
			navigation_polygon = malha
			continue
		# As malhas dos corpos maiores são regiões irmãs desta, cada uma na sua camada
		var regiao := NavigationRegion2D.new()
		regiao.name = "Navegacao_classe%d" % (i + 1)
		regiao.navigation_layers = 1 << i
		regiao.navigation_polygon = malha
		regiao.transform = transform
		get_parent().add_child.call_deferred(regiao)

## O bake devolve polígonos convexos grandes e o A* do Godot custeia a rota pelo centro de cada um: com polígonos grandes, de dois pontos
## vizinhos na borda de um obstáculo um escolhia contornar pela direita e o outro pela esquerda (rota até 60 px maior), e o inimigo ficava
## indo e voltando. Em triângulos (os mesmos vértices e arestas, então a conectividade não muda) o custo acompanha a distância real
func _triangular(malha: NavigationPolygon) -> NavigationPolygon:
	var triangulos := NavigationPolygon.new()
	triangulos.agent_radius = malha.agent_radius
	triangulos.set_vertices(malha.get_vertices())
	for k in malha.get_polygon_count():
		var poligono := malha.get_polygon(k)
		for m in range(1, poligono.size() - 1):
			triangulos.add_polygon(PackedInt32Array([poligono[0], poligono[m], poligono[m + 1]]))
	return triangulos

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
