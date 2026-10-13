extends Control

## Barra da ferramenta ativa, embaixo no centro da tela (só na fazenda: o HUD a cria quando a cena tem a meta
## "barra_ferramentas"). Uma casa por ferramenta (enxada, regador, mão e uma por semente da estação que o jogador tem,
## com a quantidade), a ativa em destaque e o nome dela acima. Q/E (ou LB/RB no controle) trocam a ferramenta.
## Mesmo desenho da barra de armas da arena: a moldura do inventário (EstiloSlot.moldura_barra) com os quadrados do sprite de slot, o ícone
## dentro da borda e a moldura branca na ferramenta em uso.
## Acima fica o aviso de por que a ação não pôde ser feita (FORA DA AREA DE PLANTIO...).

const EstiloSlot := preload("res://Codigos/UI/estilo_slot.gd")
const TEMA := preload("res://recursos/ui/tema_menu.tres")
# Planes_ValMore: o Y da CraftPixNet Survival Kit (fonte do tema) parece um "y" minúsculo; letras de botão usam esta
const FONTE_TECLAS := preload("res://UI/Planes_ValMore.ttf")
const IconesFazenda := preload("res://Codigos/UI/icones_fazenda.gd")

## O mesmo quadrado do inventário e da barra de armas (20; no celular, o dobro, para o dedo)
const LADO_CASA := 20
const LADO_CASA_TOQUE := 40
## O ícone fica dentro da borda do sprite do slot
const RECUO_ICONE := 4
const ESPACO_ENTRE_CASAS := 2
const FOLGA_MARCO := 1
const COR_ATIVA := Color(1, 1, 1, 1)
const COR_NOME := Color(1, 0.96, 0.82)
const COR_AVISO := Color(1, 0.6, 0.5)
const COR_TECLA := Color(0.75, 0.7, 0.62)
const DURACAO_AVISO := 1.8
const NOMES := {"enxada": "ENXADA", "regador": "REGADOR", "mao": "MAO (COLHER)"}

var _coluna: VBoxContainer
var _aviso: Label
var _nome: Label
var _linha: HBoxContainer
var _painel: PanelContainer
var _casas_linha: HBoxContainer
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
	# [Q] [painel com as casas] [E]
	_linha = HBoxContainer.new()
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_linha.add_theme_constant_override("separation", 3)
	_coluna.add_child(_linha)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_theme_stylebox_override("panel", EstiloSlot.moldura_barra())
	_casas_linha = HBoxContainer.new()
	_casas_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_casas_linha.add_theme_constant_override("separation", ESPACO_ENTRE_CASAS)
	_painel.add_child(_casas_linha)
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
	_tecla_anterior.visible = not Controle.usando_toque
	_tecla_proxima.visible = not Controle.usando_toque

## Refaz as casas (a lista muda quando acaba uma semente, quando compra ou quando a estação vira)
func _atualizar() -> void:
	for casa in _casas:
		_casas_linha.remove_child(casa)
		casa.queue_free()
	_casas.clear()
	for no in [_tecla_anterior, _painel, _tecla_proxima]:
		if no.get_parent() != null:
			no.get_parent().remove_child(no)
	_linha.add_child(_tecla_anterior)
	_linha.add_child(_painel)
	_linha.add_child(_tecla_proxima)
	for ferramenta in Fazenda.ferramentas():
		var casa := _nova_casa(ferramenta)
		_casas_linha.add_child(casa)
		_casas.append(casa)
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
	# Tocar (ou clicar) na casa escolhe a ferramenta: no celular não há Q/E
	casa.mouse_filter = Control.MOUSE_FILTER_STOP
	casa.add_to_group("toque_hud")
	casa.gui_input.connect(_ao_casa_tocada.bind(ferramenta))
	var lado := LADO_CASA_TOQUE if Controle.usando_toque else LADO_CASA
	casa.custom_minimum_size = Vector2(lado, lado)
	# o quadrado do sprite de slot, como no inventário e na barra de armas
	var fundo := Panel.new()
	fundo.name = "Fundo"
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_theme_stylebox_override("panel", EstiloSlot.caixa())
	casa.add_child(fundo)
	var recuo: float = RECUO_ICONE * lado / float(LADO_CASA)
	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.texture = IconesFazenda.da_ferramenta(ferramenta)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = recuo
	icone.offset_top = recuo
	icone.offset_right = -recuo
	icone.offset_bottom = -recuo
	casa.add_child(icone)
	# a ferramenta em uso: a moldura branca por fora (a mesma da arma em uso na arena)
	var marco := Panel.new()
	marco.name = "Marco"
	marco.visible = ativa
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	var estilo_marco := StyleBoxFlat.new()
	estilo_marco.bg_color = Color(1, 1, 1, 0.0)
	estilo_marco.set_border_width_all(1)
	estilo_marco.border_color = COR_ATIVA
	estilo_marco.set_corner_radius_all(3)
	estilo_marco.set_expand_margin_all(FOLGA_MARCO)
	marco.add_theme_stylebox_override("panel", estilo_marco)
	casa.add_child(marco)
	if ferramenta.begins_with(Fazenda.PREFIXO_SEMENTE):
		var quantidade := _novo_rotulo(COR_NOME)
		quantidade.text = str(Fazenda.quantidade_sementes(ferramenta.trim_prefix(Fazenda.PREFIXO_SEMENTE)))
		quantidade.add_theme_font_size_override("font_size", 6)
		quantidade.add_theme_constant_override("outline_size", 2)
		quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		quantidade.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		quantidade.grow_vertical = Control.GROW_DIRECTION_BEGIN
		quantidade.offset_right = -1
		quantidade.offset_bottom = 2
		casa.add_child(quantidade)
	return casa

func _ao_casa_tocada(evento: InputEvent, ferramenta: String) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		Fazenda.definir_ferramenta(ferramenta)
		accept_event()

## Mostra por alguns segundos por que a ação não pôde ser feita
func mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso != null and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(DURACAO_AVISO)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.4)
