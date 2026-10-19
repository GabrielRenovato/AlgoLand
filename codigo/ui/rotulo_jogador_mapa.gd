extends Control

## Letras de 3×5 pixels: centraliza o desenho visível, sem margens de fonte.
const LETRAS := {
	"P": ["110", "101", "110", "100", "100"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
}
var texto := "P1"
var cor := Color("ffe491")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var origem := ((size - Vector2(7,5)) / 2).floor()
	for indice in texto.length():
		var linhas: Array = LETRAS[texto[indice]]
		for y in 5:
			for x in 3:
				if linhas[y][x] == "1":
					draw_rect(Rect2(origem + Vector2(indice*4+x,y),Vector2.ONE),cor)
