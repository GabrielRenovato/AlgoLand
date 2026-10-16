extends Control

const DesenhoBarra := preload("res://codigo/ui/desenho_barra.gd")

## Branco mantém o vermelho do pack; outra cor tinge as peças (ex.: amarelo da stamina)
@export var cor := Color.WHITE

var _fracao := 1.0
var _fracao_rastro := 1.0
var _tween_rastro: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func definir(atual: float, maximo: float, animar_rastro := true) -> void:
	var nova := clampf(atual / maxf(maximo, 1.0), 0.0, 1.0)
	if _tween_rastro:
		_tween_rastro.kill()
	if animar_rastro and nova < _fracao:
		# O rastro claro espera um instante e desce: mostra o tamanho do golpe
		_tween_rastro = create_tween()
		_tween_rastro.tween_interval(0.25)
		_tween_rastro.tween_method(_definir_rastro, _fracao_rastro, nova, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		_fracao_rastro = nova
	_fracao = nova
	queue_redraw()

func _definir_rastro(valor: float) -> void:
	_fracao_rastro = valor
	queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(32, DesenhoBarra.ALTURA)

func _draw() -> void:
	DesenhoBarra.desenhar(self, Vector2.ZERO, int(size.x), _fracao, _fracao_rastro, cor)
