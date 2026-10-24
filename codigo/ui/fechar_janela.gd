extends Node
## Preserva o botão, seu caminho e sinais; só muda apresentação e encaixe.
const Escala := preload("res://codigo/ui/escala_interface.gd")
var botao: Button
var painel: Control
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _pressionado: StyleBoxFlat
var _foco: StyleBoxFlat

static func ligar(alvo: Button) -> void:
	if alvo.has_meta("fechar_circular"): return
	var moldura: Node = alvo.get_parent()
	while moldura is Control and not (moldura is Panel or moldura is PanelContainer or moldura is NinePatchRect or moldura.get_node_or_null("Fundo") is NinePatchRect):
		moldura = moldura.get_parent()
	if not moldura is Control: return
	var componente = load("res://codigo/ui/fechar_janela.gd").new()
	componente.botao = alvo
	componente.painel = moldura
	alvo.set_meta("fechar_circular",true)
	alvo.add_child(componente)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 200
	_normal = _estilo(Color("b88b50"),Color("503522"))
	_hover = _estilo(Color("dfb974"),Color("6d4728"))
	_pressionado = _estilo(Color("967044"),Color("3e291e"))
	_foco = _estilo(Color.TRANSPARENT,Color("fff0b1"))
	_foco.draw_center = false
	botao.set_as_top_level(true)
	botao.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	botao.z_index = 20
	botao.tooltip_text = "FECHAR JANELA"
	_process(0)

func _estilo(fundo: Color,borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(32)
	estilo.anti_aliasing = true
	for lado in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:estilo.set_content_margin(lado,0)
	return estilo

func _process(_delta: float) -> void:
	if not is_instance_valid(painel): return
	if botao.get_theme_stylebox("normal") != _normal:
		for estado in ["normal","disabled"]:botao.add_theme_stylebox_override(estado,_normal)
		for estado in ["hover","hover_pressed"]:botao.add_theme_stylebox_override(estado,_hover)
		botao.add_theme_stylebox_override("pressed",_pressionado)
		botao.add_theme_stylebox_override("focus",_foco)
		botao.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
		botao.add_theme_font_size_override("font_size",10)
		for estado in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:botao.add_theme_color_override(estado,Color("2d211c"))
		for filho in botao.get_children():
			if filho is CanvasItem:filho.hide()
	botao.text = "X"
	if not botao.is_visible_in_tree(): return
	# No toque: alvo maior e afastado das bordas da tela (o iPhone reserva a borda de cima para gestos do sistema)
	var toque: bool = botao.get_node_or_null("/root/Controle") != null and botao.get_node("/root/Controle").usando_toque
	var diametro := maxf(30 if toque else 24,botao.custom_minimum_size.y)
	var margem := 14.0 if toque else 2.0
	botao.custom_minimum_size = Vector2.ONE*diametro
	botao.size = Vector2.ONE*diametro
	var rect := painel.get_global_rect()
	var limite := Escala.tamanho_logico(botao)
	var alvo := Vector2(rect.end.x-diametro*0.5-4,rect.position.y-diametro*0.5+4)
	botao.global_position = alvo.clamp(Vector2(margem,margem),limite-botao.size-Vector2(margem,margem)).round()
