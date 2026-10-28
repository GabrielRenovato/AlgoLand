extends Node
## Recupera posições externas em mapas permanentes, preservando viagens e o mundo de cada jogador.
const MAPAS := ["res://cenas/cidade.tscn", "res://cenas/fazenda.tscn", "res://cenas/praia.tscn", "res://cenas/floresta.tscn"]
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ESPERA_FORA := 0.15
var _jogador: CharacterBody2D
var _cena: Node2D
var _ultimo_seguro := Vector2.INF
var _tempo_fora := 0.0
var _tempo_amostra := 0.0

static func atende(cena: Node) -> bool:
	return is_instance_valid(cena) and cena.scene_file_path in MAPAS

static func dentro(cena: Node2D, ponto: Vector2) -> bool:
	return ponto.is_finite() and (cena.get("limites") as Rect2).has_point(cena.to_local(ponto))

static func livre(cena: Node2D, ponto: Vector2, jogador: CharacterBody2D = null) -> bool:
	if not dentro(cena,ponto): return false
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 6.0
	consulta.shape = forma
	consulta.transform = Transform2D(0,ponto+Vector2(0,Profundidade.PES_JOGADOR))
	consulta.collision_mask = jogador.collision_mask if jogador != null else 96
	consulta.collide_with_areas = false
	if jogador != null: consulta.exclude = [jogador.get_rid()]
	return cena.get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty()

static func corrigir(cena: Node2D, ponto: Vector2, jogador: CharacterBody2D = null) -> Vector2:
	if not atende(cena) or dentro(cena,ponto): return ponto
	return retorno_seguro(cena,jogador)

static func retorno_seguro(cena: Node2D, jogador: CharacterBody2D = null, ultimo := Vector2.INF) -> Vector2:
	if ultimo.is_finite() and livre(cena,ultimo,jogador): return ultimo
	# Marcadores conhecidos são pontos de entrada, nas trilhas e junto às portas.
	for nome in ["Chegada_porta","Chegada_fazenda","Chegada_cidade","Chegada_praia","Chegada_entrada"]:
		var marcador := cena.find_child(nome,true,false) as Node2D
		if marcador == null: continue
		for raio in [0.0,16.0,32.0,48.0,64.0]:
			for direcao in [Vector2.ZERO,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
				var candidato: Vector2 = marcador.global_position+direcao*raio
				if livre(cena,candidato,jogador):return candidato
	# Usado apenas se uma cena não possuir marcadores ou todas as entradas estiverem obstruídas.
	var limites: Rect2 = cena.get("limites")
	for y in range(int(limites.position.y)+24,int(limites.end.y)-24,32):
		for x in range(int(limites.position.x)+24,int(limites.end.x)-24,32):
			var candidato := cena.to_global(Vector2(x,y))
			if livre(cena,candidato,jogador):return candidato
	return Vector2.INF

func _ready() -> void:
	name = "SegurancaMapa"
	_jogador = get_parent() as CharacterBody2D
	process_physics_priority = 200

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_jogador): return
	var cena := Cooperativo.cena_de(_jogador) as Node2D
	if not atende(cena):
		_cena = null
		_ultimo_seguro = Vector2.INF
		_tempo_fora = 0.0
		return
	if not is_instance_valid(_cena) or _cena != cena:
		_cena = cena
		_ultimo_seguro = Vector2.INF
		_tempo_fora = 0.0
		_tempo_amostra = 0.0
	# A porta pode ter retirado o personagem da cena antes de posicioná-lo no outro ambiente.
	if Transicao.ocupada or Cooperativo._viajando.get(2 if _jogador.eh_p2 else 1,false):
		_tempo_fora = 0.0
		return
	if dentro(cena,_jogador.global_position):
		_tempo_fora = 0.0
		_tempo_amostra -= delta
		if _tempo_amostra <= 0.0:
			_tempo_amostra = .25
			if (cena.get("limites") as Rect2).grow(-16).has_point(cena.to_local(_jogador.global_position)) and livre(cena,_jogador.global_position,_jogador):
				_ultimo_seguro = _jogador.global_position
		return
	_tempo_fora += delta
	if _tempo_fora < ESPERA_FORA:return
	var destino := retorno_seguro(cena,_jogador,_ultimo_seguro)
	if not destino.is_finite():return
	_jogador.global_position = destino
	_jogador.velocity = Vector2.ZERO
	_jogador.esta_em_dash = false
	var camera := _jogador.get_viewport().get_camera_2d()
	if camera != null:camera.reset_smoothing()
	if _jogador.camera != null and _jogador.camera != camera:_jogador.camera.reset_smoothing()
	_ultimo_seguro = destino
	_tempo_fora = 0.0
	Saves.salvar_tudo.call_deferred()
