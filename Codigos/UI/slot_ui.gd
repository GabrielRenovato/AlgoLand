extends Control

const COR_MOLDURA := Color(1.0, 0.82, 0.3, 0.9)
const COR_MOLDURA_HOVER := Color(1.0, 0.9, 0.45, 1.0)
const COR_PREENCHIMENTO_HOVER := Color(1.0, 0.85, 0.35, 0.25)
const COR_ICONE_VAZIO := Color(1.0, 1.0, 1.0, 0.35)

@export var tipo_slot: String = "mochila"
@export var icone_vazio: Texture2D
@export var mostrar_fundo := true

var indice: int = -1
var item_atual: DadosItem

var _arrasto_valido: bool = false
var _mouse_em_cima: bool = false
var _moldura: Control

@onready var _fundo: Panel = $Fundo
@onready var _icone_vazio: TextureRect = $IconeVazio
@onready var _item_ui: Control = $ItemUi

func _ready() -> void:
	_fundo.visible = mostrar_fundo
	_icone_vazio.texture = icone_vazio
	_icone_vazio.modulate = COR_ICONE_VAZIO
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)
	# No controle não há arrasto: o slot recebe foco e confirmar usa o item (ver _usar_com_controle)
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_ao_foco_alterado)
	focus_exited.connect(_ao_foco_alterado)
	gui_input.connect(_ao_entrada)
	# Desenhada por cima do fundo e do item; so aparece durante um arrasto compativel
	_moldura = Control.new()
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moldura.draw.connect(_desenhar_moldura)
	add_child(_moldura)
	exibir(item_atual)

func exibir(item: DadosItem) -> void:
	item_atual = item
	_item_ui.visible = item != null
	_icone_vazio.visible = item == null and icone_vazio != null
	_item_ui.exibir(item)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_arrasto_valido = _dados_validos(get_viewport().gui_get_drag_data())
		_moldura.queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_arrasto_valido = false
		_moldura.queue_redraw()

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
	return _dados_validos(dados)

func _drop_data(_posicao: Vector2, dados: Variant) -> void:
	var item: DadosItem = dados["item"]
	if tipo_slot == "mochila":
		InventarioJogador.mover_para_mochila(item, indice)
	else:
		InventarioJogador.equipar(item)

func _dados_validos(dados: Variant) -> bool:
	if not (dados is Dictionary) or dados.has("slot_origem") or not (dados.get("item") is DadosItem):
		return false
	if tipo_slot == "mochila":
		return true
	var item: DadosItem = dados["item"]
	# Item ja equipado nao tem celula na mochila, entao nao pode ser "equipado" de novo
	return item.categoria == tipo_slot and InventarioJogador.indice_de(item) != -1 and InventarioJogador.pode_equipar(item)

func _ao_foco_alterado() -> void:
	_moldura.queue_redraw()

func _ao_entrada(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"):
		_usar_com_controle()
		accept_event()

# Com a bigorna/encantamento abertos o item vai para o slot do mercador; senão, mochila equipa e
# equipamento volta para a mochila. Só armas e escudo, como no arrasto (ver item_ui._get_drag_data)
func _usar_com_controle() -> void:
	if item_atual == null or _item_ui.em_uso:
		return
	var mercante := get_tree().get_first_node_in_group("tela_mercante")
	if mercante != null and mercante.is_visible_in_tree() and mercante.receber_item_do_controle(_item_ui):
		return
	if not item_atual.categoria in ["arma", "escudo"]:
		return
	if tipo_slot == "mochila":
		InventarioJogador.equipar(item_atual)
	else:
		InventarioJogador.desequipar(tipo_slot)

func _desenhar_moldura() -> void:
	if has_focus():
		var foco := Rect2(Vector2.ZERO, size)
		_moldura.draw_rect(foco, COR_PREENCHIMENTO_HOVER)
		_moldura.draw_rect(foco.grow(-0.5), COR_MOLDURA_HOVER, false, 1.0)
	# Na grade da mochila so a celula sob o mouse acende, senao a grade inteira piscaria
	if not _arrasto_valido or (tipo_slot == "mochila" and not _mouse_em_cima):
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
