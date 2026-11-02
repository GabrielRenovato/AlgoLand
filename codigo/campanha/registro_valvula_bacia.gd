extends Node2D
## Registro apoiado num pedestal; apenas a manivela muda de posição.
var estado := 0
var estacao := 0
func _ready() -> void:
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(position.y)
	queue_redraw()
func definir_estado(valor: int) -> void:
	estado = valor
	queue_redraw()
func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(-8,0),Vector2(5,0),Vector2(9,-4),Vector2(-4,-4)]),PackedColorArray([Color("a3aa9b")]))
	draw_rect(Rect2(-8,-9,13,9),Color("687b75"))
	draw_rect(Rect2(-6,-13,9,4),Color("d6e7e5") if estacao == 3 else Color("9ca99a"))
	draw_rect(Rect2(-2,-22,3,11),Color("485e5d"))
	draw_circle(Vector2(0,-23),6,Color("263e42"),false,2,false)
	draw_circle(Vector2(0,-23),4,Color("a2b9ad"),false,1,false)
	for i in 3:
		var a := estado * PI / 3.0 + i * TAU / 3.0
		var p := Vector2(cos(a),sin(a))*5.0
		draw_line(Vector2(0,-23),Vector2(0,-23)+p,Color("b6c4ab"),1,false)
	draw_rect(Rect2(3,-11,2,3),[Color("aa624a"),Color("d4ad64"),Color("64b8ac")][estado])

func definir_estacao(indice: int) -> void:
	estacao = indice
	modulate = [Color.WHITE,Color(1.05,1,0.93),Color(1,0.95,0.88),Color(0.87,0.94,1)][indice]
	queue_redraw()
