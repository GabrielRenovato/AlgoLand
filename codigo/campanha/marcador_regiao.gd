extends Button

## Ponto de viagem: a paisagem identifica o lugar; o marcador indica seu estado.
var selecionado := false
var disponivel := false
var concluido := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estado in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(estado,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var centro := size/2
	draw_circle(centro+Vector2(0,2),8,Color(0.08,0.16,0.13,0.35))
	draw_circle(centro,7,Color("37534b"))
	draw_circle(centro,5,Color("f5d795") if disponivel else Color("82958a"))
	if concluido:
		draw_polyline(PackedVector2Array([centro+Vector2(-3,0),centro+Vector2(-1,2),centro+Vector2(3,-3)]),Color("315e40"),1.6,true)
	if selecionado or is_hovered():
		draw_arc(centro,9,0,TAU,32,Color("bff5ed"),1.5,true)
	if selecionado:
		var p := Vector2(centro.x,3)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-3,-2),p+Vector2(3,-2),p+Vector2(0,2)]),Color("d9fff2"))
