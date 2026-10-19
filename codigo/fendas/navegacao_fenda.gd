extends "res://codigo/logica/navegacao_arena.gd"

func _ready() -> void:
	# A exploração consulta a malha imediatamente após trocar de andar. Publicar
	# a nova geometria de forma síncrona evita uma iteração vazia nos mapas grandes.
	NavigationServer2D.map_set_use_async_iterations(get_world_2d().navigation_map,false)
	NavigationServer2D.region_set_use_async_iterations(get_rid(),false)
	super()
	_sincronizar.call_deferred()

func _sincronizar() -> void:
	# Os mapas maiores podem terminar o bake enquanto a versão anterior do mapa
	# ainda está no servidor. Publicar também as regiões irmãs antes dos encontros.
	await get_tree().physics_frame
	await get_tree().process_frame
	for i in range(1,RAIOS_AGENTE.size()):
		var regiao := get_parent().get_node_or_null("Navegacao_classe%d" % (i+1)) as NavigationRegion2D
		if regiao: NavigationServer2D.region_set_use_async_iterations(regiao.get_rid(),false)
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)

## Veios surgem após o bake inicial. Incorporar/remover suas bases nas três
## classes impede que a rota dos inimigos atravesse uma pedra física.
func atualizar_mineracao(mineracao: Node) -> void:
	var contorno := get_node_or_null(limite) as CollisionPolygon2D
	if contorno == null: return
	var geometria := NavigationMeshSourceGeometryData2D.new()
	geometria.add_traversable_outline(_para_local(contorno,contorno.polygon))
	for caminho in obstaculos:
		var no := get_node_or_null(caminho)
		if no: _coletar(no,geometria)
	_coletar(mineracao,geometria)
	for i in RAIOS_AGENTE.size():
		var regiao: NavigationRegion2D = self if i==0 else get_parent().get_node_or_null("Navegacao_classe%d" % (i+1))
		if regiao == null: continue
		NavigationServer2D.region_set_use_async_iterations(regiao.get_rid(),false)
		var malha := NavigationPolygon.new()
		malha.agent_radius = RAIOS_AGENTE[i]+folga_adicional
		NavigationServer2D.bake_from_source_geometry_data(malha,geometria)
		regiao.navigation_polygon = _triangular(malha)
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)

## O contorno maior gera vértices quase coincidentes no bake. Unifica na grade de
## meio pixel antes de triangular, dentro da folga de 14–30 px dos agentes.
func _triangular(malha: NavigationPolygon) -> NavigationPolygon:
	var vertices := PackedVector2Array()
	var indices := {}
	var remapeamento := PackedInt32Array()
	for vertice in malha.get_vertices():
		var ponto := vertice.snapped(Vector2(0.5,0.5))
		if not indices.has(ponto):
			indices[ponto] = vertices.size()
			vertices.append(ponto)
		remapeamento.append(indices[ponto])
	var resultado := NavigationPolygon.new()
	resultado.agent_radius = malha.agent_radius
	resultado.set_vertices(vertices)
	for i in malha.get_polygon_count():
		var face := PackedInt32Array()
		for indice in malha.get_polygon(i):
			var novo := remapeamento[indice]
			if not face.has(novo): face.append(novo)
		for j in range(1,face.size()-1):
			var a := vertices[face[0]]
			var b := vertices[face[j]]
			var c := vertices[face[j+1]]
			if absf((b-a).cross(c-a)) < 0.01: continue
			resultado.add_polygon(PackedInt32Array([face[0],face[j],face[j+1]]))
	return resultado
