extends Node2D

## Veios por onda, compartilhados no mundo; a coleta usa os itens fisicos da mochila.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Drops := preload("res://codigo/logica/drops_forja.gd")
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const PRIMEIRA_ONDA := 6
const INTERVALO := 3
const ONDA_VEIO_RICO := 21
const ALCANCE := 19.0
var _gerenciador: Node
var _veios := {}
var _jogadores := {}
var _pendentes := {}
var _onda := 0
var _geracao := 0
var _estacoes: Node

static func recompensa(onda: int) -> int:
	if onda < PRIMEIRA_ONDA or onda % INTERVALO != 0: return 0
	return 2 if onda >= ONDA_VEIO_RICO else 1

func _ready() -> void:
	add_to_group("mineracao_arena")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gerenciador = get_parent().get_node("enemySpawner/GerenciadorOndas")
	_gerenciador.onda_iniciada.connect(preparar_onda)
	_estacoes = get_parent().get_node_or_null("Terrains/Estacoes")
	if _estacoes != null: _estacoes.estacao_mudou.connect(_trocar_estacao)
	else: Calendario.estacao_mudou.connect(_trocar_estacao)
	_restaurar.call_deferred()

func _restaurar() -> void:
	await get_tree().physics_frame
	if _onda == 0 and _gerenciador != null and Progresso.veios_arena.has(str(_gerenciador.onda_atual)):
		preparar_onda(_gerenciador.onda_atual)

func _physics_process(_delta: float) -> void:
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if not jogador is CharacterBody2D or not jogador.has_method("ponto_acao_fazenda"): continue
		if jogador.get_world_2d() != get_world_2d() or _jogadores.has(jogador.get_instance_id()): continue
		_ligar_jogador(jogador)
	queue_redraw()

func _ligar_jogador(jogador: Node) -> void:
	var id: int = jogador.get_instance_id()
	if _jogadores.has(id): return
	_jogadores[id] = weakref(jogador)
	jogador.acao_fazenda_impacto.connect(_receber_impacto.bind(id))
	jogador.acao_fazenda_concluida.connect(_terminou_acao.bind(id))

func _receber_impacto(acao: String, ponto: Vector2, id: int) -> void:
	var jogador = _jogadores[id].get_ref()
	if jogador != null and jogador.get_world_2d()==get_world_2d(): _impacto(jogador,acao,ponto)

func _terminou_acao(_acao: String, id: int) -> void:
	_pendentes.erase(id)

func preparar_onda(onda: int) -> void:
	_geracao += 1
	var geracao := _geracao
	_onda = onda
	_pendentes.clear()
	for veio in _veios.values(): veio.queue_free()
	_veios.clear()
	if Introducao.ativa() or recompensa(onda) == 0: return
	await get_tree().physics_frame
	if geracao != _geracao: return
	var chave := str(onda)
	if not Progresso.veios_arena.has(chave):
		var registros := []
		var quantidade := 2 if Cooperativo.com_dois() else 1
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in quantidade:
			var ponto := _posicao_livre(rng,registros)
			if ponto == Vector2.INF: continue
			registros.append({"x":ponto.x,"y":ponto.y,"golpes":0,"extraido":false})
		Progresso.veios_arena[chave] = registros
	var registros: Array = Progresso.veios_arena[chave]
	for indice in registros.size():
		if not registros[indice].extraido: _criar_veio(indice,registros[indice])

func _posicao_livre(rng: RandomNumberGenerator, registros: Array) -> Vector2:
	var mapa := get_world_2d().navigation_map
	var forma := CircleShape2D.new()
	forma.radius = 36
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 96
	for tentativa in 120:
		var ponto := Vector2(rng.randi_range(112,512),rng.randi_range(96,352)).snapped(Vector2(16,16))
		if NavigationServer2D.map_get_iteration_id(mapa) == 0: return Vector2.INF
		if NavigationServer2D.map_get_closest_point(mapa,ponto).distance_to(ponto) > 4: continue
		if registros.any(func(r): return Vector2(r.x,r.y).distance_to(ponto)<80): continue
		var chegada := get_parent().get_node("Terrains/Chegada_portal") as Node2D
		if chegada.global_position.distance_to(ponto)<96: continue
		var ocupado := false
		for jogador in get_tree().get_nodes_in_group("jogadores"):
			if not jogador is CharacterBody2D or not jogador.has_method("ponto_acao_fazenda"): continue
			if jogador.get_world_2d()==get_world_2d() and jogador.global_position.distance_to(ponto)<48: ocupado=true
		if ocupado: continue
		consulta.transform = Transform2D(0,ponto)
		if get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty(): return ponto
	return Vector2.INF

