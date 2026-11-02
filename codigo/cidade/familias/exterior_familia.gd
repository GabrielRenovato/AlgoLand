extends Node2D
## Fachada própria: mesma tela, pivô, escala e base física nas quatro estações.
const ARQUITETURA = preload("res://codigo/cidade/familias/arquitetura.json")
@export var id := "mara"
@export var largura := 330.0
var sprite: Sprite2D
var ficha: Dictionary
var estacao_atual := -1

func _ready() -> void:
	ficha = ARQUITETURA.data[id]
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = -Vector2(ficha.pivo[0], ficha.pivo[1])
	sprite.scale = Vector2.ONE * largura / float(ficha.largura_fonte)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)

func definir_estacao(indice: int) -> void:
	estacao_atual = posmod(indice, 4)
	sprite.texture = load(ficha.texturas[estacao_atual])

func limites_visuais() -> Rect2:
	return Rect2(sprite.offset * sprite.scale, sprite.texture.get_size() * sprite.scale)
