extends ColorRect
## Ajuste RGB compacto, com o mesmo espaço interno da criação.
signal cor_alterada(cor: Color)
const Estilo := preload("res://codigo/ui/estilo_criacao_fazenda.gd")
var cor := Color.WHITE
var controles: Array[SpinBox]=[]
var painel: PanelContainer
var amostra: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=200
	color=Color(0,0,0,.65)
	var centro:=CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	painel=PanelContainer.new()
	painel.custom_minimum_size=Vector2(240,0)
	Estilo.painel(painel,12)
	centro.add_child(painel)
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",6)
	painel.add_child(coluna)
	coluna.add_child(Estilo.rotulo("COR DA PELE · RGB",12))
	amostra=ColorRect.new()
	amostra.color=cor
	amostra.custom_minimum_size.y=20
	coluna.add_child(amostra)
	for i in 3:
		var linha:=HBoxContainer.new()
		linha.add_theme_constant_override("separation",8)
		coluna.add_child(linha)
		var nome:=Estilo.rotulo(["R","G","B"][i],10)
		nome.custom_minimum_size.x=12
		linha.add_child(nome)
		var slider:=HSlider.new()
		slider.max_value=255
		slider.step=1
		slider.value=roundi(cor[i]*255)
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size=Vector2(88,24)
		linha.add_child(slider)
		var numero:=SpinBox.new()
		numero.max_value=255
		numero.step=1
		numero.value=slider.value
		numero.custom_minimum_size=Vector2(64,24)
		var campo:=numero.get_line_edit()
		campo.add_theme_font_override("font",Estilo.FONTE)
		campo.add_theme_font_size_override("font_size",11)
		campo.add_theme_color_override("font_color",Estilo.TINTA)
		campo.add_theme_stylebox_override("normal",Estilo.caixa(Color("fff0c9"),Estilo.MADEIRA,4,1))
		campo.add_theme_stylebox_override("focus",Estilo.caixa(Color("fff5dc"),Estilo.MADEIRA,4,2))
		linha.add_child(numero)
		controles.append(numero)
		slider.value_changed.connect(func(valor): numero.set_value_no_signal(valor); _alterar(valor,i))
		numero.value_changed.connect(func(valor): slider.set_value_no_signal(valor); _alterar(valor,i))
	var fechar:=Button.new()
	fechar.text="PRONTO"
	Estilo.botao(fechar,true)
	fechar.custom_minimum_size.y=28
	fechar.pressed.connect(queue_free)
	coluna.add_child(fechar)
	fechar.grab_focus()

func _alterar(valor: float, canal: int) -> void:
	cor[canal]=valor/255.0
	amostra.color=cor
	cor_alterada.emit(cor)

func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("close_menu"):
		get_viewport().set_input_as_handled()
		queue_free()
