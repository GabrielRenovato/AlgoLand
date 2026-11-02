extends Node2D
## Dique transversal ao canal: pilares apoiados nas duas margens e folha elevável.
var folha: Node2D
var estacao := 0
const NORTE := Vector2(-23,-38)
const SUL := Vector2(23,30)
func _ready() -> void:
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(position.y+30)
	folha = Node2D.new()
	folha.name = "FolhaElevavel"
	folha.draw.connect(_desenhar_folha)
	add_child(folha)
	queue_redraw()
	folha.queue_redraw()
func _barra(no: CanvasItem, a: Vector2, b: Vector2, largura: float, cor: Color) -> void:
	var n := (b-a).normalized().orthogonal()*largura*.5
	no.draw_polygon(PackedVector2Array([a+n,b+n,b-n,a-n]),PackedColorArray([cor]))
func _draw() -> void:
	for pe in [NORTE,SUL]:
		draw_polygon(PackedVector2Array([pe+Vector2(-7,2),pe+Vector2(6,2),pe+Vector2(10,-3),pe+Vector2(-3,-3)]),PackedColorArray([Color("abb19d")]))
		draw_rect(Rect2(pe+Vector2(-6,-14),Vector2(12,16)),Color("6b7e77"))
		draw_rect(Rect2(pe+Vector2(-4,-58),Vector2(7,45)),Color("735234"))
		draw_rect(Rect2(pe+Vector2(-4,-58),Vector2(2,45)),Color("ad8150"))
	_barra(self,NORTE+Vector2(0,-57),SUL+Vector2(0,-57),6,Color("55432e"))
	_barra(self,NORTE+Vector2(-1,-59),SUL+Vector2(-1,-59),2,Color("dae9e6") if estacao == 3 else Color("b28a51"))
	for pe in [NORTE,SUL]:
		draw_circle(pe+Vector2(0,-54),1.5,Color("a3ada0"))
func _desenhar_folha() -> void:
	for i in 7:
		var a := NORTE.lerp(SUL,float(i)/7.0)
		var b := NORTE.lerp(SUL,float(i+1)/7.0)
		var cores := [Color("88603a"),Color("9d7445"),Color("765236")]
		folha.draw_polygon(PackedVector2Array([a-Vector2(0,28),b-Vector2(0,28),b,a]),PackedColorArray([cores[i%3]]))
		folha.draw_line(a-Vector2(0,27),a-Vector2(0,1),Color("503d2b"),1,false)
	for altura in [7,22]:
		_barra(folha,NORTE-Vector2(0,altura),SUL-Vector2(0,altura),2,Color("455b59"))

func definir_estacao(indice: int) -> void:
	estacao = indice
	modulate = [Color.WHITE,Color(1.05,1,0.93),Color(1,0.95,0.88),Color(0.87,0.94,1)][indice]
	queue_redraw()
