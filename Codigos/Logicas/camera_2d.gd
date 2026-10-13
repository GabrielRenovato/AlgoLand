extends Camera2D

## Celular: a tela é pequena e o jogo foi desenhado para monitor, então a câmera chega mais perto do personagem
const ZOOM_TOQUE := 2.0

func _ready() -> void:
	if Controle.usando_toque:
		zoom = Vector2(ZOOM_TOQUE, ZOOM_TOQUE)
