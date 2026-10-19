extends Node2D

## Sala opcional no mesmo mundo: preserva a população, o guardião e o progresso do andar de origem.
const Premios := preload("res://codigo/fendas/premios_tesouro.gd")
const Portal := preload("res://codigo/fendas/portal_tesouro.gd")
const TERRENO := preload("res://cenas/fendas/terreno_01.tscn")
const Drop := preload("res://codigo/logica/equipamento_drop.gd")
const MIMICO := preload("res://cenas/inimigos/mimico.tscn")
const GIGANTE := preload("res://cenas/fendas/bau_gigante.tscn")
const ORIGEM_SALA := Vector2(12000, 0)
var gerente: Node
var ativo := false
var portal: Node2D
var sala: Node2D
var vivos: Array[Node2D] = []
var total_inimigos := 0
var _retornos: Dictionary = {}
var _suspensos: Dictionary = {}
var _troca := false
var _rng := RandomNumberGenerator.new()
var _andar := 1
var _gerente_processava := false
var _ambiente_anterior := false
var _clima_anterior := 0
var _particulas_visiveis := true

func preparar() -> void:
	_andar = gerente.onda_atual
	var chave := str(_andar)
	if not Progresso.portais_tesouro.has(chave):
		Progresso.portais_tesouro[chave] = "disponivel" if _rng.randf() < Premios.CHANCE_PORTAL else "ausente"
	if Progresso.portais_tesouro[chave] != "disponivel": return
	var terreno := get_parent().get_node("Terrains")
	var entrada: Vector2 = terreno.get_node("Chegada_portal").global_position
	var mapa: RID = get_world_2d().navigation_map
	var ponto := Vector2.INF
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 16
	consulta.shape = forma
	consulta.collision_mask = 64
	for deslocamento in [Vector2(40, 64), Vector2(-48, 72), Vector2(80, 16), Vector2(0, 96), Vector2(-96, 32)]:
		var candidato := NavigationServer2D.map_get_closest_point(mapa, entrada + deslocamento)
		if candidato.distance_to(entrada) < 42: continue
		consulta.transform = Transform2D(0, candidato)
		if get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			ponto = candidato
			break
	if not ponto.is_finite(): return
	portal = Portal.new()
	portal.name = "PortalDoTesouro"
	portal.estacoes = terreno.get_node("Estacoes")
	portal.destino = entrar
	portal.permitido = pode_entrar
	portal.position = to_local(ponto)
	add_child(portal)
	get_tree().call_group("hud", "anunciar", "PORTAL DO TESOURO", "UMA PASSAGEM PARA OS MIMICOS APARECEU", 3.0)

func pode_entrar() -> bool:
	return Progresso.portais_tesouro.get(str(_andar), "") == "disponivel" and not ativo and not _troca and not Transicao.ocupada and not gerente.ondas_paradas and gerente.etapa in [gerente.Etapa.EXPLORANDO, gerente.Etapa.GUARDIAO, gerente.Etapa.CONCLUIDO]

func _ready() -> void:
	_rng.randomize()

