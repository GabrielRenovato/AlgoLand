extends CanvasLayer

## Teclado na tela para digitar com o controle (nome do personagem).
## Direcional navega, o botão de baixo digita a tecla em foco, o da direita apaga a última letra e Start (ou o botão OK) confirma.
## As fontes pixel do jogo não têm acentos, então o teclado só tem letras sem acento, números, - e _

signal confirmado(texto: String)

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const FONTE_TECLA := preload("res://assets/ui/Planes_ValMore.ttf")
const LINHAS := ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-_", "0123456789"]
const CAMADA := 50
const LADO_TECLA := Vector2(18, 16)
const LADO_TECLA_TOQUE := Vector2(30, 21)
const PONTUACAO := ".,!?:;'()"
const COR_FUNDO := Color(0, 0, 0, 0.6)

var titulo_texto := "NOME DO PERSONAGEM"
var texto := ""
var max_caracteres := 12
## Chat precisa de pontuação; nomes continuam só com letras, números, - e _
var com_pontuacao := false
## Campo que abriu o teclado pelo toque (quem confirma decide o que fazer com ele)
var alvo: LineEdit

var _rotulo: Label
var _teclas: Array[Button] = []
var _botao_ok: Button
var _dica: Label

func _ready() -> void:
	layer = CAMADA
	visible = false
	_montar()
	Controle.dicas_alteradas.connect(_atualizar_dica)
	_atualizar_dica()

func abrir(texto_inicial: String, maximo: int = 12) -> void:
	max_caracteres = maximo
	texto = texto_inicial.to_upper().substr(0, maximo)
	_atualizar_rotulo()
	visible = true
	_teclas[0].grab_focus()

func fechar() -> void:
	visible = false
	confirmado.emit(texto)

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.theme = TEMA
	fundo.add_child(centro)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", preload("res://codigo/ui/estilo_interface.gd").painel())
	centro.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = titulo_texto
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)
	# Caixa com a mensagem sendo digitada, para ler tudo o que foi escrito (quebra em linhas)
	var caixa := PanelContainer.new()
	var estilo_caixa := StyleBoxFlat.new()
	estilo_caixa.bg_color = Color(0, 0, 0, 0.55)
	estilo_caixa.set_border_width_all(1)
	estilo_caixa.border_color = Color(0.96, 0.81, 0.48, 0.8)
	estilo_caixa.set_content_margin_all(4)
	caixa.add_theme_stylebox_override("panel", estilo_caixa)
	coluna.add_child(caixa)
	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _toque():
		_rotulo.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_rotulo.custom_minimum_size = Vector2(LADO_TECLA_TOQUE.x * 10 + 18, 30)
	caixa.add_child(_rotulo)

	var linhas: Array = LINHAS.duplicate()
	if com_pontuacao:
		linhas.append(PONTUACAO)
	for linha in linhas:
		var fileira := HBoxContainer.new()
		fileira.alignment = BoxContainer.ALIGNMENT_CENTER
		fileira.add_theme_constant_override("separation", 2)
		coluna.add_child(fileira)
		for letra in linha:
			fileira.add_child(_criar_tecla(letra, _digitar.bind(letra)))

	var acoes := HBoxContainer.new()
	acoes.alignment = BoxContainer.ALIGNMENT_CENTER
	acoes.add_theme_constant_override("separation", 4)
	coluna.add_child(acoes)
	acoes.add_child(_criar_tecla("ESPACO", _digitar.bind(" ")))
	acoes.add_child(_criar_tecla("APAGAR", _apagar))
	_botao_ok = _criar_tecla("OK", fechar)
	acoes.add_child(_botao_ok)

	_dica = Label.new()
	var dica := _dica
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.modulate = Color(1, 1, 1, 0.6)
	dica.visible = not _toque()
	coluna.add_child(dica)

# Letras como estão no controle em uso (no 8BitDo o botão de baixo é B e o menu é +)
func _atualizar_dica() -> void:
	_dica.text = "%s DIGITA   %s APAGA   %s CONFIRMA" % [Controle.rotulo_botao(JOY_BUTTON_A), Controle.rotulo_botao(JOY_BUTTON_B), Controle.rotulo_botao(JOY_BUTTON_START)]

func _criar_tecla(rotulo: String, acao: Callable) -> Button:
	var tecla := Button.new()
	tecla.text = rotulo
	# A letra X não pode virar o botão circular de fechar janela
	tecla.set_meta("tecla_virtual", true)
	tecla.custom_minimum_size = LADO_TECLA_TOQUE if _toque() else LADO_TECLA
	tecla.focus_mode = Control.FOCUS_ALL
	# Planes_ValMore: o Y da fonte do tema parece um "y" minúsculo
	tecla.add_theme_font_override("font", FONTE_TECLA)
	tecla.pressed.connect(acao)
	_teclas.append(tecla)
	return tecla

# Atalhos do controle e do teclado físico; tudo que chega aqui fica com o teclado virtual
func _input(evento: InputEvent) -> void:
	if not visible:
		return
	var start: bool = evento is InputEventJoypadButton and evento.button_index == JOY_BUTTON_START and evento.pressed
	var enter: bool = evento is InputEventKey and evento.pressed and evento.keycode in [KEY_ENTER, KEY_KP_ENTER]
	var apagar: bool = evento is InputEventKey and evento.pressed and evento.keycode == KEY_BACKSPACE
	if start or enter:
		fechar()
	elif apagar or evento.is_action_pressed("ui_cancel"):
		_apagar()
	else:
		return
	get_viewport().set_input_as_handled()

func _digitar(letra: String) -> void:
	if texto.length() >= max_caracteres:
		return
	texto += letra
	_atualizar_rotulo()

func _apagar() -> void:
	texto = texto.substr(0, maxi(texto.length() - 1, 0))
	_atualizar_rotulo()

func _toque() -> bool:
	return Controle.celular() or Controle.usando_toque

## No celular o teclado do sistema cobre o campo; o toque no campo abre este teclado, que mostra o que está sendo escrito
func ligar_toque(campo: LineEdit) -> void:
	if Controle.celular():
		campo.virtual_keyboard_enabled = false
	campo.gui_input.connect(func(evento: InputEvent) -> void:
		if not _toque() or not (evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT) or not campo.editable:
			return
		alvo = campo
		campo.release_focus()
		abrir(campo.text, campo.max_length if campo.max_length > 0 else 160)
		campo.accept_event())

func _atualizar_rotulo() -> void:
	var limite := 90 if _toque() else 24
	_rotulo.text = (("..."+texto.right(limite)) if texto.length()>limite else texto) + ("_" if texto.length() < max_caracteres else "")
