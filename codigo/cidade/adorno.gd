extends Node2D

## Pequenos objetos da praça desenhados na grade de pixels, com a paleta de madeira do cenário.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
@export_enum("poco", "banco", "mural", "lampiao", "canteiro", "bandeiras", "coreto") var tipo := "poco"
const ESCURO := Color("49372f")
const MADEIRA := Color("9f7150")
const CLARO := Color("c4996b")

func _ready() -> void:
	z_index = Profundidade.z_de(global_position.y)

func _r(x: float, y: float, w: float, h: float, cor: Color) -> void:
	draw_rect(Rect2(x, y, w, h), cor)

func _draw() -> void:
	match tipo:
		"poco":
			_r(-22, -5, 44, 10, Color(0.15, 0.12, 0.1, 0.3))
			_r(-18, -20, 36, 18, ESCURO)
			_r(-16, -18, 32, 14, Color("a9a18b"))
			_r(-13, -19, 26, 7, Color("4a6973"))
			for x in range(-15, 16, 8):
				_r(x, -10, 1, 6, Color("736e61"))
			_r(-22, -47, 5, 43, ESCURO)
			_r(17, -47, 5, 43, ESCURO)
			_r(-20, -46, 2, 40, CLARO)
			_r(18, -46, 2, 40, CLARO)
			_r(-27, -54, 54, 9, ESCURO)
			_r(-24, -52, 48, 5, Color("b7704c"))
			_r(-2, -44, 2, 22, CLARO)
			_r(-5, -27, 9, 7, MADEIRA)
		"banco":
			_r(-20, -4, 40, 6, Color(0.1, 0.1, 0.08, 0.25))
			_r(-19, -20, 38, 8, ESCURO)
			_r(-17, -19, 34, 3, CLARO)
			_r(-17, -15, 34, 2, MADEIRA)
			_r(-20, -10, 40, 6, ESCURO)
			_r(-18, -9, 36, 3, CLARO)
			_r(-16, -4, 4, 5, ESCURO)
			_r(12, -4, 4, 5, ESCURO)
		"mural":
			_r(-20, -40, 40, 28, ESCURO)
			_r(-18, -38, 36, 24, MADEIRA)
			for x in [-13, 1]:
				_r(x, -34, 11, 14, Color("e6d5a9"))
				_r(x + 2, -30, 6, 1, Color("8f785e"))
				_r(x + 2, -26, 5, 1, Color("8f785e"))
			_r(-16, -12, 4, 12, ESCURO)
			_r(12, -12, 4, 12, ESCURO)
		"lampiao":
			_r(-2, -38, 4, 38, ESCURO)
			_r(-7, -49, 14, 14, ESCURO)
			_r(-5, -47, 10, 10, Color("ffd794"))
			_r(-7, -51, 14, 3, MADEIRA)
		"canteiro":
			_r(-26, -16, 52, 16, ESCURO)
			_r(-24, -14, 48, 12, Color("76603e"))
			for x in range(-20, 23, 8):
				_r(x, -18, 2, 12, Color("50824e"))
				_r(x - 3, -15, 3, 2, Color("88a852"))
				_r(x - 2, -21, 6, 5, Color("ebb0bf") if (x + 20) % 16 == 0 else Color("f3d677"))
		"bandeiras":
			_r(-92, -30, 184, 1, ESCURO)
			for x in range(-88, 90, 16):
				draw_colored_polygon(PackedVector2Array([Vector2(x, -29), Vector2(x + 10, -29), Vector2(x + 5, -19)]), Color("e7b34f") if (x + 88) % 32 == 0 else Color("ba665d"))
		"coreto":
			_r(-30, -40, 4, 42, ESCURO)
			_r(26, -40, 4, 42, ESCURO)
			_r(-29, -38, 1, 34, CLARO)
			_r(27, -38, 1, 34, CLARO)
			_r(-32, -40, 64, 4, MADEIRA)
			_r(-32, -10, 64, 14, ESCURO)
			_r(-30, -8, 60, 10, MADEIRA)
			for y in range(-7, 3, 3):
				_r(-28, y, 56, 1, CLARO)
			_r(-18, 4, 36, 4, CLARO)
