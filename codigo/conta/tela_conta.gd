extends CanvasLayer
## Entrar, criar conta e recuperar senha. Abre sobre a tela inicial; com CONTA_OBRIGATORIA não dá para fechar sem entrar.
signal concluida
const Cliente := preload("res://codigo/conta/cliente_conta.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const COR_FUNDO := Color(0.17, 0.11, 0.10, 0.98)
const COR_BORDA := Color(0.55, 0.38, 0.24)
const COR_LINHA := Color(0.25, 0.17, 0.14)
const COR_PALCO := Color(0.12, 0.08, 0.08)
const COR_TEXTO := Color(0.97, 0.90, 0.76)
const COR_SUAVE := Color(0.78, 0.68, 0.55)
const COR_OURO := Color("ffd966")
const COR_ERRO := Color("ff8a80")
const COR_OK := Color("8de08d")
const COR_BOTAO := Color(0.34, 0.22, 0.16)
const COR_DESTAQUE := Color(0.27, 0.50, 0.24)

enum Modo { ENTRAR, CRIAR, RECUPERAR }
var conta: Node
var _modo := Modo.ENTRAR
var _caixa: VBoxContainer
var _email: LineEdit
var _senha: LineEdit
var _apelido: LineEdit
var _mensagem: Label
var _enviar: Button
var _ver_senha: CheckBox

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	conta = Cliente.obter(get_tree())
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.78)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(minf(330.0, get_viewport().get_visible_rect().size.x - 24.0), 0)
	painel.add_theme_stylebox_override("panel", _caixa_estilo(COR_FUNDO, COR_BORDA, 5, 2, 12))
	centro.add_child(painel)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 6)
	painel.add_child(_caixa)
	_montar()

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel") and not Cliente.CONTA_OBRIGATORIA:
		get_viewport().set_input_as_handled()
		queue_free()

# --- Montagem