func entrar() -> void:
	if not pode_entrar(): return
	_troca = true
	Transicao.ocupada = true
	await Transicao.escurecer()
	Progresso.portais_tesouro[str(_andar)] = "consumido"
	ativo = true
	portal.hide()
	_gerente_processava = gerente.is_physics_processing()
	gerente.set_physics_process(false)
	var estacoes: Node = get_parent().get_node("Terrains/Estacoes")
	_ambiente_anterior = estacoes.ambiente_interno
	_clima_anterior = estacoes.meteorologia.clima_atual
	_particulas_visiveis = estacoes.get_node("Clima").visible
	estacoes.ambiente_interno = true
	estacoes.meteorologia.definir_clima(0, true)
	estacoes.get_node("Clima").hide()
	# Os inimigos originais, incluindo habilidades e lacaios, aguardam a volta.
	for inimigo in get_tree().get_nodes_in_group("enemy"):
		if not get_parent().is_ancestor_of(inimigo): continue
		_suspensos[inimigo] = inimigo.process_mode
		inimigo.process_mode = Node.PROCESS_MODE_DISABLED
	_montar_sala()
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if jogador.get_world_2d() != get_world_2d(): continue
		var camera: Camera2D = jogador.camera
		_retornos[jogador] = {"posicao": jogador.global_position, "camera": [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]}
		jogador.global_position = sala.get_node("Chegada_portal").global_position + Vector2(32 + (_retornos.size() - 1) * 24, 8)
		jogador.velocity = Vector2.ZERO
		camera.limit_left = int(ORIGEM_SALA.x) - 640
		camera.limit_top = -448
		camera.limit_right = int(ORIGEM_SALA.x) + 640
		camera.limit_bottom = 448
		camera.reset_smoothing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)
	_montar_inimigos()
	gerente.progresso_andar_alterado.emit()
	get_tree().call_group("hud", "anunciar", "BOSQUE DO TESOURO", "OURO EXTRA / BAU GIGANTE: 5% DE PREMIO LENDARIO", 4.0)
	await Transicao.clarear()
	Transicao.ocupada = false
	_troca = false

func _montar_sala() -> void:
	# Reutiliza o terreno de andar, com vegetação, bordas, colisões e três classes de navegação sazonais.
	sala = TERRENO.instantiate()
	sala.name = "BosqueDoTesouro"
	sala.position = ORIGEM_SALA
	sala.set_as_top_level(true)
	add_child(sala)
	sala.global_position = ORIGEM_SALA
	var estacoes: Node = get_parent().get_node("Terrains/Estacoes")
	sala.get_node("Estacoes").definir_estacao(estacoes.estacao_atual, true)
	if not estacoes.estacao_mudou.is_connected(_atualizar_sala):
		estacoes.estacao_mudou.connect(_atualizar_sala)
	var retorno := Portal.new()
	retorno.name = "PortalDeRetorno"
	retorno.position = sala.get_node("Chegada_portal").position
	retorno.estacoes = sala.get_node("Estacoes")
	retorno.destino = sair
	retorno.permitido = func(): return ativo and not _troca
	sala.add_child(retorno)

func _montar_inimigos() -> void:
	var quantidade := mini(6 + _andar / 3, 12)
	var grupos: Array[Node] = sala.get_node("GruposCombate").get_children()
	var usados: Array[Vector2] = []
	for i in quantidade:
		var mimico := MIMICO.instantiate() as Node2D
		var grupo: Node2D = grupos[i % grupos.size()]
		var alvo := grupo.global_position + Vector2.from_angle(i * 2.4) * 32
		var ponto := _ponto_livre(alvo, usados)
		usados.append(ponto)
		mimico.position = sala.to_local(ponto)
		mimico.vida = roundi(45 * gerente.multiplicador_vida_inimigo)
		mimico.dano = 6 * gerente.multiplicador_dano_inimigo
		mimico.velocidade = 42
		sala.add_child(mimico)
		vivos.append(mimico)
		mimico.inimigo_morreu.connect(_premiar.bind(mimico, false))
	var gigante := GIGANTE.instantiate() as Node2D
	gigante.position = sala.get_node("ClareiraGuardiao").position
	gigante.tornar_chefe("BAU GIGANTE", 1.8, 1.0)
	gigante.vida = roundi((350 + _andar * 35) * gerente.multiplicador_vida_inimigo)
	gigante.dano = 10 * gerente.multiplicador_dano_inimigo
	gigante.velocidade = 28
	gigante.recompensa_chefe = 0
	sala.add_child(gigante)
	vivos.append(gigante)
	gigante.inimigo_morreu.connect(_premiar.bind(gigante, true))
	total_inimigos = vivos.size()

func _atualizar_sala(indice: int) -> void:
	if is_instance_valid(sala): sala.get_node("Estacoes").definir_estacao(indice, true)

