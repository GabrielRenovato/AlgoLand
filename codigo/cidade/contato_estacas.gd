extends Node2D

## Ondas pequenas na linha de imersão. Ficam sob as estacas e o tablado,
## somente na água; os pilares não recebem colisão por estarem abaixo do piso.
var pontos: PackedVector2Array = []
var _tempo := 0.0

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	for indice in pontos.size():
		for onda in 2:
			var fase := fposmod(_tempo * 0.5 + onda * 0.5 + indice * 0.21, 1.0)
			var raio := 1.4 + fase * 1.2
			draw_set_transform(pontos[indice], 0, Vector2(1, 0.28))
			draw_arc(Vector2.ZERO, raio, 0, TAU, 24, Color(0.64, 0.82, 0.82, (1.0 - fase) * 0.32), 0.5, true)
