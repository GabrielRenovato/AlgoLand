extends Control

## Energia da fazenda: moldura em pixel art e preenchimento de baixo para cima.
## No toque fica abaixo do Status, fora da região do joystick e da barra de ferramentas.
const DesenhoBarra := preload("res://codigo/ui/desenho_barra.gd")
const ICONE := preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/3 Icons/Icon_49.png")
const LARGURA := 10.0
const COMPRIMENTO := 64
const ALTURA := 76.0
const COR_CHEIA := Color(0.45, 0.85, 0.3)
const COR_BAIXA := Color(1.0, 0.3, 0.3)
const FRACAO_BAIXA := 0.25

var _fracao := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(LARGURA, ALTURA)
	size = custom_minimum_size
	get_viewport().size_changed.connect(_posicionar)
	var status := get_parent().get_node_or_null("Status") as Control
	if status != null:
		status.resized.connect(_posicionar)
	_posicionar.call_deferred()

func _posicionar() -> void:
	var margens := Controle.margens_seguras()
	if Controle.usando_toque and not EventosJogo.eh_do_p2(self):
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var status := get_parent().get_node_or_null("Status") as Control
		position = Vector2(8 + margens.x, 54 + margens.y)
		if status != null:
			position = (status.position + Vector2(0, status.size.y + 6)).round()
	else:
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		offset_left = -(LARGURA + 8 + margens.z)
		offset_right = -(8 + margens.z)
		offset_top = -(ALTURA + 8 + margens.w)
		offset_bottom = -(8 + margens.w)

func definir(atual: float, maximo: float) -> void:
	_fracao = clampf(atual / maxf(maximo, 1.0), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var cor := COR_BAIXA if _fracao <= FRACAO_BAIXA else COR_CHEIA
	draw_texture_rect(ICONE, Rect2(0, 0, 10, 8), false, cor)
	# As mesmas pontas, bordas e brilho da vida/estamina, giradas para encher de baixo para cima.
	draw_set_transform(Vector2(1, ALTURA), -PI / 2.0)
	DesenhoBarra.desenhar(self, Vector2.ZERO, COMPRIMENTO, _fracao, _fracao, cor)
	draw_set_transform(Vector2.ZERO)
