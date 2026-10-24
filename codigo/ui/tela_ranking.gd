extends Control
## Consulta pública do ranking, independente da tela de fim de partida e da metade do cooperativo.
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
var painel: PanelContainer
var _lista: VBoxContainer
var _estado: Label
var _fechar: Button
var _atualizar: Button
var _rolagem: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(false,8.0))
	add_child(painel)
	painel.minimum_size_changed.connect(func() -> void: _ajustar.call_deferred())
	var margem := MarginContainer.new()
	for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,8)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",6)
	margem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "RANKING DA ARENA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color",Color("f5cf7a"))
	coluna.add_child(titulo)
	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.add_theme_font_size_override("font_size",7)
	coluna.add_child(_estado)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.size_flags_vertical = SIZE_EXPAND_FILL
	_rolagem.follow_focus = true
	coluna.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation",5)
	var folga_lista := MarginContainer.new()
	folga_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	folga_lista.add_theme_constant_override("margin_right",8)
	_rolagem.add_child(folga_lista)
	folga_lista.add_child(_lista)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation",8)
	coluna.add_child(botoes)
	_atualizar = Button.new()
	_atualizar.text = "ATUALIZAR"
	_atualizar.custom_minimum_size.y = 28
	_atualizar.size_flags_horizontal = SIZE_EXPAND_FILL
	_atualizar.pressed.connect(_buscar)
	botoes.add_child(_atualizar)
	_fechar = Button.new()
	_fechar.text = "VOLTAR"
	_fechar.size_flags_horizontal = SIZE_EXPAND_FILL
	_fechar.pressed.connect(func() -> void: EventosJogo.fechar_tela_de(self,"ranking"))
	botoes.add_child(_fechar)
	Ranking.lista_atualizada.connect(_mostrar)
	Ranking.para_jogador(EventosJogo.dono(self)).envio_concluido.connect(_ao_envio_perfil)
	visibility_changed.connect(_ao_abrir)
	resized.connect(_ajustar)
	_ajustar()

func _ajustar() -> void:
	if painel == null: return
	var dimensoes := Vector2(minf(400,size.x-24),minf(300,size.y-24))
	painel.size = dimensoes
	painel.position = ((size-dimensoes)*0.5).floor()
	if _lista == null: return
	for caixa in _lista.get_children():
		var apelido: Label = caixa.get_child(1)
		var largura := maxf(60.0,dimensoes.x-32-22-12-60-12)
		var fonte := apelido.get_theme_font("font")
		var tamanho := 8
		while tamanho > 5 and fonte.get_string_size(apelido.text,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho).x > largura:
			tamanho -= 1
		apelido.add_theme_font_size_override("font_size",tamanho)

func _ao_abrir() -> void:
	if not visible: return
	_mostrar(Ranking.lista_cache)
	_buscar()

func _buscar() -> void:
	_estado.text = "CONSULTANDO O RANKING..."
	Ranking.buscar()

func _mostrar(lista: Array) -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_estado.text = Ranking.erro_consulta if not Ranking.erro_consulta.is_empty() else ("AINDA NAO HA COLOCADOS" if lista.is_empty() else "MELHORES ANDARES - TOP %d" % lista.size())
	for i in lista.size():
		var linha: Dictionary = lista[i]
		var caixa := HBoxContainer.new()
		caixa.add_theme_constant_override("separation",6)
		_lista.add_child(caixa)
		var posicao := Label.new()
		posicao.text = "%02d." % (i+1)
		posicao.custom_minimum_size.x = 22
		caixa.add_child(posicao)
		var apelido := Label.new()
		apelido.text = str(linha.get("apelido",""))
		apelido.clip_text = true
		apelido.size_flags_horizontal = SIZE_EXPAND_FILL
		apelido.add_theme_font_size_override("font_size",8)
		caixa.add_child(apelido)
		var andar := Label.new()
		andar.text = "ANDAR %d" % int(linha.get("andar",0))
		andar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caixa.add_child(andar)
	_ajustar.call_deferred()

func focar_inicio() -> void:
	_fechar.grab_focus()

func _process(delta: float) -> void:
	if not visible: return
	# O mesmo analógico usado nos demais painéis da vila, por jogador.
	var eixo := Input.get_joy_axis(_dispositivo(),JOY_AXIS_RIGHT_Y)
	if absf(eixo) > 0.2: _rolagem.scroll_vertical += int(eixo*240.0*delta)

func _input(evento: InputEvent) -> void:
	if not visible: return
	if evento is InputEventKey and EventosJogo.eh_do_p2(self): return
	if not (evento is InputEventKey or evento is InputEventJoypadButton): return
	if evento is InputEventJoypadButton and _dispositivo() >= 0 and evento.device != _dispositivo(): return
	var passo := 0
	if evento.is_action_pressed("ui_down",true): passo = 28
	elif evento.is_action_pressed("ui_up",true): passo = -28
	if passo == 0: return
	var antes := _rolagem.scroll_vertical
	_rolagem.scroll_vertical += passo
	if antes != _rolagem.scroll_vertical: get_viewport().set_input_as_handled()

func _dispositivo() -> int:
	if EventosJogo.eh_do_p2(self) and Cooperativo.ativo: return Cooperativo.dispositivo_p2
	return Cooperativo.dispositivo_p1 if Cooperativo.ativo and Cooperativo.dispositivo_p1 >= 0 else Controle.dispositivo

func _ao_envio_perfil(erro: String) -> void:
	if not visible: return
	if not erro.is_empty(): _estado.text = erro
