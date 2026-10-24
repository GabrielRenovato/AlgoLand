extends Button

var tela: Control
var ajuda: Label
var selecionando := false
var pendente: DadosItem
var _cobertura: Control
var _texto: Label
var _confirmar: Button

func _ready() -> void:
	name = "Lixeira"
	custom_minimum_size = Vector2(32,32)
	toggle_mode = true
	tooltip_text = "LIXEIRA: ARRASTE UM ITEM OU TOQUE PARA ESCOLHER"
	pressed.connect(_ao_pressionar)
	tela.visibility_changed.connect(_ao_visibilidade)
	_montar_confirmacao()
	_ajudar("LIXEIRA: EXCLUIR ITENS")

func _draw() -> void:
	# Contraste com o pergaminho claro do botão, mantendo o desenho centralizado.
	var cor := Color("3e2416")
	var origem := ((size - Vector2(32,32)) / 2).floor()
	draw_rect(Rect2(origem+Vector2(11,12),Vector2(10,13)),cor,false,1)
	draw_rect(Rect2(origem+Vector2(9,9),Vector2(14,2)),cor)
	draw_rect(Rect2(origem+Vector2(14,6),Vector2(4,2)),cor)
	for x in [14,17]: draw_rect(Rect2(origem+Vector2(x,15),Vector2(1,7)),cor)

func _ajudar(texto: String) -> void:
	if ajuda != null: ajuda.text = texto

func _ao_pressionar() -> void:
	var interface := EventosJogo.interface_de(self)
	if interface.item_carregado != null:
		button_pressed = false
		solicitar(interface.item_carregado)
		return
	selecionando = button_pressed
	_ajudar("TOQUE NUM ITEM PARA EXCLUIR" if selecionando else "LIXEIRA: EXCLUIR ITENS")

func _pode_excluir(item: DadosItem) -> bool:
	if item == null or EventosJogo.inventario_de(self).indice_de(item) < 0:
		return false
	for slot in tela._slots_mochila:
		if slot.item_atual == item and slot.item_ui().em_uso:
			return false
	return true

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
	return dados is Dictionary and dados.get("item") is DadosItem and _pode_excluir(dados["item"])

func _drop_data(_posicao: Vector2, dados: Variant) -> void:
	if _can_drop_data(_posicao,dados): solicitar(dados["item"])

func solicitar(item: DadosItem) -> void:
	if not _pode_excluir(item):
		_ajudar("DESEQUIPE OU RETIRE O ITEM DO SERVICO")
		Sons.tocar("erro",0)
		return
	pendente = item
	_texto.text = "EXCLUIR %s%s?\nO ITEM SERA REMOVIDO DA MOCHILA." % [item.nome()," x%d" % item.quantidade if item.empilhavel() else ""]
	_cobertura.show()
	Controle.focar(_confirmar)

func confirmar() -> void:
	if not _pode_excluir(pendente) or not EventosJogo.inventario_de(self).excluir_item(pendente):
		_ajudar("NAO FOI POSSIVEL EXCLUIR O ITEM")
		cancelar()
		return
	var interface := EventosJogo.interface_de(self)
	if interface.item_carregado == pendente: interface.definir_carregado(null)
	_ajudar("ITEM EXCLUIDO")
	selecionando = false
	button_pressed = false
	cancelar()

func cancelar() -> void:
	pendente = null
	_cobertura.hide()
	if is_visible_in_tree(): Controle.focar(self)

func _ao_visibilidade() -> void:
	if not tela.visible:
		selecionando = false
		button_pressed = false
		pendente = null
		_cobertura.hide()

func _input(evento: InputEvent) -> void:
	if is_instance_valid(_cobertura) and _cobertura.is_visible_in_tree() and (evento.is_action_pressed("close_menu") or evento.is_action_pressed("ui_cancel")):
		cancelar()
		get_viewport().set_input_as_handled()

func _montar_confirmacao() -> void:
	_cobertura = Control.new()
	_cobertura.name = "ConfirmarExclusao"
	_cobertura.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_cobertura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cobertura.z_index = 40
	tela.add_child(_cobertura)
	var fundo := ColorRect.new()
	fundo.color = Color(0,0,0,0.65)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cobertura.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cobertura.add_child(centro)
	var painel := PanelContainer.new()
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").painel(painel,false,10)
	centro.add_child(painel)
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation",8)
	painel.add_child(linhas)
	_texto = Label.new()
	_texto.custom_minimum_size.x = 180
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size",9)
	linhas.add_child(_texto)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation",6)
	linhas.add_child(botoes)
	for titulo in ["CANCELAR","EXCLUIR"]:
		var botao := Button.new()
		botao.text = titulo
		preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(botao,titulo == "EXCLUIR",16.0)
		botao.custom_minimum_size.y = 32
		botao.size_flags_horizontal = SIZE_EXPAND_FILL
		botoes.add_child(botao)
		if titulo == "EXCLUIR":
			_confirmar = botao
			botao.pressed.connect(confirmar)
		else:
			botao.pressed.connect(cancelar)
	_cobertura.hide()
