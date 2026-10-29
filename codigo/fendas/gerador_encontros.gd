extends "res://codigo/logica/slime_spawner.gd"

## Distribuição estável no chão navegável. Nenhum surgimento contínuo em cima do jogador.
const Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
var PLANTA: Dictionary
const DISTANCIA_ENTRADA := 140.0
var _populacao: Array[Node2D] = []
var _pontos: Array[Vector2] = []

func limpar_populacao() -> void:
	for inimigo in _populacao:
		if is_instance_valid(inimigo):
			inimigo.set_physics_process(false)
			inimigo.queue_free()
	_populacao.clear()

func _posicoes_livres() -> Array[Vector2]:
	var resultado: Array[Vector2] = []
	var terreno: Node2D = principal.get_node("Terrains")
	var mapa := get_world_2d().navigation_map
	var entrada: Vector2 = terreno.get_node("Chegada_portal").global_position
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	# O esqueleto mutante leva o centro do colisor 24,8 px abaixo da origem,
	# mais 9,3 px de raio. A folga antiga de 25 permitia nascer dentro da margem.
	forma.radius = 36
	consulta.shape = forma
	consulta.collision_mask = 96
	var deslocamentos: Array[Vector2] = [Vector2.ZERO]
	for y in range(-84,85,28):
		for x in range(-84,85,28):
			var deslocamento := Vector2(x,y)
			if deslocamento.length()<=110 and deslocamento!=Vector2.ZERO:
				deslocamentos.append(deslocamento)
	deslocamentos.sort_custom(func(a,b): return a.length_squared()<b.length_squared())
	# Consulta apenas os pontos de encontro desenhados na planta, sem varrer o mapa inteiro.
	for grupo in terreno.get_node("GruposCombate").get_children():
		for deslocamento in deslocamentos:
			var ponto: Vector2 = grupo.global_position + deslocamento
			if ponto.distance_to(entrada) < DISTANCIA_ENTRADA: continue
			if resultado.any(func(outro): return outro.distance_to(ponto)<22): continue
			if NavigationServer2D.map_get_closest_point(mapa,ponto).distance_to(ponto)>2: continue
			consulta.transform = Transform2D(0,ponto)
			if not get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty(): continue
			resultado.append(ponto)
	return resultado

func montar_populacao(geracao: int) -> int:
	PLANTA = Catalogo.dados(gerenciador_ondas.onda_atual)
	_pontos = _posicoes_livres()
	var terreno: Node2D = principal.get_node("Terrains")
	var usados: Array[Vector2] = []
	for grupo in terreno.get_node("GruposCombate").get_children():
		var perto := _pontos.duplicate()
		perto.sort_custom(func(a,b): return a.distance_squared_to(grupo.global_position)<b.distance_squared_to(grupo.global_position))
		var tamanho: int = int(PLANTA.combate.comuns_por_grupo) + (1 if grupo.get_meta("elite",false) else 0)
		var criados := 0
		for ponto in perto:
			if criados >= tamanho: break
			if ponto.distance_to(grupo.global_position)>110 or usados.has(ponto): continue
			usados.append(ponto)
			var elite: bool = grupo.get_meta("elite",false) and criados == 0
			var especies := obter_pool_especies(gerenciador_ondas.onda_atual)
			var cena: PackedScene = especies[criados % especies.size()]
			if PLANTA.bioma.begins_with("caverna") and criados == 2: cena = CENA_MORCEGO
			var inimigo := _criar(cena,ponto,geracao,int(PLANTA.combate.pontos_elite if elite else PLANTA.combate.pontos_comum),false)
			inimigo.set_meta("grupo_andar",grupo.name)
			if elite:
				inimigo.tornar_mutante()
				inimigo.set_meta("elite_andar",true)
				if inimigo.has_node("HPBar"):
					inimigo.get_node("HPBar").vida_maxima = inimigo.vida
					inimigo.get_node("HPBar").definir_vida_atual(inimigo.vida)
			gerenciador_ondas.registrar_inimigo_adormecido(inimigo)
			criados += 1
	return usados.size()

func _criar(cena: PackedScene, ponto: Vector2, geracao: int, valor: int, chefe: bool) -> Node2D:
	var inimigo := cena.instantiate() as Node2D
	inimigo.position = principal.to_local(ponto)
	if not chefe:
		inimigo.vida = mini(inimigo.vida,preload("res://codigo/fendas/ritmo_andares.gd").teto_vida_comum(gerenciador_ondas.onda_atual))
	aplicar_atributos(inimigo, gerenciador_ondas.multiplicador_vida_inimigo, gerenciador_ondas.multiplicador_dano_inimigo)
	if chefe:
		if cena == preload("res://cenas/inimigos/cogumelo.tscn"):
			inimigo.tornar_chefe("COGUMELO ANCIAO",2.0,7.0,1.2,"cogumelo",10.0)
		var andar: int = gerenciador_ondas.onda_atual
		inimigo.vida = roundi((180 + 24 * maxi(andar-1,0)) * gerenciador_ondas.multiplicador_vida_inimigo * _mult_evento("vida"))
		inimigo.dano = (9.0 + 0.8 * maxi(andar-1,0)) * gerenciador_ondas.multiplicador_dano_inimigo * _mult_evento("dano")
		inimigo.velocidade = 65
		if Cooperativo.com_dois(): inimigo.vida = roundi(inimigo.vida * Cooperativo.MULT_VIDA_CHEFE_COOP)
		var online := get_tree().root.get_node_or_null("CoopOnline")
		if online != null and online.ativo: inimigo.vida = roundi(inimigo.vida * Cooperativo.MULT_VIDA_CHEFE_COOP)
	principal.add_child(inimigo)
	if chefe:
		inimigo.set_meta("guardiao_aguardando",true)
		inimigo.set_physics_process(false)
	_populacao.append(inimigo)
	inimigo.inimigo_morreu.connect(_concluir_abate.bind(inimigo, valor, chefe, geracao))
	return inimigo

func _concluir_abate(inimigo: Node2D, valor: int, chefe: bool, geracao: int) -> void:
	if geracao != gerenciador_ondas._geracao or gerenciador_ondas.ondas_paradas: return
	var etapa_esperada: int = gerenciador_ondas.Etapa.GUARDIAO if chefe else gerenciador_ondas.Etapa.EXPLORANDO
	if gerenciador_ondas.etapa != etapa_esperada: return
	# Saque nasce antes da conclusão. Mortes simultâneas após encher a barra não duplicam prêmios.
	_soltar_sementes(inimigo)
	_soltar_equipamento(inimigo)
	gerenciador_ondas.ao_abate(inimigo, valor, chefe, geracao)

func ponto_guardiao() -> Vector2:
	# A planta reserva uma clareira sem mobs e sem obstáculos para o confronto final.
	return principal.get_node("Terrains/ClareiraGuardiao").global_position

func criar_guardiao(ponto: Vector2, geracao: int) -> Node2D:
	return _criar(Catalogo.chefe(gerenciador_ondas.onda_atual).cena, ponto, geracao, 0, true)
