extends Node2D

## Vara e boia cosméticas durante o afazer; não concedem itens nem alteram a mochila.
var _tempo := 0.0

func _ready() -> void:
	var vara := Sprite2D.new()
	vara.texture = preload("res://assets/pesca/vara.png")
	vara.position = Vector2(9, -3)
	add_child(vara)

func _process(delta: float) -> void:
	_tempo += delta
	if visible:
		queue_redraw()

func _draw() -> void:
	var boia := Vector2(51, 30 + roundf(sin(_tempo * 2.0)))
	draw_line(Vector2(15, -10), boia, Color(0.95, 0.96, 0.88, 0.65), 1)
	draw_rect(Rect2(boia - Vector2(1, 1), Vector2(2, 3)), Color("d45548"))
