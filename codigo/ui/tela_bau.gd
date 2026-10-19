extends Control

## Tela do baú da casa (BauCasa): abre na esquerda com a mochila junto na direita (Interface.TELAS_ACOMPANHANTES).
## Arrastar da mochila para uma casa do baú guarda; do baú para a mochila, retira. No controle (ou com o botão direito),
## confirmar num item troca ele de lado (slot_ui.gd).

const CENA_SLOT := preload("res://cenas/ui/componentes/slot_ui.tscn")
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const EstiloSlot := preload("res://codigo/ui/estilo_slot.gd")
const COLUNAS := 4

var painel: PanelContainer
var _grade: GridContainer
var _rolagem: ScrollContainer
var _rotulo: Label
var _slots: Array[Control] = []

func _ready() -> void:
	add_to_group("tela_bau")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.anchor_left = 0.0
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = 12
	painel.offset_top = -60
	painel.offset_bottom = 60
	var moldura: StyleBoxTexture = EstiloSlot.moldura_barra().duplicate()
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_content_margin(lado, 8)
	painel.add_theme_stylebox_override("panel", moldura)
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "BAU"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", FONTE)
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color("e7c884"))
	coluna.add_child(titulo)
	_grade = GridContainer.new()
	_grade.columns = COLUNAS
	_grade.add_theme_constant_override("h_separation", 2)
	_grade.add_theme_constant_override("v_separation", 2)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.size_flags_vertical = SIZE_EXPAND_FILL
	_rolagem.follow_focus = true
	coluna.add_child(_rolagem)
	_rolagem.add_child(_grade)
	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_override("font", FONTE)
	_rotulo.add_theme_font_size_override("font_size", 8)
	_rotulo.modulate = Color(1, 1, 1, 0.7)
	coluna.add_child(_rotulo)
	var fechar := Button.new()
	fechar.text = "FECHAR"
	fechar.add_theme_font_size_override("font_size", 8)
	fechar.pressed.connect(func() -> void: EventosJogo.fechar_tela_de(self, "bau"))
	coluna.add_child(fechar)
	BauCasa.alterado.connect(_atualizar)
	visibility_changed.connect(func() -> void: if visible: _atualizar())
	resized.connect(_ajustar)
	_atualizar()
	_ajustar()

func _ajustar() -> void:
	if painel == null: return
	painel.anchor_top = 0
	painel.anchor_bottom = 0
	painel.offset_left = 8
	painel.offset_right = 118
	painel.offset_top = 8
	painel.offset_bottom = minf(288,size.y-8)

func _atualizar() -> void:
	while _slots.size() < BauCasa.capacidade:
		var slot: Control = CENA_SLOT.instantiate()
		slot.tipo_slot = "bau"
		slot.indice = _slots.size()
		_grade.add_child(slot)
		_slots.append(slot)
	for i in _slots.size():
		_slots[i].exibir(BauCasa.itens[i] if i < BauCasa.itens.size() else null)
	var usadas := BauCasa.itens.filter(func(item) -> bool: return item != null).size()
	_rotulo.text = "%d/%d ESPACOS" % [usadas, BauCasa.capacidade]

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na primeira casa
func focar_inicio() -> void:
	if not _slots.is_empty():
		Controle.focar(_slots[0])