func _criar_veio(indice: int, registro: Dictionary) -> void:
	var veio := StaticBody2D.new()
	veio.name = "VeioFerro%d" % indice
	veio.collision_layer = 64
	veio.collision_mask = 0
	add_child(veio)
	veio.global_position = Vector2(registro.x,registro.y)
	veio.z_as_relative = false
	veio.z_index = Profundidade.z_de(veio.global_position.y)-1
	var sprite := Sprite2D.new()
	sprite.name = "Pedra"
	sprite.centered = false
	sprite.position = Vector2(-16,-28)
	veio.add_child(sprite)
	var colisao := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(22,12)
	colisao.shape = forma
	colisao.position.y = -6
	veio.add_child(colisao)
	_veios[indice] = veio
	_trocar_estacao(0)

func _trocar_estacao(_indice: int) -> void:
	var estacao := Calendario.estacao()
	if _estacoes != null and int(_estacoes.estacao_atual)>=0: estacao = int(_estacoes.estacao_atual)
	for veio in _veios.values():
		veio.get_node("Pedra").texture = load("res://assets/cenario/arena/minerios/ferro_%s.png" % ESTACOES[estacao])

func _alvo(ponto: Vector2) -> int:
	var indice := -1
	var distancia := ALCANCE
	for id in _veios:
		var atual: float = ponto.distance_to(_veios[id].global_position-Vector2(0,4))
		if atual<distancia:
			distancia=atual
			indice=id
	return indice

func pedir_golpe(jogador: Node) -> bool:
	if jogador.get_world_2d()!=get_world_2d() or jogador.estaMorto or jogador.caido or jogador.ataques_bloqueados: return false
	if EventosJogo.inventario_de(jogador).buscar_por_tipo("picareta")==null:
		jogador.picareta_arena_ativa=false
		return false
	if jogador.esta_em_acao_fazenda or jogador._esta_atacando or jogador.esta_em_dash or not jogador.movimento_habilitado: return false
	var indice := _alvo(jogador.ponto_acao_fazenda())
	if indice<0:
		_avisar(jogador,"NENHUM VEIO A FRENTE")
		return false
	var lado: int = Fazenda.lado_de(jogador)
	if Fazenda.energia_de(lado)<Fazenda.custo_energia("picareta",lado):
		_avisar(jogador,Fazenda.MSG_SEM_ENERGIA)
		return false
	_ligar_jogador(jogador)
	if not jogador.acao_fazenda("picareta"): return false
	Fazenda.gastar_energia("picareta",lado)
	_pendentes[jogador.get_instance_id()] = indice
	return true

func _impacto(jogador: Node, acao: String, ponto: Vector2) -> void:
	var id: int = jogador.get_instance_id()
	if acao!="picareta" or not _pendentes.has(id): return
	var indice: int = _pendentes[id]
	_pendentes.erase(id)
	if not _veios.has(indice) or _alvo(ponto)!=indice: return
	var registro: Dictionary = Progresso.veios_arena[str(_onda)][indice]
	if registro.extraido: return
	registro.golpes += preload("res://codigo/dados/melhorias_ferramentas.gd").nivel(EventosJogo.inventario_de(jogador),"picareta")
	var veio: StaticBody2D = _veios[indice]
	Sons.tocar("bloqueio",0.05,-3.0)
	if registro.golpes < (4 if recompensa(_onda)==2 else 3):
		var sprite := veio.get_node("Pedra") as Sprite2D
		var tween := create_tween()
		tween.tween_property(sprite,"modulate",Color(1.5,1.4,1.1),0.06)
		tween.tween_property(sprite,"modulate",Color.WHITE,0.12)
		return
	registro.extraido=true
	Drops.soltar_material("ferro",recompensa(_onda),veio.global_position,get_parent())
	_veios.erase(indice)
	veio.queue_free()

func _avisar(jogador: Node, mensagem: String) -> void:
	get_tree().call_group(jogador.grupo_hud(),"avisar_pocao",mensagem)
	Sons.tocar("erro",0,-4)

func _draw() -> void:
	for referencia in _jogadores.values():
		var jogador = referencia.get_ref()
		if jogador==null or jogador.get_world_2d()!=get_world_2d() or not jogador.picareta_arena_ativa: continue
		var indice := _alvo(jogador.ponto_acao_fazenda())
		if indice<0: continue
		var ponto := to_local(_veios[indice].global_position)
		draw_arc(ponto-Vector2(0,4),14,0,TAU,24,Color(1,0.85,0.35,0.8),1)
