extends Camera2D

## Celular: a tela é pequena e o jogo foi desenhado para monitor, então a câmera chega mais perto do personagem
const ZOOM_TOQUE := 2.0
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")

## Zoom sem a opção do jogador (ZOOM na pausa multiplica por cima)
var _zoom_base := Vector2.ONE

func _ready() -> void:
	add_to_group("camera_jogo")
	if Controle.usando_toque:
		zoom = Vector2(ZOOM_TOQUE, ZOOM_TOQUE)
	_zoom_base = zoom
	aplicar_zoom()

func aplicar_zoom() -> void:
	zoom = _zoom_base * Opcoes.zoom(2 if bool(get_parent().get("eh_p2")) else 1)
