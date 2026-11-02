extends Control

## Atmosfera cartográfica, sob os marcadores e na mesma camada móvel da pintura.
## Todas as posições usam os 1536 × 1024 pixels da arte aprovada.
var instante_forcado := -1.0
var _tempo := 0.0
const TAMANHO := Vector2(1536,1024)
const CHAMINES := [Vector2(754,508),Vector2(460,410),Vector2(210,318)]
var _nevoas: Array[Vector2] = []
const MAGIA := [Vector2(244,771),Vector2(1240,569),Vector2(1246,191)]

func _ready() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/campanha/quedas_primeira_raiz.json"))
	for queda in dados.quedas:
		if Vector2(queda.direita[0]-queda.esquerda[0],queda.direita[1]-queda.esquerda[1]).length()>18:
			_nevoas.append(Vector2(queda.pe[0],queda.pe[1]))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_visibilidade)
	_visibilidade()

func _visibilidade() -> void:
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	if size.x<=0: return
	var t := instante_forcado if instante_forcado >= 0 else _tempo
	draw_set_transform(Vector2.ZERO,0,size/TAMANHO)
	# Fumaça leve nasce na chaminé e se desfaz antes de cruzar as outras casas.
	for origem in CHAMINES:
		for i in 4:
			var fase := fposmod(t*0.15+i*0.25,1.0)
			var posicao: Vector2 = origem+Vector2(sin(fase*3+i)*7+fase*13,-fase*51)
			_bolha(posicao,Vector2(3+fase*7,2+fase*4),Color(0.96,0.91,0.76,sin(fase*PI)*0.16))
	# Névoa baixa e espuma nas quedas, sem véus sobre as rotas.
	for origem in _nevoas:
		for i in 5:
			var fase := fposmod(t*0.26+i*0.2,1.0)
			var posicao: Vector2 = origem+Vector2((i-2)*4+sin(t+i)*3,-fase*12)
			_bolha(posicao,Vector2(5+fase*6,2+fase*3),Color(0.86,1,1,sin(fase*PI)*0.18))
	# Brilhos de invocação e minerais; pulsos lentos com intensidades independentes.
	for j in MAGIA.size():
		var origem: Vector2 = MAGIA[j]
		var pulso := 0.5+0.5*sin(t*1.4+j*2)
		_bolha(origem,Vector2(14,23),Color(0.57,0.94,0.76,0.035+pulso*0.055))
		for i in 5:
			var fase := fposmod(t*0.17+i*0.2+j*0.13,1.0)
			var p: Vector2 = origem+Vector2(sin(i*2.4+t*0.3)*19,13-fase*50)
			var luz := sin(fase*PI)*1.4
			draw_circle(p,luz,Color(1,0.92,0.55,sin(fase*PI)*0.7),true,-1,true)
	# Folhas esparsas acompanham a brisa perto da vila e do bosque.
	for i in 9:
		var fase := fposmod(t*0.075+i*0.113,1.0)
		var origem := Vector2(500,355) if i<5 else Vector2(947,321)
		var p := origem+Vector2((i%5)*18+fase*26,sin(fase*TAU+i)*10+fase*70)
		var giro := t*1.4+i
		var folha := PackedVector2Array([p+Vector2(0,-3).rotated(giro),p+Vector2(2,1).rotated(giro),p+Vector2(-2,1).rotated(giro)])
		draw_colored_polygon(folha,Color(0.92,0.77,0.3,sin(fase*PI)*0.65))
	# Duas aves pequenas atravessam o céu sobre o mar, em trajetórias diferentes.
	for i in 2:
		var fase := fposmod(t*0.018+i*0.5,1.0)
		var p := Vector2(450+fase*700,850+sin(fase*TAU)*26+i*35)
		var asa := sin(t*5+i)*2.0
		draw_polyline(PackedVector2Array([p+Vector2(-4,asa),p,p+Vector2(4,asa)]),Color(0.97,0.92,0.75,0.55),1.2,true)
	draw_set_transform(Vector2.ZERO)

func _bolha(centro: Vector2, raio: Vector2, cor: Color) -> void:
	var pontos := PackedVector2Array()
	for i in 16:
		pontos.append(centro+Vector2(cos(i*TAU/16),sin(i*TAU/16))*raio)
	draw_colored_polygon(pontos,cor)
