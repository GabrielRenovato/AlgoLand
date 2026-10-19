extends Node2D

## Bordas baixas e cabeços de amarração; nenhuma travessa de cerca sobre o piso.
var _celulas: Dictionary = {}
var _estacao := 0
var _layout: Dictionary

func configurar(layout: Dictionary) -> void:
	name = "AcabamentoCais"
	z_as_relative = false
	z_index = -998
	texture_filter = TEXTURE_FILTER_NEAREST
	_layout = layout
	for area: Array in layout["cais"]:
		for y in range(int(area[1])/16, (int(area[1])+int(area[3]))/16):
			for x in range(int(area[0])/16, (int(area[0])+int(area[2]))/16):
				_celulas[Vector2i(x,y)] = true

func aplicar_estacao(estacao: int) -> void:
	_estacao = estacao
	queue_redraw()

func _draw() -> void:
	var sombra := Color("533720")
	var luz: Color = [Color("b58a50"),Color("c69b60"),Color("a47b4b"),Color("989082")][_estacao]
	for celula: Vector2i in _celulas:
		var p := Vector2(celula*16)
		for lado: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if _celulas.has(celula+lado): continue
			var caixa := Rect2(p,Vector2(16,2))
			if lado == Vector2i.DOWN: caixa.position.y += 14
			if lado == Vector2i.LEFT: caixa.size = Vector2(2,16)
			if lado == Vector2i.RIGHT: caixa = Rect2(p+Vector2(14,0),Vector2(2,16))
			draw_rect(caixa,sombra)
			caixa.size = Vector2(16,1) if lado.y else Vector2(1,16)
			draw_rect(caixa,luz)

	# Cabeços fora da faixa central de circulação, nos cantos expostos.
	for p: Vector2 in [Vector2(115,343),Vector2(157,343),Vector2(115,507),Vector2(381,507),Vector2(451,443),Vector2(637,443),Vector2(637,307)]:
		draw_rect(Rect2(p-Vector2(3,5),Vector2(7,9)),sombra)
		draw_rect(Rect2(p-Vector2(2,5),Vector2(5,7)),Color("936539"))
		draw_rect(Rect2(p-Vector2(3,6),Vector2(7,2)),luz)
		draw_rect(Rect2(p-Vector2(2,7),Vector2(5,4)),luz)
		draw_line(p+Vector2(-1,-6),p+Vector2(2,-6),sombra)
		if _estacao == 3:
			draw_rect(Rect2(p-Vector2(3,8),Vector2(7,2)),Color("e2ece9"))
