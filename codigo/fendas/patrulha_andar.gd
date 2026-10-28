extends Node

## Patrulha local pelos caminhos reais enquanto o grupo não entrou em combate.
## A IA normal assume ao avistar o jogador ou receber dano. Nenhum teleporte.
var inimigo: CharacterBody2D
var gerente: Node
var origem := Vector2.ZERO
var _tempo := 0.0
var _espera := 0.0
var _rota_ativa := false
var _rng := RandomNumberGenerator.new()
var _suspensa := false
var _modo_animacao := Node.PROCESS_MODE_INHERIT

func _retomar_animacao() -> void:
	if not _suspensa:return
	_suspensa=false
	if is_instance_valid(inimigo) and is_instance_valid(inimigo.arvore_animacao):
		inimigo.arvore_animacao.process_mode=_modo_animacao

func _exit_tree() -> void:
	_retomar_animacao()

func _ready() -> void:
	inimigo = get_parent()
	origem = inimigo.global_position
	_rng.seed = hash(str(origem,inimigo.scene_file_path))
	_espera = _rng.randf_range(.05,.7)

func _physics_process(delta: float) -> void:
	if inimigo.esta_morto:
		inimigo.set_physics_process(true)
		queue_free()
		return
	if not is_instance_valid(gerente) or gerente.etapa!=gerente.Etapa.EXPLORANDO:
		return
	inimigo._atualizar_efeitos(delta)
	if inimigo.esta_morto: return
	inimigo._atualizar_ordem_desenho()
	if inimigo.esta_congelado():
		inimigo.velocity = Vector2.ZERO
		return
	if (inimigo.esta_recuando or inimigo._atordoado>0) and inimigo.get("parado")!=true:
		inimigo._atordoado = maxf(0,inimigo._atordoado-delta)
		inimigo.velocity = inimigo.velocity.move_toward(Vector2.ZERO,inimigo.desaceleracao_knockback*delta)
		inimigo.move_and_slide()
		return
	# Fora das duas câmeras, conserva a posição e os estados de dano. Sem rotas
	# ou passos acumulados: retoma antes de entrar na tela, sem teleportar.
	if not gerente.patrulha_proxima(inimigo):
		if not _suspensa:
			_suspensa=true
			if inimigo.arvore_animacao:
				_modo_animacao=inimigo.arvore_animacao.process_mode
				inimigo.arvore_animacao.process_mode=Node.PROCESS_MODE_DISABLED
		inimigo.velocity=Vector2.ZERO
		_rota_ativa=false
		return
	_retomar_animacao()
	# Inimigos configurados como enraizados preservam sua identidade de emboscada.
	if inimigo.get("parado")==true:
		if inimigo.has_method("_animar"): inimigo._animar(delta)
		return
	_tempo -= delta
	_espera -= delta
	var agente: NavigationAgent2D = inimigo._agente
	if _tempo<=0:
		_rota_ativa = false
		_tempo = _rng.randf_range(3.0,5.0)
	if not _rota_ativa and _espera<=0:
		_escolher_destino(agente)
	var desejada := Vector2.ZERO
	if _rota_ativa and agente!=null:
		if agente.is_navigation_finished():
			_rota_ativa = false
			_espera = _rng.randf_range(.3,.8)
		else:
			desejada = (agente.get_next_path_position()-inimigo._centro_de_navegacao()).normalized()*inimigo.velocidade*.55
	elif _rota_ativa:
		desejada = (Vector2(inimigo.get_meta("destino_patrulha"))-inimigo.global_position).normalized()*inimigo.velocidade*.55
		if inimigo.global_position.distance_to(inimigo.get_meta("destino_patrulha"))<8: _rota_ativa=false
	inimigo.velocity = inimigo.velocity.move_toward(desejada,inimigo.aceleracao*delta)
	if inimigo.velocity.length()>1: inimigo.definir_direcao_animacao(inimigo.velocity)
	inimigo.move_and_slide()
	if inimigo.has_method("_animar"): inimigo._animar(delta)
	if inimigo.get_slide_collision_count()>0:
		_rota_ativa = false
		_espera = .4

func _escolher_destino(agente: NavigationAgent2D) -> void:
	var mapa := inimigo.get_world_2d().navigation_map
	var camada: int = 1 << inimigo.classe_de_navegacao()
	for tentativa in 10:
		if not gerente.reservar_rota_patrulha():
			_espera=_rng.randf_range(.04,.10)
			return
		var candidato := origem+Vector2.from_angle(_rng.randf_range(0,TAU))*_rng.randf_range(45,115)
		var rota := NavigationServer2D.map_get_path(mapa,inimigo._centro_de_navegacao() if agente!=null else inimigo.global_position,candidato,true,camada)
		if rota.is_empty() or rota[-1].distance_to(candidato)>8: continue
		var comprimento := 0.0
		for i in range(1,rota.size()): comprimento += rota[i-1].distance_to(rota[i])
		if comprimento>240 or comprimento<24: continue
		if agente!=null: agente.target_position=rota[-1]
		inimigo.set_meta("destino_patrulha",rota[-1])
		_rota_ativa = true
		return
	_espera = .8
