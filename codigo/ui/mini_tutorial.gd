extends Control

## Lembrete compacto de comandos; acompanha o teclado ou o controle em uso.
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const ACOES := [["attack", "ATACAR"], ["rolar", "ESQUIVAR"], ["aparar", "DEFENDER"],
	["open_menu", "INTERAGIR"], ["usar_pocao", "BEBER POCAO"],
	["open_inventory", "MOCHILA"], ["arma_proxima", "TROCAR ARMA"], ["pausar", "PAUSA"], ["open_map", "MAPA"]]

const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
## Fechado com o X (ou L3 no controle): fica guardado em user://opcoes.cfg e não volta mais, nem ao reabrir o jogo.
## Lido uma vez por execução; -1 = ainda não lido
static var _fechado := -1

## No controle o quadro fecha com o clique no analógico esquerdo (não está ligado a nenhuma ação do jogo)
const BOTAO_FECHAR_CONTROLE := JOY_BUTTON_LEFT_STICK

var _painel: PanelContainer
var _botao_fechar: Button
var _teclas: Array[Label] = []
var _interface: Node
var _acoes: Array = []
var _fechado_na_introducao := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "MiniTutorial"
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface = EventosJogo.interface_de(self)
	_acoes = ACOES.duplicate(true)
	var cena := get_tree().current_scene
	if cena != null and bool(cena.get_meta("barra_ferramentas", false)):
		_acoes[0][1] = "USAR FERRAMENTA"
		_acoes[2] = ["colher", "COLHER"]
		_acoes[6] = ["ferramenta_proxima", "FERRAMENTA"]
		_acoes.remove_at(4)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo: StyleBoxTexture = TEMA.get_stylebox("panel", "MolduraSlot").duplicate()
	estilo.region_rect = Rect2(0, 0, 24, 24)
	estilo.modulate_color = Color(1.0, 0.95, 0.85, 0.9)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		estilo.set_content_margin(lado, 6)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation", 3)
	_painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	cabecalho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(cabecalho)
	var titulo := _rotulo("CONTROLES", Color(1, 0.88, 0.6))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	var fechar := Button.new()
	_botao_fechar = fechar
	fechar.name = "BotaoFechar"
	fechar.text = "X"
	fechar.flat = true
	fechar.focus_mode = Control.FOCUS_NONE
	fechar.tooltip_text = "FECHAR"
	fechar.add_theme_font_size_override("font_size", 8)
	fechar.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	fechar.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.8))
	fechar.pressed.connect(_ao_fechar)
	cabecalho.add_child(fechar)
	var grade := GridContainer.new()
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 7)
	grade.add_theme_constant_override("v_separation", 1)
	coluna.add_child(grade)
	for i in _acoes.size() + 1:
		var tecla := _rotulo("", Color(1, 0.94, 0.76))
		_teclas.append(tecla)
		grade.add_child(tecla)
		grade.add_child(_rotulo("MOVER" if i == 0 else _acoes[i - 1][1], Color(0.85, 0.86, 0.9)))
	Controle.dicas_alteradas.connect(_atualizar)
	_painel.minimum_size_changed.connect(_encaixar.call_deferred)
	_atualizar()

func _ao_fechar() -> void:
	if Introducao.etapa == Introducao.Etapa.COMBATE:
		_fechado_na_introducao = true
		visible = false
		return
	_fechado = 1
	Opcoes.fechar_mini_tutorial()
	visible = false

static func esta_fechado() -> bool:
	if _fechado < 0:
		_fechado = 1 if Opcoes.mini_tutorial_fechado() else 0
	return _fechado == 1

func _input(evento: InputEvent) -> void:
	if visible and evento is InputEventJoypadButton and evento.pressed and evento.button_index == BOTAO_FECHAR_CONTROLE:
		get_viewport().set_input_as_handled()
		_ao_fechar()

func _rotulo(texto: String, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", 8)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

func _atualizar() -> void:
	_botao_fechar.text = "%s X" % Controle.rotulo_botao(BOTAO_FECHAR_CONTROLE) if Controle.usando_controle else "X"
	_teclas[0].text = "ANALOGICO" if Controle.usando_controle else "".join([Controle.rotulo_acao("move_up"),Controle.rotulo_acao("move_left"),Controle.rotulo_acao("move_down"),Controle.rotulo_acao("move_right")])
	for i in _acoes.size():
		var tecla := Controle.rotulo_acao(_acoes[i][0]).replace("SPACE", "ESPACO").replace("ESCAPE", "ESC")
		if tecla.is_empty() and Controle.usando_controle:
			for evento in InputMap.action_get_events(_acoes[i][0]):
				if evento is InputEventJoypadButton and evento.button_index == JOY_BUTTON_GUIDE:
					tecla = "GUIA"
		if _acoes[i][0] == "attack" and not Controle.usando_controle:
			tecla = "CLIQUE / " + tecla
		_teclas[i + 1].text = "SEGURAR " + tecla if _acoes[i][0] == "open_map" and Controle.usando_controle else tecla
	_painel.reset_size()
	_encaixar.call_deferred()

func _encaixar() -> void:
	if not is_inside_tree():
		return
	var margens := Controle.margens_seguras()
	_painel.reset_size()
	_painel.offset_left = -8 - margens.z - _painel.size.x
	_painel.offset_right = -8 - margens.z
	# Na metade estreita, deixa a barra de itens livre embaixo do lembrete.
	var rodape := 52.0 if get_viewport().has_meta("dono") else 8.0
	_painel.offset_top = -rodape - margens.w - _painel.size.y
	_painel.offset_bottom = -rodape - margens.w

func _process(_delta: float) -> void:
	# Menus e botões de toque já apresentam seus próprios comandos.
	var exibir := (Introducao.etapa == Introducao.Etapa.COMBATE and not _fechado_na_introducao) if Introducao.ativa() else not esta_fechado()
	visible = exibir and not Controle.usando_toque and (not is_instance_valid(_interface) or _interface._telas_abertas.is_empty())
