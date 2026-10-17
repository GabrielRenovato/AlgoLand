extends Control

## Vinheta da rota: conjunto nativo sincronizado e chão passando na velocidade da passada.
var conjunto: Node2D
var andando := true
var _tempo := 0.0
var _estacao := 0

func _init() -> void:
	custom_minimum_size = Vector2(150, 80)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	conjunto = preload("res://codigo/comercio/conjunto_carroca.gd").new()
	add_child(conjunto)
	conjunto.atualizar_estacao(Calendario.estacao())
	conjunto.definir_movimento(andando)
	conjunto.embarcar_jogadores()
	_estacao = Calendario.estacao()
	resized.connect(_ajustar)
	_ajustar()

func _ajustar() -> void:
	if conjunto != null:
		conjunto.position = Vector2(floorf((size.x - 150) / 2) + 42, 64)

func _process(delta: float) -> void:
	if andando:
		_tempo += delta
	queue_redraw()

func _draw() -> void:
	var grama: Color = [Color("526c3b"), Color("747746"), Color("946743"), Color("c6d4d6")][_estacao]
	var terra: Color = [Color("86674f"), Color("8c7152"), Color("805b48"), Color("807c86")][_estacao]
	draw_rect(Rect2(Vector2.ZERO, size), grama)
	draw_rect(Rect2(0, 57, size.x, 18), terra)
	var deslocamento := floori(_tempo * 24.0) % 24
	for x in range(-24, ceili(size.x) + 24, 24):
		draw_rect(Rect2(x - deslocamento, 68, 4, 1), terra.lightened(0.12))
		draw_rect(Rect2(x + 11 - deslocamento, 53, 2, 2), grama.lightened(0.1))
