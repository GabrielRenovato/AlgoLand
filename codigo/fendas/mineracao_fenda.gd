extends "res://codigo/logica/mineracao_arena.gd"

var _atualizacao_pendente := false

func preparar_onda(onda: int) -> void:
	var tinha_veios := not _veios.is_empty()
	await super.preparar_onda(onda)
	if tinha_veios or not _veios.is_empty(): _pedir_atualizacao()

func _impacto(jogador: Node, acao: String, ponto: Vector2) -> void:
	var quantidade := _veios.size()
	super._impacto(jogador,acao,ponto)
	if _veios.size()!=quantidade: _pedir_atualizacao()

func _pedir_atualizacao() -> void:
	if _atualizacao_pendente: return
	_atualizacao_pendente = true
	_atualizar_navegacao.call_deferred()

func _atualizar_navegacao() -> void:
	# Esperar a liberação das pedras antigas e a sincronização das novas bases.
	await get_tree().physics_frame
	_atualizacao_pendente = false
	var navegacao := get_parent().get_node_or_null("Terrains/Navegacao")
	if navegacao: navegacao.atualizar_mineracao(self)

## Conserva o rendimento da arena; distribui os veios pelo chão livre do andar inteiro.
func _posicao_livre(rng: RandomNumberGenerator, registros: Array) -> Vector2:
	var terreno: Node2D = get_parent().get_node("Terrains")
	var dados: Dictionary = preload("res://codigo/fendas/catalogo_andares.gd").dados(_gerenciador.onda_atual)
	var limites: Array = dados.limites
	var mapa := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(mapa)==0: return Vector2.INF
	var forma := CircleShape2D.new()
	forma.radius = 36
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 96
	for tentativa in 400:
		var local := Vector2(rng.randf_range(limites[0]+40,limites[0]+limites[2]-40),rng.randf_range(limites[1]+40,limites[1]+limites[3]-40)).snapped(Vector2(16,16))
		var ponto := terreno.to_global(local)
		if NavigationServer2D.map_get_closest_point(mapa,ponto).distance_to(ponto)>2: continue
		if terreno.get_node("Chegada_portal").global_position.distance_to(ponto)<96: continue
		if terreno.get_node("ClareiraGuardiao").global_position.distance_to(ponto)<100: continue
		if registros.any(func(r): return Vector2(r.x,r.y).distance_to(ponto)<80): continue
		var ocupado := false
		for grupo in ["jogadores","enemy"]:
			for parte in get_tree().get_nodes_in_group(grupo):
				if parte is Node2D and parte.get_world_2d()==get_world_2d() and parte.global_position.distance_to(ponto)<64:
					ocupado = true
		if ocupado: continue
		consulta.transform = Transform2D(0,ponto)
		if get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty(): return ponto
	return Vector2.INF
