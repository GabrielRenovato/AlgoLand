extends Node2D

## Dois sprites rígidos na mesma projeção, ligados por pás independentes.
var textura: Texture2D
var instante_forcado := -1.0
var _tempo := 0.0
var _frente: Sprite2D
var _fundo: Sprite2D
var _laterais := Node2D.new()
const CENTRO := Vector2(799,617)
const PROFUNDIDADE := Vector2(14,-6)
const EIXO_X := Vector2(30,0)
const EIXO_Y := Vector2(-12,41)

func _ready() -> void:
	_fundo = _disco(CENTRO+PROFUNDIDADE,Color(0.62,0.53,0.4))
	add_child(_laterais)
	_laterais.draw.connect(_desenhar_pas)
	_frente = _disco(CENTRO,Color.WHITE)

func _disco(centro: Vector2, cor: Color) -> Sprite2D:
	var plano := Node2D.new()
	var raio := textura.get_width()*0.475
	plano.transform=Transform2D(EIXO_X/raio,EIXO_Y/raio,centro)
	add_child(plano)
	var sprite := Sprite2D.new()
	sprite.texture=textura
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.modulate=cor
	plano.add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	_tempo+=delta
	var t:=instante_forcado if instante_forcado>=0 else _tempo
	_frente.rotation=t*0.32
	_fundo.rotation=t*0.32
	_laterais.queue_redraw()

func _projetar(angulo: float) -> Vector2:
	return CENTRO+EIXO_X*cos(angulo)+EIXO_Y*sin(angulo)

func _desenhar_pas() -> void:
	var t:=instante_forcado if instante_forcado>=0 else _tempo
	for i in 16:
		var angulo:=i*TAU/16+t*0.32
		var a:=_projetar(angulo-0.045)
		var b:=_projetar(angulo+0.045)
		if absf((b-a).cross(PROFUNDIDADE))<2.0: continue
		var luz:=0.75+sin(angulo)*0.15
		_laterais.draw_colored_polygon(PackedVector2Array([a,b,b+PROFUNDIDADE,a+PROFUNDIDADE]),Color(0.61,0.39,0.17)*Color(luz,luz,luz))
		_laterais.draw_line(a,a+PROFUNDIDADE,Color(0.3,0.19,0.08),0.7,true)
