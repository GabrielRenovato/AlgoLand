extends HBoxContainer

## Buffs (totens) comprados na janela entre os andares: um ícone por tipo, com o nível (quantas vezes foi comprado).
## Fica acima da barra de itens; passar o mouse ou tocar mostra o nome, o nível e o efeito, como as habilidades do League of Legends.

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const LADO := 16
const LADO_TOQUE := 24
const DURACAO_TOQUE := 3.0
const COR_TEXTO := Color(1, 0.96, 0.82)
const COR_NIVEL := Color(1.0, 0.85, 0.4)

var _assinatura := ""
var _dicas: Dictionary = {}   # icone -> {"nome", "texto"}
var _dica: PanelContainer
var _rotulo_dica: Label
var _icone_da_dica: Control
var _tween: Tween

func _ready() -> void:
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 3)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dica = PanelContainer.new()
	_dica.top_level = true
	_dica.visible = false
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.z_index = 50
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.1, 0.07, 0.04, 0.95)
	fundo.border_color = Color("c9a45c")
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(2)
	fundo.set_content_margin_all(4)
	_dica.add_theme_stylebox_override("panel", fundo)
	_rotulo_dica = Label.new()
	_rotulo_dica.add_theme_font_size_override("font_size", 8)
	_rotulo_dica.add_theme_color_override("font_color", COR_TEXTO)
	_dica.add_child(_rotulo_dica)
	add_child(_dica)
	_atualizar()

func _process(_delta: float) -> void:
	_atualizar()
	if _dica.visible and is_instance_valid(_icone_da_dica):
		_posicionar_dica()

## Agrupa as compras do jogador por nome; o nível é o número de cópias
static func agrupar(compras: Array) -> Array:
	var ordem: Array = []
	var por_nome := {}
	for compra: Dictionary in compras:
		var nome := str(compra.get("nome", ""))
		if not por_nome.has(nome):
			por_nome[nome] = {"dados": compra, "nivel": 0}
			ordem.append(nome)
		por_nome[nome]["nivel"] += 1
	var lista: Array = []
	for nome in ordem:
		lista.append(por_nome[nome])
	return lista

func _atualizar() -> void:
	var jogador := EventosJogo.dono(self)
	var compras: Array = jogador.get("itens_comprados") if jogador != null and jogador.get("itens_comprados") != null else []
	var assinatura := "%d|%s" % [compras.size(), compras[-1].get("nome", "") if not compras.is_empty() else ""]
	if assinatura == _assinatura:
		return
	_assinatura = assinatura
	_dica.visible = false
	for filho in get_children():
		if filho != _dica:
			remove_child(filho)
			filho.queue_free()
	_dicas.clear()
	var lado := LADO_TOQUE if Controle.usando_toque else LADO
	for grupo: Dictionary in agrupar(compras):
		var dados: Dictionary = grupo["dados"]
		var nivel: int = grupo["nivel"]
		var casa := TextureRect.new()
		casa.texture = load(str(dados.get("icone", ""))) if ResourceLoader.exists(str(dados.get("icone", ""))) else null
		casa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		casa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		casa.custom_minimum_size = Vector2(lado, lado)
		casa.mouse_filter = Control.MOUSE_FILTER_STOP
		var selo := Label.new()
		selo.text = str(nivel)
		selo.add_theme_font_size_override("font_size", 7)
		selo.add_theme_color_override("font_color", COR_NIVEL)
		selo.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
		selo.add_theme_constant_override("outline_size", 2)
		selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		selo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		selo.grow_vertical = Control.GROW_DIRECTION_BEGIN
		casa.add_child(selo)
		_dicas[casa] = "%s  NV %d\n%s" % [str(dados.get("nome", "")).to_upper(), nivel, str(dados.get("descricao", "")).to_upper()]
		casa.mouse_entered.connect(_mostrar_dica.bind(casa, false))
		casa.mouse_exited.connect(_esconder_dica.bind(casa))
		casa.gui_input.connect(func(evento: InputEvent) -> void:
			if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
				_mostrar_dica(casa, true))
		add_child(casa)
	visible = get_child_count() > 1

func _mostrar_dica(casa: Control, temporaria: bool) -> void:
	if not _dicas.has(casa):
		return
	_icone_da_dica = casa
	_rotulo_dica.text = _dicas[casa]
	_dica.reset_size()
	_dica.visible = true
	_posicionar_dica()
	if _tween != null:
		_tween.kill()
	if temporaria:
		_tween = create_tween()
		_tween.tween_interval(DURACAO_TOQUE)
		_tween.tween_callback(func() -> void: _dica.visible = false)

func _esconder_dica(casa: Control) -> void:
	if _icone_da_dica == casa and (_tween == null or not _tween.is_running()):
		_dica.visible = false

func _posicionar_dica() -> void:
	var caixa := _icone_da_dica.get_global_rect()
	var tela := get_viewport().get_visible_rect()
	var x := clampf(caixa.get_center().x - _dica.size.x / 2.0, tela.position.x + 4.0, tela.end.x - _dica.size.x - 4.0)
	_dica.global_position = Vector2(x, caixa.position.y - _dica.size.y - 4.0)
