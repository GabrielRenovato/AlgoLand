extends CanvasLayer

const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const Controles := preload("res://codigo/dados/controles_personalizados.gd")
var lado := 1
var controle := false
var _capturando := ""
var _botoes := {}
var _aviso: Label
var _raiz: Control
var _painel: PanelContainer
var _coluna: VBoxContainer
var _origem: Control

func abrir(origem: Control, jogador := 1) -> void:
	_origem = origem
	lado = jogador
	controle = lado == 2
	origem.get_tree().root.add_child(self)
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("remapeando_controles")
	_raiz = Control.new()
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0,0,0,0.9)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for borda in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+borda,12)
	_raiz.add_child(margem)
	var centro := CenterContainer.new()
	margem.add_child(centro)
	_painel = PanelContainer.new()
	EstiloInicio.painel(_painel,false,10,true)
	centro.add_child(_painel)
	var coluna := VBoxContainer.new()
	_coluna = coluna
	coluna.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_painel.add_child(coluna)
	_aviso = Label.new()
	_aviso.text = "CONTROLES P%d - ESC CANCELA A CAPTURA" % lado
	_aviso.add_theme_font_size_override("font_size",10)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_aviso)
	var modo := Button.new()
	modo.text = "TECLADO / CONTROLE - ALTERNAR"
	modo.disabled = lado == 2
	modo.pressed.connect(func(): controle = not controle; _atualizar())
	coluna.add_child(modo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	for acao in Controles.ACOES:
		if lado == 2 and not InputMap.has_action("p2_"+acao): continue
		var botao := Button.new()
		botao.custom_minimum_size.y = 26
		botao.add_theme_font_size_override("font_size",9)
		botao.pressed.connect(_capturar.bind(String(acao)))
		lista.add_child(botao)
		_botoes[acao] = botao
	var restaurar := Button.new()
	restaurar.text = "RESTAURAR PADRAO"
	restaurar.pressed.connect(func(): Controles.restaurar(lado,controle); _atualizar())
	coluna.add_child(restaurar)
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.pressed.connect(_fechar)
	coluna.add_child(voltar)
	EstiloInicio.botoes_do_painel(_painel)
	_raiz.resized.connect(_ajustar_layout)
	_ajustar_layout()
	_atualizar()
	if lado == 2: _botoes.values()[0].grab_focus()
	else: modo.grab_focus()

func _ajustar_layout() -> void:
	_painel.custom_minimum_size = Vector2(minf(440,_raiz.size.x-24),_raiz.size.y-24)
	var compacto := _raiz.size.y < 300 or _raiz.size.x < 400
	_coluna.add_theme_constant_override("separation",3 if compacto else 6)
	_aviso.add_theme_font_size_override("font_size",8 if compacto else 10)
	for botao: Button in _painel.find_children("*","Button",true,false):
		botao.add_theme_font_size_override("font_size",8 if compacto else 9)
		botao.custom_minimum_size.y = 20 if compacto else 26

func _atualizar() -> void:
	for acao in _botoes:
		_botoes[acao].text = Controles.ACOES[acao] + " : " + Controles.rotulo(acao,lado,controle)

func _capturar(acao: String) -> void:
	_capturando = acao
	_aviso.text = "APERTE " + ("UM BOTAO OU EIXO DO CONTROLE" if controle else "UMA TECLA") + " - ESC CANCELA"

func _input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion: return
	if evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _capturando == "": _fechar()
		else:
			_capturando = ""
			_aviso.text = "CAPTURA CANCELADA"
		return
	if _capturando == "":
		var coop := get_node_or_null("/root/Cooperativo")
		if lado == 2 and coop != null and coop.ativo and (evento is InputEventJoypadButton or evento is InputEventJoypadMotion) and evento.device == coop.dispositivo_p2:
			var copia: InputEvent = evento.duplicate()
			copia.device = coop.dispositivo_p1
			get_viewport().set_input_as_handled()
			Input.parse_input_event(copia)
		return
	var valido: bool = (evento is InputEventJoypadButton and evento.pressed) or (evento is InputEventJoypadMotion and absf(evento.axis_value) > 0.8) if controle else (evento is InputEventKey and evento.pressed and not evento.echo)
	if not valido: return
	if controle:
		var coop := get_node_or_null("/root/Cooperativo")
		if coop != null and coop.ativo:
			var esperado: int = coop.dispositivo_p2 if lado == 2 else coop.dispositivo_p1
			if evento.device != esperado: return
	get_viewport().set_input_as_handled()
	var motivo := Controles.alterar(_capturando,evento,lado,controle)
	_aviso.text = "COMANDO SALVO" if motivo == "" else motivo
	if motivo == "": _capturando = ""
	_atualizar()

func _fechar() -> void:
	if is_instance_valid(_origem): _origem.grab_focus()
	queue_free()
