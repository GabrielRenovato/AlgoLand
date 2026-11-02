extends RefCounted

## Madeira escura, metal envelhecido e âmbar: nove partes com bordas finas.
const ATLAS := preload("res://assets/ui/expedicoes/atlas.png")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const ESCALA := 8.0

static func fundo(controle: Control,celula: Vector2i) -> NinePatchRect:
	var textura:=AtlasTexture.new();textura.atlas=ATLAS
	var lado:=ATLAS.get_width()/2.0
	textura.region=Rect2(Vector2(celula)*lado,Vector2.ONE*lado)
	textura.filter_clip=true
	var arte:=NinePatchRect.new();arte.texture=textura
	arte.scale=Vector2.ONE/ESCALA;arte.mouse_filter=Control.MOUSE_FILTER_IGNORE
	arte.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	for borda in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:arte.set_patch_margin(borda,38)
	var camada:=Node2D.new();camada.show_behind_parent=true;controle.add_child(camada);camada.add_child(arte)
	var ajustar:=func():arte.size=controle.size*ESCALA
	controle.resized.connect(ajustar);ajustar.call()
	return arte

static func painel(controle: Control,_claro:=false,margem:=10.0,_opaco:=true) -> void:
	var estilo:=StyleBoxEmpty.new()
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:estilo.set_content_margin(lado,margem)
	controle.add_theme_stylebox_override("panel",estilo)
	fundo(controle,Vector2i(1,0) if _claro else Vector2i.ZERO)

static func botao(controle: Button,principal:=false) -> void:
	controle.add_theme_font_override("font",FONTE);controle.add_theme_font_size_override("font_size",9)
	controle.clip_text=true
	for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var estilo:=StyleBoxEmpty.new()
		estilo.set_content_margin_all(7);estilo.content_margin_top=3;estilo.content_margin_bottom=3
		controle.add_theme_stylebox_override(estado,estilo)
		controle.add_theme_color_override("font_"+estado+"_color",Color("f2ddb7"))
	controle.add_theme_color_override("font_color",Color("f2ddb7"))
	controle.add_theme_color_override("font_disabled_color",Color("918779"))
	var arte:=fundo(controle,Vector2i(0,1) if principal else Vector2i(1,1))
	var atualizar:=func():arte.modulate=Color(.55,.55,.55) if controle.disabled else (Color(1.2,1.12,.95) if controle.is_hovered() or controle.has_focus() else Color.WHITE)
	controle.draw.connect(atualizar)

static func campo(controle: LineEdit) -> void:
	var estilo:=StyleBoxEmpty.new();estilo.set_content_margin_all(6)
	estilo.content_margin_top=3;estilo.content_margin_bottom=3
	controle.add_theme_stylebox_override("normal",estilo)
	var foco:=StyleBoxFlat.new();foco.bg_color=Color.TRANSPARENT
	foco.border_color=Color("b48442");foco.set_border_width_all(1)
	controle.add_theme_stylebox_override("focus",foco)
	controle.add_theme_font_override("font",FONTE)
	controle.add_theme_font_size_override("font_size",9)
	controle.add_theme_color_override("font_color",Color("eddec8"))
	controle.add_theme_color_override("font_placeholder_color",Color("a99d88"))
	fundo(controle,Vector2i(1,1))
