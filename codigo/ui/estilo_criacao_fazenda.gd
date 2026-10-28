extends RefCounted
## Molduras nativas com paleta de madeira/pergaminho, sem depender de filtro.
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const TINTA := Color("543a29")
const MADEIRA := Color("76502f")
const PAPEL := Color("f5dfae")
class Moldura extends Node2D:
	var painel: Control
	func _ready(): painel.resized.connect(queue_redraw)
	func _draw():
		var s := painel.size
		if s.x<12 or s.y<12:return
		draw_rect(Rect2(Vector2(4,4),s-Vector2(8,8)),Color("d2a264"),false,1)
		draw_line(Vector2(5,5),Vector2(s.x-6,5),Color("ffe5ab"),1)
		draw_line(Vector2(5,s.y-5),Vector2(s.x-6,s.y-5),Color("ac7946"),1)
class Seta extends Button:
	var direcao := 1
	func _draw():
		var c := (size/2).round()
		var cor := Color("f7e7bd") if disabled else Color("61432a")
		draw_colored_polygon(PackedVector2Array([c+Vector2(-2*direcao,-3),c+Vector2(2*direcao,0),c+Vector2(-2*direcao,3)]),cor)
class Dado extends Button:
	func _draw():
		var c := (size/2).round()
		for p in [Vector2(-3,-3),Vector2(3,-3),Vector2.ZERO,Vector2(-3,3),Vector2(3,3)]:
			draw_rect(Rect2(c+p-Vector2.ONE,Vector2(2,2)),Color("61432a"))
class Palco extends Control:
	func _ready():
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("c4d4b4"))
		var horizonte := floorf(size.y*.56)
		draw_colored_polygon(PackedVector2Array([Vector2(0,horizonte),Vector2(size.x*.32,horizonte-14),Vector2(size.x*.72,horizonte+3),Vector2(size.x,horizonte-8),Vector2(size.x,size.y),Vector2(0,size.y)]),Color("a5ba88"))
		draw_rect(Rect2(Vector2(0,size.y-18),Vector2(size.x,18)),Color("879d68"))
		draw_line(Vector2(0,size.y-18),Vector2(size.x,size.y-18),Color("bdca91"))
		for x in range(8,int(size.x)-4,17):
			draw_line(Vector2(x,size.y-8),Vector2(x+3,size.y-8),Color("748a59"))

static func caixa(cor: Color, borda:=MADEIRA, margem:=8.0, espessura:=2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=cor
	s.border_color=borda
	s.set_border_width_all(espessura)
	s.set_corner_radius_all(1)
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:s.set_content_margin(lado,margem)
	return s
static func painel(p: PanelContainer, margem:=10.0):
	var s := caixa(PAPEL,MADEIRA,margem,4)
	s.shadow_color=Color(0.08,.06,.03,.30)
	s.shadow_size=3
	s.shadow_offset=Vector2(0,2)
	p.add_theme_stylebox_override("panel",s)
	var m := Moldura.new()
	m.painel=p
	p.add_child(m)
static func botao(b: Button, principal:=false):
	b.add_theme_font_override("font",FONTE)
	b.add_theme_font_size_override("font_size",10)
	for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
		var cor := Color("8a9e68") if principal else Color("edd19a")
		if estado=="hover":cor=Color("a6b87d") if principal else Color("ffe8b5")
		if estado in ["pressed","hover_pressed"]:cor=Color("71894f") if principal else Color("d8bc80")
		if estado=="disabled":cor=Color("d6c9ac")
		var s := caixa(cor,Color("62462d"),6,2)
		s.content_margin_top=3
		s.content_margin_bottom=3
		b.add_theme_stylebox_override(estado,s)
		b.add_theme_color_override("font_"+estado+"_color",Color("fff5d6") if principal else TINTA)
	b.add_theme_color_override("font_color",Color("fff5d6") if principal else TINTA)
	b.add_theme_color_override("font_focus_color",TINTA)
	var foco := caixa(Color.TRANSPARENT,Color("b16832"),0,1)
	foco.draw_center=false
	b.add_theme_stylebox_override("focus",foco)
static func amostra(b: Button, selecionada: bool):
	var s := caixa(Color("ead5a9"),Color("60432b") if selecionada else Color("b4925f"),3,3 if selecionada else 1)
	b.add_theme_stylebox_override("normal",s)
	b.add_theme_stylebox_override("pressed",s)
static func rotulo(texto: String, tamanho:=10) -> Label:
	var r := Label.new()
	r.text=texto
	r.add_theme_font_override("font",FONTE)
	r.add_theme_font_size_override("font_size",tamanho)
	r.add_theme_color_override("font_color",TINTA)
	return r
