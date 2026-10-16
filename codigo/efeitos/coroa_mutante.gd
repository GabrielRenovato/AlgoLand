extends Node2D

## Coroa em pixel art desenhada acima dos inimigos: cinza nos mutantes e dourada nos chefes (no lugar do antigo tom roxo)
const DESENHO := [
	".#...#...#.",
	"#b#.#b#.#b#",
	"#cb#cbc#bc#",
	"#ccbcccbcc#",
	"#ccccccccc#",
	"#cgccgccgc#",
	"#ccccccccc#",
	"###########",
]
const PALETA_CINZA := {
	"#": Color(0.16, 0.16, 0.19),
	"c": Color(0.62, 0.63, 0.67),
	"b": Color(0.88, 0.89, 0.92),
	"g": Color(0.36, 0.37, 0.42),
}
# Chefes: ouro com uma gema vermelha no meio
const PALETA_DOURADA := {
	"#": Color(0.28, 0.15, 0.03),
	"c": Color(0.96, 0.73, 0.14),
	"b": Color(1.0, 0.93, 0.5),
	"g": Color(0.82, 0.16, 0.14),
}

## Define antes de entrar na árvore (ou chame queue_redraw depois)
var paleta: Dictionary = PALETA_CINZA

func _ready() -> void:
	# Acima de tudo, como a barra de vida (z relativo ao inimigo)
	z_index = 1000

func _draw() -> void:
	var largura: int = DESENHO[0].length()
	var altura: int = DESENHO.size()
	var canto := Vector2(-largura / 2, -altura)
	for y in altura:
		for x in largura:
			var c: String = DESENHO[y][x]
			if paleta.has(c):
				draw_rect(Rect2(canto + Vector2(x, y), Vector2.ONE), paleta[c])
