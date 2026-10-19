extends Control

## Pequenos pontos de luz na camada da interface, sem alterar o cenario.
var _tempo := 0.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_tempo += delta
	queue_redraw()
func _draw() -> void:
	for i in 18:
		var x := fposmod(i*0.618+sin(_tempo*0.12+i)*0.03,1.0)*size.x
		var y := fposmod(i*0.237-_tempo*0.008,1.0)*size.y
		var brilho := 0.10+0.22*pow(maxf(0,sin(_tempo*1.1+i*1.7)),2)
		draw_rect(Rect2(Vector2(floorf(x),floorf(y)),Vector2.ONE),Color(1,0.85,0.45,brilho))
