extends Node2D

## Travessa, pão, tigela e caneca, na grade de pixels do mobiliário.
var porcao := 1.0
func _draw() -> void:
	draw_rect(Rect2(-7, -2, 14, 4), Color("875635"))
	draw_rect(Rect2(-6, -3, 6, 3), Color("ead5aa"))
	if porcao > 0:
		draw_rect(Rect2(-5, -4, maxi(1, int(4 * porcao)), 2), Color("bc8548"))
	draw_rect(Rect2(1, -5, 4, 5), Color("d0b88a"))
	draw_rect(Rect2(5, -4, 2, 3), Color("d0b88a"), false, 1)
	draw_rect(Rect2(2, -5, 2, 1), Color("62432c"))
