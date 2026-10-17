extends TextureRect

## Mesmo pacote dos botões existentes; o desenho ocupa dez pixels lógicos na aba.
var tipo := 0
const ICONES := [
	preload("res://assets/ui/sem org/3 Icons/Icons_11.png"),
	preload("res://assets/ui/sem org/3 Icons/Icons_61.png"),
	preload("res://assets/ui/sem org/3 Icons/Icons_10.png"),
	preload("res://assets/pesca/peixes/sardinha.png"),
]
func _ready() -> void:
	texture = ICONES[clampi(tipo, 0, 3)]
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(0.13, 0.12, 0.18)
