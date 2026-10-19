extends TextureRect

const ESTACOES := ["primavera","verao","outono","inverno"]
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Calendario.estacao_mudou.connect(_aplicar)
	_aplicar(Calendario.estacao())
func _aplicar(estacao: int) -> void:
	texture = load("res://assets/ui/fundos_menu/%s.png" % ESTACOES[clampi(estacao,0,3)])
