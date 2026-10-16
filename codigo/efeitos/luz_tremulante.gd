extends PointLight2D

@export var energia_base: float = 1.0
@export var energia_dia: float = 0.55
@export var intensidade_tremor: float = 0.18
@export var velocidade: float = 1.0
@export_range(0.0, 1.0) var multiplicador_noite: float = 0.0

const TREMOR_REFERENCIA := 0.18
const TREMOR_ESCALA := 0.04

var _ruido := FastNoiseLite.new()
var _escala_base: float
var _tempo := 0.0

func _ready() -> void:
	add_to_group("luzes_noturnas")
	_escala_base = texture_scale
	_ruido.seed = randi()
	_ruido.frequency = 1.0
	_tempo = randf() * 100.0

func _process(delta: float) -> void:
	_tempo += delta * velocidade * 3.0
	var energia := energia_base * lerpf(energia_dia, 1.0, multiplicador_noite)
	energy = maxf(energia + _ruido.get_noise_1d(_tempo) * intensidade_tremor, 0.0)
	# Escala treme em proporção ao tremor de energia; offset no tempo descorrelaciona os dois ruídos
	var proporcao := intensidade_tremor / TREMOR_REFERENCIA
	texture_scale = _escala_base * (1.0 + _ruido.get_noise_1d(_tempo + 37.0) * TREMOR_ESCALA * proporcao)
