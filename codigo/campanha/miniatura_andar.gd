extends Button

## Lugar em miniatura: área clicável transparente, sem transformar o andar em cartão.
var imagem: Texture2D
var numero := 1
var selecionada := false
var revelada := true
var reliquia: SubViewport

func _ready() -> void:
	reliquia = preload("res://codigo/campanha/reliquia_tabuleiro.gd").new()
	add_child(reliquia)
	imagem = reliquia.get_texture()
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estado in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(estado,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if imagem != null:
		var sombra := PackedVector2Array()
		for i in 33:
			sombra.append(Vector2(size.x*0.5,size.y*0.81)+Vector2(cos(i*TAU/32)*size.x*0.19,sin(i*TAU/32)*size.y*0.045))
		draw_colored_polygon(sombra,Color(0.22,0.14,0.04,0.25))
		var origem := Vector2(imagem.get_size())
		var margem := minf(size.x,size.y)*0.01
		var disponivel := size-Vector2.ONE*margem*2
		var fator := minf(disponivel.x/origem.x,disponivel.y/origem.y)
		var exibida := origem*fator
		var cor := Color.WHITE if revelada else Color(0.3,0.42,0.43,0.72)
		draw_texture_rect(imagem,Rect2((size-exibida)/2,exibida),false,cor)
