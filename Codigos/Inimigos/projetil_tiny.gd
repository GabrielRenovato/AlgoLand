extends Area2D

const Indicador := preload("res://Codigos/Efeitos/indicador_ataque.gd")
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
const VELOCIDADE := 125.0
const DURACAO := 2.5
const TEMPO_BOMBA := 0.9
const RAIO_BOMBA := 32.0

var tipo := "flecha"
var dano: int = 0
var alvo: Node2D
var origem := Vector2.ZERO
var destino := Vector2.ZERO
var _rumo := Vector2.RIGHT
var _tempo := 0.0
var _atingiu := false
var _indicador: Node2D

func _ready() -> void:
	top_level = true
	global_position = origem
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y)
	collision_layer = 0
	collision_mask = 66 # AreaDano do jogador (2) e obstáculos do mundo (64).
	_rumo = (destino - origem).normalized()
	if tipo in ["bomba", "esporos"]:
		monitoring = false
		_indicador = Indicador.new()
		add_child(_indicador)
		_indicador.configurar(destino, RAIO_BOMBA)
	else:
		var forma := CircleShape2D.new()
		forma.radius = 3.0
		var colisao := CollisionShape2D.new()
		colisao.shape = forma
		add_child(colisao)
		area_entered.connect(_ao_entrar_area)
		body_entered.connect(func(_corpo): queue_free())
	queue_redraw()

func _physics_process(delta: float) -> void:
	_tempo += delta
	if _atingiu:
		return
	if not is_instance_valid(alvo):
		queue_free()
		return
	if tipo in ["bomba", "esporos"]:
		var progresso := minf(_tempo / TEMPO_BOMBA, 1.0)
		global_position = origem.lerp(destino, progresso)
		_indicador.atualizar_progresso(progresso)
		queue_redraw()
		if progresso >= 1.0:
			_atingiu = true
			if alvo.global_position.distance_to(destino) <= RAIO_BOMBA:
				_dar_dano()
			_indicador.detonar_impacto()
			await get_tree().create_timer(0.3).timeout
			queue_free()
	else:
		global_position += _rumo * VELOCIDADE * delta
		if _tempo >= DURACAO:
			queue_free()
	z_index = Profundidade.z_de(global_position.y)

func _ao_entrar_area(area: Area2D) -> void:
	if _atingiu or not is_instance_valid(alvo) or area.get_parent() != alvo:
		return
	_atingiu = true
	_dar_dano()
	queue_free()

func _dar_dano() -> void:
	if is_instance_valid(alvo):
		alvo.receber_dano(dano, (alvo.global_position - global_position).normalized() * 100.0)

func _draw() -> void:
	if _atingiu:
		return
	match tipo:
		"flecha":
			draw_line(-_rumo * 6.0, _rumo * 6.0, Color(0.7, 0.45, 0.2), 2.0)
			draw_line(_rumo * 6.0, _rumo * 2.0 + _rumo.orthogonal() * 3.0, Color.WHITE, 2.0)
			draw_line(_rumo * 6.0, _rumo * 2.0 - _rumo.orthogonal() * 3.0, Color.WHITE, 2.0)
		"espinho":
			draw_circle(Vector2.ZERO, 3.0, Color(0.7, 0.9, 0.3))
		"bomba":
			var altura := -sin(minf(_tempo / TEMPO_BOMBA, 1.0) * PI) * 28.0
			draw_circle(Vector2(0, altura), 4.0, Color(0.2, 0.2, 0.25))
			draw_circle(Vector2(1, altura - 4), 1.5, Color(1.0, 0.65, 0.1))
