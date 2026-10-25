extends CanvasLayer

## No celular o teclado nativo cobre o campo de texto; esta barra no alto da tela mostra o que está sendo digitado.
## Fica visível só enquanto o campo tem o foco e não faz parte do teclado: a digitação continua sendo a do sistema.

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const CAMADA := 60
const LIMITE_VISIVEL := 90

var _campo: LineEdit
var _titulo: Label
var _texto: Label
var _painel: PanelContainer

## Liga a prévia a um campo; fora do celular não faz nada
static func ligar(campo: LineEdit, titulo: String) -> void:
	if not Controle.celular():
		return
	var previa := load("res://codigo/ui/previa_digitacao.gd").new() as CanvasLayer
	previa._campo = campo
	campo.add_child(previa)
	previa._titulo.text = titulo

func _init() -> void:
	layer = CAMADA
	_montar()

func _ready() -> void:
	_painel.visible = false
	_campo.focus_entered.connect(_mostrar)
	_campo.focus_exited.connect(func() -> void: _painel.visible = false)
	_campo.text_changed.connect(func(_t: String) -> void: _atualizar())
	_campo.visibility_changed.connect(func() -> void:
		if not _campo.is_visible_in_tree(): _painel.visible = false)

func _montar() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.theme = TEMA
	add_child(centro)
	_painel = PanelContainer.new()
	_painel.add_theme_stylebox_override("panel", preload("res://codigo/ui/estilo_interface.gd").painel())
	centro.add_child(_painel)
	var coluna := HBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	_painel.add_child(coluna)
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	coluna.add_child(textos)
	_titulo = Label.new()
	_titulo.modulate = Color(1, 1, 1, 0.7)
	textos.add_child(_titulo)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_texto.custom_minimum_size = Vector2(250, 22)
	textos.add_child(_texto)
	var pronto := Button.new()
	pronto.text = "PRONTO"
	pronto.focus_mode = Control.FOCUS_NONE
	pronto.pressed.connect(func() -> void: _campo.release_focus())
	coluna.add_child(pronto)

func _mostrar() -> void:
	_painel.visible = true
	_atualizar()

func _atualizar() -> void:
	var t := _campo.text
	_texto.text = (("..." + t.right(LIMITE_VISIVEL)) if t.length() > LIMITE_VISIVEL else t) + "_"
