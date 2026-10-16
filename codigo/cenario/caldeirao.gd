extends Sprite2D

## Caldeirão da fazenda (assets/cenario/Farm RPG/caldeirao.png: 5 quadros de 32x32, o 0 apagado e 1-4 com fogo e bolhas).
## Fica sempre aceso, trocando os quadros 1-4. Quando uma poção fica pronta (tela do caldeirão), ferver() dá um pulo
## no desenho. A textura é um AtlasTexture (o profundidade_grupo mede o sprite por ela): a animação troca a região.

const LADO := 32
const QUADROS := [1, 2, 3, 4]
const QUADROS_POR_SEGUNDO := 6.0

var _tempo := 0.0
var _tween: Tween

func _ready() -> void:
	add_to_group("caldeirao")
	# Cópia própria da região: a animação não mexe no recurso salvo na cena
	if texture is AtlasTexture:
		texture = texture.duplicate()

func _process(delta: float) -> void:
	_tempo += delta
	if texture is AtlasTexture:
		var quadro: int = QUADROS[int(_tempo * QUADROS_POR_SEGUNDO) % QUADROS.size()]
		(texture as AtlasTexture).region = Rect2(quadro * LADO, 0, LADO, LADO)

## Poção pronta: o caldeirão estica e volta (a base fica no chão: a origem do sprite é a base)
func ferver() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(0.9, 1.15), 0.08)
	_tween.tween_property(self, "scale", Vector2(1.08, 0.94), 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
