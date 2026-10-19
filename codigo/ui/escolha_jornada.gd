extends CanvasLayer

## Escolha compartilhada: pausa o combate, respeita o viewport de quem interagiu e restaura o estado ao fechar.
signal escolhida(id: String)
var _pausa_anterior := false
var _fechando := false
var _raiz: Control
var _quem: Node
var _painel: PanelContainer
var _rotulos: Array[Label] = []

func abrir(quem: Node, titulo: String, texto: String, opcoes: Array) -> void:
	_quem = quem
	quem.get_viewport().add_child(self)
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pausa_anterior = get_tree().paused
	get_tree().paused = true
	_raiz = Control.new()
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.65)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)
	var painel := PanelContainer.new()
	_painel = painel
	painel.theme = preload("res://recursos/ui/tema_sidebar.tres")
	painel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(false,8))
	centro.add_child(painel)
	var largura := minf(300, quem.get_viewport().get_visible_rect().size.x - 24)
	painel.custom_minimum_size.x = largura
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]: margem.add_theme_constant_override("margin_"+lado, 10)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	margem.add_child(coluna)
	for mensagem in [titulo, texto]:
		var rotulo := Label.new()
		rotulo.text = mensagem
		rotulo.custom_minimum_size.x = largura - 40
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rotulo.add_theme_font_size_override("font_size", 10)
		coluna.add_child(rotulo)
		_rotulos.append(rotulo)
	for opcao in opcoes:
		var botao := Button.new()
		botao.text = opcao.nome
		botao.custom_minimum_size.y = 28
		botao.add_theme_font_size_override("font_size", 9)
		botao.pressed.connect(_escolher.bind(String(opcao.id)))
		coluna.add_child(botao)
		if coluna.get_child_count() == 3: botao.grab_focus()
	_raiz.resized.connect(_ajustar)
	_quem.tree_exiting.connect(_escolher.bind(""),CONNECT_ONE_SHOT)

func _ajustar() -> void:
	if not is_instance_valid(_quem) or _painel == null: return
	var largura := minf(300,_quem.get_viewport().get_visible_rect().size.x-24)
	_painel.custom_minimum_size.x = largura
	for rotulo in _rotulos: rotulo.custom_minimum_size.x = largura-40
	_painel.reset_size()

func _unhandled_input(evento: InputEvent) -> void:
	if is_instance_valid(_quem) and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_escolher("")

func _escolher(id: String) -> void:
	if _fechando: return
	_fechando = true
	get_tree().paused = _pausa_anterior
	get_viewport().gui_release_focus()
	for acao in ["attack", "open_menu", "aparar", "rolar"]:
		Input.action_release(acao)
		if InputMap.has_action("p2_"+acao): Input.action_release("p2_"+acao)
	escolhida.emit(id)
	queue_free()

func _exit_tree() -> void:
	if not _fechando and get_tree() != null: get_tree().paused = _pausa_anterior
