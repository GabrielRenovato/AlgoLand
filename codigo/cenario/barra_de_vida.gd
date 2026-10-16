extends Node2D

## Tempo visível depois do último dano; com vida cheia a barra fica escondida
const TEMPO_VISIVEL := 2.5

@export var vida_maxima: int = 30
var vida_atual: int = vida_maxima

@onready var barra: Control = $Barra

var _tween_visivel: Tween

func _ready() -> void:
	modulate.a = 0.0
	definir_vida_atual(vida_maxima)

func definir_vida_atual(valor: int) -> void:
	vida_atual = clampi(valor, 0, vida_maxima)
	barra.definir(vida_atual, vida_maxima, false)

func atualizar_barra(nova_vida: int) -> void:
	vida_atual = clampi(nova_vida, 0, vida_maxima)
	barra.definir(vida_atual, vida_maxima)
	if _tween_visivel:
		_tween_visivel.kill()
	modulate.a = 1.0
	if vida_atual <= 0:
		return
	_tween_visivel = create_tween()
	_tween_visivel.tween_interval(TEMPO_VISIVEL)
	_tween_visivel.tween_property(self, "modulate:a", 0.0, 0.4)