func _montar() -> void:
	for filho in _caixa.get_children():
		_caixa.remove_child(filho)
		filho.queue_free()
	_caixa.add_child(_rotulo("CONTA", 16, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT))
	var explicacao := {
		Modo.ENTRAR: "Entre para guardar seu progresso e jogar em qualquer aparelho.",
		Modo.CRIAR: "Crie sua conta. Se voce ja joga, seu progresso atual fica guardado nela.",
		Modo.RECUPERAR: "Informe o e-mail da conta. Enviamos um link para criar outra senha.",
	}
	_caixa.add_child(_rotulo(explicacao[_modo], 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
	_email = _campo("E-MAIL", 120)
	_email.text = conta.email
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_caixa.add_child(_email)
	_senha = null
	_apelido = null
	_ver_senha = null
	if _modo != Modo.RECUPERAR:
		_senha = _campo("SENHA (8 OU MAIS CARACTERES)" if _modo == Modo.CRIAR else "SENHA", 72)
		_senha.secret = true
		_caixa.add_child(_senha)
		_ver_senha = CheckBox.new()
		_ver_senha.text = "MOSTRAR SENHA"
		_ver_senha.add_theme_font_override("font", FONTE)
		_ver_senha.add_theme_font_size_override("font_size", 8)
		_ver_senha.add_theme_color_override("font_color", COR_SUAVE)
		_ver_senha.add_theme_color_override("font_hover_color", COR_TEXTO)
		_ver_senha.add_theme_color_override("font_pressed_color", COR_TEXTO)
		# Sem o fundo de pergaminho do tema do jogo: só o quadradinho e o texto.
		for estado in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			_ver_senha.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
		_ver_senha.toggled.connect(func(ligado: bool): _senha.secret = not ligado)
		_caixa.add_child(_ver_senha)
	if _modo == Modo.CRIAR:
		_apelido = _campo("APELIDO NO JOGO", 24)
		var atual := str(get_tree().root.get_node("Ranking").get("apelido")) if get_tree().root.has_node("Ranking") else ""
		_apelido.text = "" if atual.is_empty() or atual.to_lower() == "sem apelido" else atual
		_caixa.add_child(_apelido)
	_mensagem = _rotulo("", 8, COR_ERRO, HORIZONTAL_ALIGNMENT_LEFT)
	_mensagem.custom_minimum_size.y = 20
	_caixa.add_child(_mensagem)
	_enviar = _botao({Modo.ENTRAR: "ENTRAR", Modo.CRIAR: "CRIAR CONTA", Modo.RECUPERAR: "ENVIAR LINK"}[_modo], _enviar_formulario, COR_DESTAQUE, Vector2(0, 32))
	_caixa.add_child(_enviar)
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 6)
	_caixa.add_child(rodape)
	if _modo == Modo.ENTRAR:
		rodape.add_child(_botao("CRIAR CONTA", _trocar.bind(Modo.CRIAR), COR_BOTAO, Vector2(0, 26), true))
		rodape.add_child(_botao("ESQUECI A SENHA", _trocar.bind(Modo.RECUPERAR), COR_BOTAO, Vector2(0, 26), true))
	else:
		rodape.add_child(_botao("JA TENHO CONTA", _trocar.bind(Modo.ENTRAR), COR_BOTAO, Vector2(0, 26), true))
	if not Cliente.CONTA_OBRIGATORIA:
		_caixa.add_child(_botao("AGORA NAO", queue_free, COR_LINHA, Vector2(0, 24)))
	for campo in [_email, _senha, _apelido]:
		if campo != null: campo.text_submitted.connect(func(_t): _enviar_formulario())
	_email.grab_focus.call_deferred()

func _trocar(modo: Modo) -> void:
	_modo = modo
	_montar()

# --- Envio

func _enviar_formulario() -> void:
	if conta.ocupado(): return
	_enviar.disabled = true
	_avisar("AGUARDE...", COR_SUAVE)
	var erro := ""
	match _modo:
		Modo.ENTRAR: erro = await conta.entrar(_email.text, _senha.text)
		Modo.CRIAR: erro = await conta.criar(_email.text, _senha.text, _apelido.text)
		Modo.RECUPERAR: erro = await conta.recuperar(_email.text)
	if not is_instance_valid(self): return
	_enviar.disabled = false
	if erro == "CONFIRMAR_EMAIL":
		_modo = Modo.ENTRAR
		_montar()
		_avisar("CONTA CRIADA! CONFIRME O E-MAIL E ENTRE.", COR_OK)
	elif not erro.is_empty():
		_avisar(erro, COR_ERRO)
	elif _modo == Modo.RECUPERAR:
		_modo = Modo.ENTRAR
		_montar()
		_avisar("LINK ENVIADO. CONFIRA SEU E-MAIL.", COR_OK)
	else:
		concluida.emit()
		queue_free()

func _avisar(texto: String, cor: Color) -> void:
	if is_instance_valid(_mensagem):
		_mensagem.text = texto
		_mensagem.add_theme_color_override("font_color", cor)

# --- Componentes

func _caixa_estilo(fundo: Color, borda: Color, raio := 3, largura := 1, margem := 0) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fundo
	c.border_color = borda
	c.set_border_width_all(largura)
	c.set_corner_radius_all(raio)
	c.set_content_margin_all(margem)
	return c

func _rotulo(texto: String, tamanho: int, cor: Color, alinhamento := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = alinhamento
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo

func _campo(dica: String, maximo: int) -> LineEdit:
	var campo := LineEdit.new()
	campo.placeholder_text = dica
	campo.max_length = maximo
	campo.custom_minimum_size = Vector2(0, 30)
	campo.add_theme_font_override("font", FONTE)
	campo.add_theme_font_size_override("font_size", 10)
	campo.add_theme_color_override("font_color", COR_TEXTO)
	campo.add_theme_color_override("font_placeholder_color", Color(COR_SUAVE, 0.55))
	for tipo in ["normal", "focus", "read_only"]:
		campo.add_theme_stylebox_override(tipo, _caixa_estilo(COR_PALCO, COR_OURO if tipo == "focus" else COR_BORDA, 3, 1, 6))
	return campo

func _botao(texto: String, acao: Callable, cor := COR_BOTAO, minimo := Vector2(0, 30), expandir := false) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = minimo
	if expandir: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_override("font", FONTE)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45))
	b.add_theme_stylebox_override("normal", _caixa_estilo(cor, cor.lightened(0.3), 3, 1, 5))
	b.add_theme_stylebox_override("hover", _caixa_estilo(cor.lightened(0.15), COR_OURO, 3, 1, 5))
	b.add_theme_stylebox_override("pressed", _caixa_estilo(cor.darkened(0.2), cor.lightened(0.2), 3, 1, 5))
	b.add_theme_stylebox_override("disabled", _caixa_estilo(Color(0.2, 0.16, 0.15), Color(0.32, 0.27, 0.25), 3, 1, 5))
	b.add_theme_stylebox_override("focus", _caixa_estilo(Color(0, 0, 0, 0), COR_OURO, 3, 2, 5))
	b.pressed.connect(acao)
	return b
