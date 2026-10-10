extends Control

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")

const ESCALA_PREVIEW := 1.2
const BRILHO_HOVER := Color(1.15, 1.15, 1.15, 1.0)
# Item reservado (ex.: na bigorna) fica acinzentado, sem transparencia
const COR_EM_USO := Color(0.4, 0.4, 0.4, 1.0)

var dados: DadosItem
var em_uso: bool = false

var _filtro_mouse_original: MouseFilter = MOUSE_FILTER_STOP
var _arrastando: bool = false

@onready var moldura: Panel = $Panel
@onready var icone: TextureRect = $Icone

func _ready() -> void:
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)

func exibir(item: DadosItem) -> void:
	dados = item
	modulate = Color.WHITE
	if item == null:
		icone.texture = null
		tooltip_text = ""
		return
	icone.texture = IconesItens.obter(item, get_tree())
	var estilo := moldura.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	estilo.border_color = item.cor_raridade()
	moldura.add_theme_stylebox_override("panel", estilo)
	tooltip_text = "%s  NV %d  (%s)" % [item.nome(), item.nivel, item.raridade.capitalize()]

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# Sem isso o item (acima do slot na ordem de picking) engoliria o drop
		_filtro_mouse_original = mouse_filter
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = _filtro_mouse_original
		if _arrastando:
			_arrastando = false
			moldura.visible = true
			icone.visible = true

func _get_drag_data(_posicao: Vector2) -> Variant:
	if dados == null or em_uso or not is_visible_in_tree():
		return null
	# O Jogador ainda nao tem desequipar_* para armaduras; arrastar so mudaria o modelo e seria desfeito
	if not dados.categoria in ["arma", "escudo"]:
		return null
	PreviewArrasto.mostrar(_criar_preview())
	_arrastando = true
	moldura.visible = false
	icone.visible = false
	modulate = Color.WHITE
	return {"item": dados, "origem": self, "tipo_item": dados.tipo}

func _criar_preview() -> Control:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var conteudo := Control.new()
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.size = size
	conteudo.scale = Vector2.ONE * ESCALA_PREVIEW
	conteudo.position = -size * ESCALA_PREVIEW / 2.0
	raiz.add_child(conteudo)

	var copia_moldura := Panel.new()
	copia_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copia_moldura.add_theme_stylebox_override("panel", moldura.get_theme_stylebox("panel"))
	copia_moldura.position = moldura.position
	copia_moldura.size = moldura.size
	conteudo.add_child(copia_moldura)

	var copia_icone := TextureRect.new()
	copia_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copia_icone.texture = icone.texture
	copia_icone.expand_mode = icone.expand_mode
	copia_icone.stretch_mode = icone.stretch_mode
	copia_icone.position = icone.position
	copia_icone.size = icone.size
	conteudo.add_child(copia_icone)
	return raiz

func _ao_mouse_entrar() -> void:
	if not get_viewport().gui_is_dragging() and not em_uso:
		modulate = BRILHO_HOVER

func _ao_mouse_sair() -> void:
	modulate = Color.WHITE

# Usados pelo slot da bigorna (Codigos/Logicas/slot.gd)
func obter_tipo_item() -> String:
	return dados.tipo if dados != null else ""

func obter_cor_raridade() -> Color:
	return dados.cor_raridade() if dados != null else Color.WHITE

func obter_textura_icone() -> Texture2D:
	return icone.texture

func definir_em_uso(valor: bool) -> void:
	em_uso = valor
	icone.modulate = COR_EM_USO if valor else Color.WHITE
