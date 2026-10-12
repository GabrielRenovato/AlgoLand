extends Control

## Barra da ferramenta ativa, embaixo no centro da tela (só na fazenda: o HUD a cria quando a cena tem a meta
## "barra_ferramentas"). Uma casa por ferramenta (enxada, regador, mão e uma por semente da estação que o jogador tem,
## com a quantidade), a ativa em destaque e o nome dela acima. Q/E (ou LB/RB no controle) trocam a ferramenta.
## Acima fica o aviso de por que a ação não pôde ser feita (FORA DA AREA DE PLANTIO...).

const TEMA := preload("res://recursos/ui/tema_menu.tres")
# Planes_ValMore: o Y da CraftPixNet Survival Kit (fonte do tema) parece um "y" minúsculo; letras de botão usam esta
const FONTE_TECLAS := preload("res://UI/Planes_ValMore.ttf")
const IconesFazenda := preload("res://Codigos/UI/icones_fazenda.gd")

const LADO_CASA := 24
const COR_FUNDO := Color(0.1, 0.08, 0.06, 0.85)
const COR_BORDA := Color(0.35, 0.27, 0.16, 1)
const COR_ATIVA := Color(1, 0.82, 0.3, 1)
const COR_NOME := Color(1, 0.96, 0.82)
const COR_AVISO := Color(1, 0.6, 0.5)
const COR_TECLA := Color(0.75, 0.7, 0.62)
const DURACAO_AVISO := 1.8
const NOMES := {"enxada": "ENXADA", "regador": "REGADOR", "mao": "MAO (COLHER)"}

var _coluna: VBoxContainer
var _aviso: Label
var _nome: Label
var _linha: HBoxContainer
var _tecla_anterior: Label
var _tecla_proxima: Label
var _casas: Array[Control] = []
var _tween_aviso: Tween

func _ready() -> void:
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_montar()
	Fazenda.ferramenta_alterada.connect(_ao_ferramenta_alterada)
	Fazenda.bolsas_alteradas.connect(_atualizar)
	Calendario.estacao_mudou.connect(_ao_estacao_mudou)
	Controle.dicas_alteradas.connect(_atualizar_teclas)
	_atualizar_teclas()
	_atualizar()

func _montar() -> void:
	_coluna = VBoxContainer.new()
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coluna.add_theme_constant_override("separation", 2)
	# Centrada embaixo: as âncoras iguais deixam o tamanho no mínimo e a coluna cresce para cima e para os lados
	_coluna.anchor_left = 0.5
	_coluna.anchor_right = 0.5
	_coluna.anchor_top = 1.0
	_coluna.anchor_bottom = 1.0
	_coluna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coluna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coluna.offset_top = -5
	_coluna.offset_bottom = -5
	add_child(_coluna)
	_aviso = _novo_rotulo(COR_AVISO)
	_aviso.modulate.a = 0.0
	_coluna.add_child(_aviso)
	_nome = _novo_rotulo(COR_NOME)
	_coluna.add_child(_nome)
	_linha = HBoxContainer.new()
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_linha.add_theme_constant_override("separation", 3)
	_coluna.add_child(_linha)
	_tecla_anterior = _novo_rotulo(COR_TECLA)
	_tecla_proxima = _novo_rotulo(COR_TECLA)

func _novo_rotulo(cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 10)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1))
	rotulo.add_theme_constant_override("outline_size", 3)
	return rotulo

func _ao_ferramenta_alterada(_ferramenta: String) -> void:
	_atualizar()

func _ao_estacao_mudou(_estacao: int) -> void:
	_atualizar()

func _atualizar_teclas() -> void:
	for rotulo in [_tecla_anterior, _tecla_proxima]:
		rotulo.add_theme_font_override("font", FONTE_TECLAS)
	_tecla_anterior.text = Controle.rotulo_acao("ferramenta_anterior")
	_tecla_proxima.text = Controle.rotulo_acao("ferramenta_proxima")

## Refaz as casas (a lista muda quando acaba uma semente, quando compra ou quando a estação vira)
func _atualizar() -> void:
	for casa in _casas:
		_linha.remove_child(casa)
		casa.queue_free()
	_casas.clear()
	if _tecla_anterior.get_parent() != null:
		_tecla_anterior.get_parent().remove_child(_tecla_anterior)
	if _tecla_proxima.get_parent() != null:
		_tecla_proxima.get_parent().remove_child(_tecla_proxima)
	_linha.add_child(_tecla_anterior)
	for ferramenta in Fazenda.ferramentas():
		var casa := _nova_casa(ferramenta)
		_linha.add_child(casa)
		_casas.append(casa)
	_linha.add_child(_tecla_proxima)
	_nome.text = nome_da_ferramenta(Fazenda.ferramenta)

static func nome_da_ferramenta(ferramenta: String) -> String:
	if ferramenta.begins_with(Fazenda.PREFIXO_SEMENTE):
		var id := ferramenta.trim_prefix(Fazenda.PREFIXO_SEMENTE)
		return "SEMENTE: %s" % String(Fazenda.PLANTAS[id]["nome"])
	return String(NOMES.get(ferramenta, ferramenta.to_upper()))

func _nova_casa(ferramenta: String) -> Control:
	var ativa := ferramenta == Fazenda.ferramenta
	var casa := Control.new()
	casa.name = "Casa_" + ferramenta.replace(":", "_")
	casa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	casa.custom_minimum_size = Vector2(LADO_CASA, LADO_CASA)
	var fundo := Panel.new()
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.set_border_width_all(2 if ativa else 1)
	estilo.border_color = COR_ATIVA if ativa else COR_BORDA
	estilo.set_corner_radius_all(2)
	fundo.add_theme_stylebox_override("panel", estilo)
	casa.add_child(fundo)
	var icone := TextureRect.new()
	icone.texture = IconesFazenda.da_ferramenta(ferramenta)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.modulate = Color.WHITE if ativa else Color(0.78, 0.74, 0.7)
	icone.set_anchors_preset(Control.PRESET_CENTER)
	icone.offset_left = -8
	icone.offset_right = 8
	icone.offset_top = -8
	icone.offset_bottom = 8
	casa.add_child(icone)
	if ferramenta.begins_with(Fazenda.PREFIXO_SEMENTE):
		var quantidade := _novo_rotulo(COR_NOME)
		quantidade.text = str(Fazenda.quantidade_sementes(ferramenta.trim_prefix(Fazenda.PREFIXO_SEMENTE)))
		quantidade.add_theme_font_size_override("font_size", 9)
		quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		quantidade.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		quantidade.grow_vertical = Control.GROW_DIRECTION_BEGIN
		quantidade.offset_right = -1
		quantidade.offset_bottom = 2
		casa.add_child(quantidade)
	return casa

## Mostra por alguns segundos por que a ação não pôde ser feita
func mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso != null and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(DURACAO_AVISO)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.4)
