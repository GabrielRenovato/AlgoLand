extends Node2D
## Canalização em pixels do mapa, sem ampliar texturas do personagem.
var origem := Vector2.ZERO
var destino := Vector2.ZERO
var tempo := 0.0
var impacto := -1.0

func _ready() -> void:
	add_to_group("espelhos_coop")

func espelho() -> Dictionary:
	return {"k": "canal", "o": [origem.x, origem.y], "d": [destino.x, destino.y], "t": snappedf(tempo, 0.01), "f": snappedf(impacto, 0.01)}

func atualizar(inicio: Vector2, fim: Vector2, relogio: float, fase := -1.0) -> void:
	origem = inicio.round()
	destino = fim.round()
	tempo = relogio
	impacto = fase
	queue_redraw()

func _draw() -> void:
	var forca := clampf(tempo / 0.35, 0.0, 1.0)
	if impacto >= 0:
		forca = maxf(0, 1.0 - impacto * 4.0)
	var lateral := (destino - origem).normalized().orthogonal()
	var ponta := origem.lerp(destino, clampf(tempo / 0.45, 0, 1))
	var pontos := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pontos.append((origem.lerp(ponta, t) + lateral * sin(t * TAU * 2 + tempo * 15) * sin(t * PI) * 3).round())
	if forca > 0:
		draw_polyline(pontos, Color(0.13, 0.38, 0.29, 0.65 * forca), 5, false)
		draw_polyline(pontos, Color(0.57, 0.95, 0.59, 0.9 * forca), 1, false)
		for i in 12:
			var t := fposmod(i / 12.0 + tempo * 0.7, 1.0)
			var ponto := origem.lerp(ponta, t) + lateral * sin(i * 2.4 + tempo * 7) * 7
			draw_rect(Rect2(ponto.round(), Vector2(2, 2)), Color(0.85, 0.90, 0.53, forca))
		draw_line(origem - Vector2(5, 0), origem + Vector2(5, 0), Color(0.83, 1, 0.63, forca), 1, false)
