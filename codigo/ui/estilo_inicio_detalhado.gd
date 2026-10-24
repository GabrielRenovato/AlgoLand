extends RefCounted

## Acabamento das telas de início e criação de personagem. A arte em alta resolução usa nove partes em escala 1/8.
## O layout continua nas coordenadas lógicas do jogo; textos e foco permanecem nos controles nativos.
const ATLAS := preload("res://assets/ui/inicio_detalhado/atlas.png")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const FONTE_TITULO := preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf")
const ESCALA := 8.0

static func espaco(margem: float) -> StyleBoxEmpty:
	var estilo := StyleBoxEmpty.new()
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: estilo.set_content_margin(lado,margem)
	return estilo

static func fundo(controle: Control, celula: Vector2i, escala := ESCALA, opaco := false) -> NinePatchRect:
	var recorte := AtlasTexture.new()
	recorte.atlas = ATLAS
	var lado := ATLAS.get_width()/2.0
	recorte.region = Rect2(Vector2(celula)*lado,Vector2.ONE*lado)
	recorte.filter_clip = true
	var arte := NinePatchRect.new()
	arte.name = "AcabamentoInicio"
	arte.texture = recorte
	if opaco:
		var material := ShaderMaterial.new()
		material.shader = preload("res://codigo/ui/fundo_interface_opaco.gdshader")
		arte.material = material
	arte.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arte.show_behind_parent = true
	arte.scale = Vector2.ONE/escala
	arte.set_meta("escala_pintura",escala)
	for borda in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: arte.set_patch_margin(borda,64)
	var camada := Node2D.new()
	camada.name = "PinturaInicio"
	camada.show_behind_parent = true
	controle.add_child(camada)
	camada.add_child(arte)
	var ajustar := func(): arte.size = controle.size*float(arte.get_meta("escala_pintura"))
	controle.resized.connect(ajustar)
	ajustar.call()
	return arte

static func painel(controle: Control, claro := false, margem := 14.0, opaco := false) -> void:
	controle.add_theme_stylebox_override("panel",espaco(margem))
	fundo(controle,Vector2i(1,0) if claro else Vector2i.ZERO,ESCALA,opaco)

static func botao(controle: Button, principal := false, escala := ESCALA) -> void:
	for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var estilo := espaco(10)
		estilo.content_margin_top = 2
		estilo.content_margin_bottom = 2
		controle.add_theme_stylebox_override(estado,estilo)
	controle.add_theme_font_override("font",FONTE)
	controle.add_theme_font_size_override("font_size",10)
	controle.add_theme_constant_override("outline_size",0)
	var cor := Color("f8efd6") if principal else Color("49321e")
	for estado in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		controle.add_theme_color_override(estado,cor)
	controle.add_theme_color_override("font_disabled_color",Color("85765e"))
	var arte := fundo(controle,Vector2i(0,1) if principal else Vector2i(1,0),escala)
	var atualizar := func():
		arte.modulate = Color(0.78,0.78,0.78) if controle.disabled else (Color(0.88,0.88,0.88) if controle.is_pressed() else (Color(1.14,1.1,1.02) if controle.has_focus() or controle.is_hovered() else Color.WHITE))
	controle.draw.connect(atualizar)
	atualizar.call()
	# Contorno fino de foco desenhado dentro da moldura, sem deslocar o rótulo.
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.set_border_width_all(1)
	foco.border_color = Color("e5c680")
	foco.set_corner_radius_all(2)
	foco.expand_margin_left = -3
	foco.expand_margin_right = -3
	foco.expand_margin_top = -3
	foco.expand_margin_bottom = -3
	controle.add_theme_stylebox_override("focus",foco)

static func botoes_do_painel(no: Node) -> void:
	for filho in no.get_children():
		if filho is Button: botao(filho)
		else: botoes_do_painel(filho)

static func textos_do_painel(no: Node) -> void:
	for filho in no.get_children():
		if filho is Label:
			filho.add_theme_font_override("font",FONTE)
			if filho.label_settings != null:
				filho.label_settings = filho.label_settings.duplicate()
				filho.label_settings.font = FONTE
		textos_do_painel(filho)

## Moldura menor nas miniaturas e amostras, sem modificar o tamanho dos sprites.
static func casa(controle: Button) -> void:
	fundo(controle,Vector2i(1,0),16.0)
	for estado in ["normal","disabled","pressed","hover_pressed","hover","focus"]:
		controle.add_theme_stylebox_override(estado,borda_casa(estado in ["pressed","hover_pressed","hover","focus"]))

static func borda_casa(selecionada: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.draw_center = false
	estilo.set_border_width_all(2 if selecionada else 0)
	estilo.border_color = Color("eecb72")
	estilo.set_corner_radius_all(2)
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		estilo.set_content_margin(lado,3)
		estilo.set_expand_margin(lado,-2)
	return estilo

static func campo(controle: LineEdit) -> void:
	for estado in ["normal","read_only","focus"]:
		var estilo := espaco(10)
		estilo.content_margin_top = 4
		estilo.content_margin_bottom = 4
		controle.add_theme_stylebox_override(estado,estilo)
	fundo(controle,Vector2i(1,0),16.0)
	controle.add_theme_color_override("font_color",Color("49321e"))
	controle.add_theme_color_override("font_placeholder_color",Color("877457"))
	controle.add_theme_color_override("caret_color",Color("49321e"))

static func slider(controle: HSlider) -> void:
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color("211a13")
	trilho.border_color = Color("89613a")
	trilho.set_border_width_all(1)
	trilho.content_margin_top = 2
	trilho.content_margin_bottom = 2
	controle.add_theme_stylebox_override("slider",trilho)
	var preenchido := trilho.duplicate() as StyleBoxFlat
	preenchido.bg_color = Color("667344")
	controle.add_theme_stylebox_override("grabber_area",preenchido)
	controle.add_theme_stylebox_override("grabber_area_highlight",preenchido)
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0,0.12,0.25,0.75,0.88,1])
	gradiente.colors = PackedColorArray([Color("49301c"),Color("d5b36f"),Color("b8874c"),Color("8c5c30"),Color("5e3c23"),Color("382517")])
	var alca := GradientTexture2D.new()
	alca.gradient = gradiente
	alca.width = 10
	alca.height = 14
	alca.fill_to = Vector2.DOWN
	for estado in ["grabber","grabber_highlight","grabber_disabled"]:
		controle.add_theme_icon_override(estado,alca)