func _ponto_livre(alvo: Vector2, usados: Array[Vector2]) -> Vector2:
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 14
	consulta.shape = forma
	consulta.collision_mask = 64
	var mapa: RID = get_world_2d().navigation_map
	for i in 24:
		var candidato := NavigationServer2D.map_get_closest_point(mapa, alvo + Vector2.from_angle(i * 2.4) * (i / 6) * 20)
		consulta.transform = Transform2D(0, candidato)
		if usados.any(func(outro): return outro.distance_to(candidato) < 34): continue
		if get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty(): return candidato
	return NavigationServer2D.map_get_closest_point(mapa, alvo)

func _premiar(inimigo: Node2D, gigante: bool) -> void:
	if not ativo or not vivos.has(inimigo): return
	vivos.erase(inimigo)
	gerente.progresso_andar_alterado.emit()
	var ouro: int = 100 + _andar * 20 if gigante else gerente.ouro_por_abate(_andar) * Premios.MULT_OURO_MIMICO
	DadosJogo.adicionar_moedas(gerente._aplicar_saque(float(ouro)))
	Progresso.registrar_abate()
	if gigante:
		preload("res://codigo/logica/drops_forja.gd").soltar_material("fragmento", preload("res://codigo/fendas/ritmo_andares.gd").fragmentos_tesouro(_andar), inimigo.global_position, sala)
		var premio := Premios.sortear_premio(_rng, _andar)
		if premio != null:
			Drop.soltar_item(premio, inimigo.global_position, sala, _rng)
			get_tree().call_group("hud", "anunciar", "TESOURO LENDARIO", "O BAU REVELOU UMA PECA DE CONJUNTO", 3.0)
	if vivos.is_empty():
		Progresso.bonus_concluidos += 1
		get_tree().call_group("hud", "anunciar", "TESOURO CONCLUIDO", "VOLTE PELO PORTAL AZUL", 3.0)

func sair() -> void:
	if not ativo or _troca or Transicao.ocupada: return
	_troca = true
	Transicao.ocupada = true
	await Transicao.escurecer()
	_restaurar()
	await Transicao.clarear()
	Transicao.ocupada = false
	_troca = false

func _restaurar() -> void:
	ativo = false
	for jogador in _retornos:
		if not is_instance_valid(jogador): continue
		jogador.global_position = _retornos[jogador].posicao
		jogador.velocity = Vector2.ZERO
		var limites: Array = _retornos[jogador].camera
		jogador.camera.limit_left = limites[0]
		jogador.camera.limit_top = limites[1]
		jogador.camera.limit_right = limites[2]
		jogador.camera.limit_bottom = limites[3]
		jogador.camera.reset_smoothing()
	# Não perder um prêmio que ficou no chão por falta de espaço na mochila.
	for drop in get_tree().get_nodes_in_group("equipamento_drop"):
		if not is_instance_valid(sala) or not sala.is_ancestor_of(drop): continue
		drop.reparent(get_parent())
		drop.preparar_pulo(portal.global_position, portal.global_position)
		drop.atrair()
	_retornos.clear()
	for no in _suspensos:
		if is_instance_valid(no): no.process_mode = _suspensos[no]
	_suspensos.clear()
	gerente.set_physics_process(_gerente_processava)
	var estacoes: Node = get_parent().get_node("Terrains/Estacoes")
	estacoes.ambiente_interno = _ambiente_anterior
	estacoes.meteorologia.definir_clima(_clima_anterior, true)
	estacoes.get_node("Clima").visible = _particulas_visiveis
	get_tree().call_group("hud", "esconder_chefe")
	if is_instance_valid(gerente.guardiao) and gerente.etapa == gerente.Etapa.GUARDIAO:
		get_tree().call_group("hud", "mostrar_chefe", gerente.guardiao.nome_chefe, gerente.guardiao.vida, gerente.guardiao.vida_maxima)
	if is_instance_valid(sala): sala.queue_free()
	vivos.clear()
	gerente.progresso_andar_alterado.emit()
