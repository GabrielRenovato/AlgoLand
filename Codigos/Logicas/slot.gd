extends Control

signal item_alterado(tem_item: bool)
## Confirmar (controle) ou clicar (mouse) num slot vazio: quem usa o slot decide de onde vem a arma
signal pediu_item

@export var tipos_aceitos: Array[String] = []

const LADO_ICONE := 14.0
const COR_MOLDURA := Color(1.0, 0.82, 0.3, 0.9)
const COR_MOLDURA_HOVER := Color(1.0, 0.9, 0.45, 1.0)
const COR_PREENCHIMENTO_HOVER := Color(1.0, 0.85, 0.35, 0.25)

var item_atual: Node = null

var _arrasto_valido: bool = false
var _mouse_em_cima: bool = false
var _arrastando_daqui: bool = false
var _moldura: Control

@onready var icone: Sprite2D = $Icone
@onready var fundo: Panel = $Fundo
@onready var _estilo_fundo_original: StyleBox = fundo.get_theme_stylebox("panel")

func _ready() -> void:
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)
	# No controle: o slot recebe foco e confirmar nele devolve o item ao inventário
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_ao_foco_alterado)
	focus_exited.connect(_ao_foco_alterado)
	gui_input.connect(_ao_entrada)
	# Desenhada por cima do fundo e do ícone; só aparece durante um arrasto compatível
	_moldura = Control.new()
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moldura.draw.connect(_desenhar_moldura)
	add_child(_moldura)

func aceita_tipo_item(tipo_item: String) -> bool:
	return tipos_aceitos.is_empty() or tipos_aceitos.has(tipo_item)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_arrasto_valido = _dados_validos(get_viewport().gui_get_drag_data())
		_moldura.queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_arrasto_valido = false
		_moldura.queue_redraw()
		if _arrastando_daqui:
			_arrastando_daqui = false
			icone.visible = true
			if not get_viewport().gui_is_drag_successful():
				limpar()

func _get_drag_data(_posicao: Vector2) -> Variant:
	if item_atual == null or icone.texture == null:
		return null
	_arrastando_daqui = true
	PreviewArrasto.mostrar(_criar_preview_icone())
	icone.visible = false
	return {"tipo_item": item_atual.obter_tipo_item(), "origem": item_atual, "slot_origem": self}

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
	return _dados_validos(dados)

func _drop_data(_posicao: Vector2, dados: Variant) -> void:
	colocar_item(dados["origem"])

func limpar() -> void:
	var tinha_item := item_atual != null
	if tinha_item and is_instance_valid(item_atual):
		item_atual.definir_em_uso(false)
	item_atual = null
	icone.texture = null
	fundo.add_theme_stylebox_override("panel", _estilo_fundo_original)
	if tinha_item:
		item_alterado.emit(false)

func _dados_validos(dados: Variant) -> bool:
	if not (dados is Dictionary) or not dados.has("tipo_item"):
		return false
	return aceita_tipo_item(dados["tipo_item"])

func colocar_item(origem: Node) -> void:
	if item_atual != null and item_atual != origem and is_instance_valid(item_atual):
		item_atual.definir_em_uso(false)
	item_atual = origem
	origem.definir_em_uso(true)
	_copiar_icone(origem)
	item_alterado.emit(true)

func _criar_preview_icone() -> Control:
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var copia := icone.duplicate() as Sprite2D
	copia.position = Vector2.ZERO
	copia.visible = true
	preview.add_child(copia)
	return preview

func _copiar_icone(origem: Control) -> void:
	var textura: Texture2D = origem.obter_textura_icone()
	icone.hframes = 1
	icone.vframes = 1
	icone.frame = 0
	icone.texture = textura
	icone.position = size / 2.0
	var maior := 1.0
	if textura != null:
		maior = maxf(maxf(textura.get_width(), textura.get_height()), 1.0)
	var escala_final := Vector2.ONE * minf(1.0, LADO_ICONE / maior)
	icone.modulate = Color.WHITE
	var estilo := _estilo_fundo_original.duplicate() as StyleBoxFlat
	estilo.border_color = origem.obter_cor_raridade()
	fundo.add_theme_stylebox_override("panel", estilo)
	icone.scale = escala_final * 1.4
	create_tween().tween_property(icone, "scale", escala_final, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ao_foco_alterado() -> void:
	_moldura.queue_redraw()

func _ao_entrada(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"):
		if item_atual != null:
			limpar()
		else:
			pediu_item.emit()
		accept_event()
	elif item_atual == null and evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		pediu_item.emit()
		accept_event()

func _desenhar_moldura() -> void:
	if has_focus():
		_moldura.draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), COR_MOLDURA_HOVER, false, 1.0)
	if not _arrasto_valido:
		return
	var retangulo := Rect2(Vector2.ZERO, size)
	if _mouse_em_cima:
		_moldura.draw_rect(retangulo, COR_PREENCHIMENTO_HOVER)
	_moldura.draw_rect(retangulo.grow(-0.5), COR_MOLDURA_HOVER if _mouse_em_cima else COR_MOLDURA, false, 1.0)

func _ao_mouse_entrar() -> void:
	_mouse_em_cima = true
	_moldura.queue_redraw()

func _ao_mouse_sair() -> void:
	_mouse_em_cima = false
	_moldura.queue_redraw()
