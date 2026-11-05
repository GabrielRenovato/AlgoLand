extends RefCounted
## Acabamento local da Primeira Raiz: madeira escura, latão e encaixes verdes.
const FONTE := preload("res://assets/ui/fontes/NotoSans-Regular.ttf")
const FONTE_TITULO := preload("res://assets/ui/fontes/NotoSerif-SemiBold.ttf")
const BRASAO := preload("res://assets/ui/resultado_expedicao/brasao_raiz.svg")
const TINTA := Color("f4e6c4")
const SUAVE := Color("c1b18b")
const VERDE := Color("d1ad62")
const PAPEL := Color("30271c")
const BRONZE := Color("a58650")
const LEGENDAS := {"MUSICA":"MÚSICA","FPS MAXIMO":"FPS MÁXIMO","VIBRACAO":"VIBRAÇÃO","VENDA DO TOMAS":"VENDA DO TOMÁS","LANCA":"LANÇA","MACA":"MAÇA"}

class Acabamento extends Node2D:
	var alvo: Control
	var preencher := true
	var cor := Color("30271c")
	func _draw() -> void:
		if not is_instance_valid(alvo):return
		var r := Rect2(Vector2.ZERO,alvo.size)
		if preencher:
			var s := StyleBoxFlat.new();s.bg_color=cor;s.border_color=Color("a58650")
			s.set_border_width_all(1);s.set_corner_radius_all(4);draw_style_box(s,r)
		if minf(alvo.size.x,alvo.size.y)<36:return
		draw_line(Vector2(10,3),Vector2(alvo.size.x-10,3),Color("715333"),1)
		draw_line(Vector2(10,alvo.size.y-4),Vector2(alvo.size.x-10,alvo.size.y-4),Color("715333"),1)
		for x in [5.0,alvo.size.x-6]:
			for y in [5.0,alvo.size.y-6]:
				draw_circle(Vector2(x,y),1.5,Color("ceaa65"))

static func superficie(cor := PAPEL,borda := BRONZE,margem := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new();s.bg_color=cor;s.border_color=borda
	s.set_border_width_all(1);s.border_width_top=2;s.border_width_bottom=3
	s.set_corner_radius_all(4);s.set_content_margin_all(margem)
	s.shadow_color=Color(0,0,0,.35);s.shadow_size=2;s.shadow_offset=Vector2(0,1)
	return s

static func _acabamento(no: Control,cor := PAPEL) -> void:
	if no.has_node("AcabamentoRaiz"):
		no.get_node("AcabamentoRaiz").cor=cor;no.get_node("AcabamentoRaiz").queue_redraw();return
	var a := Acabamento.new();a.name="AcabamentoRaiz";a.alvo=no
	a.cor=cor
	no.add_child(a);no.move_child(a,0);no.resized.connect(a.queue_redraw)

static func painel(no: Control,claro := false,margem := 10.0,_opaco := true) -> void:
	no.set_meta("acabamento_campanha",true)
	no.add_theme_stylebox_override("panel",superficie(Color("273d32") if claro else PAPEL,BRONZE,margem))
	_acabamento(no,Color("273d32") if claro else PAPEL)

static func botao(no: Button,principal := false) -> void:
	no.set_meta("acabamento_campanha",true)
	no.text=no.text.replace("OPCOES","OPÇÕES").replace("ARVORE","ÁRVORE")
	if no.text.strip_edges().to_upper() in ["X","FECHAR","×"]:
		no.set_meta("fechar_no_fluxo",true)
		no.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	for filho in no.get_children():
		if filho.name=="PinturaInicio" or filho.name=="PinturaCampanha":
			if filho is CanvasItem:filho.hide()
		if filho.get_script()!=null and filho.get_script().resource_path=="res://codigo/ui/fechar_janela.gd":
			filho.set_process(false);no.set_as_top_level(false);no.z_index=0
			no.custom_minimum_size=Vector2(24,24)
			if no.get_parent() is Container:no.get_parent().queue_sort()
	no.add_theme_font_override("font",FONTE_TITULO);no.add_theme_font_size_override("font_size",10)
	for estado in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var cor := Color("35513b") if principal else Color("4a3828")
		if estado=="hover":cor=cor.lightened(.15)
		if estado=="pressed" or estado=="hover_pressed":cor=cor.darkened(.22)
		if estado=="disabled":cor=Color("302b23")
		var s := superficie(cor,Color("d1ad62") if principal else BRONZE,8)
		s.content_margin_top=4;s.content_margin_bottom=4
		if estado=="focus":s.draw_center=false;s.border_color=TINTA;s.set_border_width_all(2)
		no.add_theme_stylebox_override(estado,s)
	for chave in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:no.add_theme_color_override(chave,TINTA)
	no.add_theme_color_override("font_disabled_color",Color("8c8065"))

static func campo(no: LineEdit) -> void:
	no.set_meta("acabamento_campanha",true)
	no.add_theme_font_override("font",FONTE);no.add_theme_font_size_override("font_size",10)
	for estado in ["normal","read_only","focus"]:no.add_theme_stylebox_override(estado,superficie(Color("19271f"),BRONZE,6))
	no.add_theme_color_override("font_color",TINTA);no.add_theme_color_override("font_placeholder_color",SUAVE);no.add_theme_color_override("caret_color",TINTA)

static func fontes(no: Node) -> void:
	if no is Label:
		if no.name=="Bloqueio" and no.text=="BLOQUEADO":no.text="Trancado"
		if no.name in ["Nome","Bloqueio"] and no.get_theme_font_size("font_size")<8:
			no.add_theme_font_size_override("font_size",8);no.add_theme_constant_override("line_spacing",0)
		if no.text in ["MAESTRIA","OPCOES","MISSOES","BIGORNA DO IVO","VENDA DO TOMÁS"]:
			no.add_theme_font_override("font",FONTE_TITULO);no.add_theme_color_override("font_color",VERDE)
		no.text=str(LEGENDAS.get(no.text,no.text))
		no.text=no.text.replace("GUARDIAO","GUARDIÃO").replace("OPCOES","OPÇÕES").replace("MISSOES","MISSÕES")
		if no.label_settings!=null:
			var ajustes: LabelSettings=no.label_settings.duplicate()
			ajustes.font=FONTE_TITULO;ajustes.font_color=TINTA;ajustes.outline_size=0;no.label_settings=ajustes
		elif no.get_theme_font("font")!=FONTE_TITULO:no.add_theme_font_override("font",FONTE)
		if no.get_theme_color("font_color").get_luminance()<.5:no.add_theme_color_override("font_color",TINTA)
	elif no is Button or no is LineEdit or no is TextEdit:
		if no.get_theme_font("font")!=FONTE_TITULO:no.add_theme_font_override("font",FONTE)
	if no is RichTextLabel:
		for chave in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]:no.add_theme_font_override(chave,FONTE)
		no.add_theme_color_override("default_color",TINTA)
	for filho in no.get_children():fontes(filho)

static func pergaminho(no: Control,margem := 10.0) -> void:
	# Mantém as pinturas antigas vivas: seus sinais de resize capturam esses nós.
	for filho in no.get_children():
		if filho.name=="PinturaInicio" or filho.name=="PinturaCampanha":
			if filho is CanvasItem:filho.hide()
	painel(no,false,margem)

static func vestir(no: Node) -> void:
	# Molduras de estado (seleção na barra): o painel opaco da campanha cobriria o ícone.
	if no.has_meta("sem_acabamento"):return
	if "tipo_slot" in no:
		no.set_meta("estilo_campanha",true)
		if no.has_method("item_ui"):no.item_ui().set_meta("acabamento_campanha",true)
		var fundo: Control=no.get_node_or_null("Fundo")
		if fundo!=null:
			pergaminho(fundo,0);painel(fundo,true,0)
		if no.has_method("_atualizar_acabamento"):no.call("_atualizar_acabamento")
		return
	var ancestral: Node=no
	while ancestral!=null:
		if ancestral.has_meta("habilidade") or (ancestral!=no and "tipo_slot" in ancestral):return
		ancestral=ancestral.get_parent()
	if no.name=="PinturaInicio" or no.name=="PinturaCampanha":
		if no is CanvasItem:no.hide()
		return
	if no.get_script()!=null:
		if no.get_script().resource_path=="res://codigo/ui/icone_aba_inventario.gd":no.modulate=TINTA
		if no.get_script().resource_path=="res://codigo/ui/item_ui.gd":no.set_meta("acabamento_campanha",true)
	if no is Button:botao(no)
	elif no is LineEdit:campo(no)
	elif no is PanelContainer or no is Panel:
		var antigo: StyleBox=no.get_theme_stylebox("panel")
		var margem := clampf(antigo.get_content_margin(SIDE_LEFT),6,12) if antigo!=null else 8.0
		painel(no,false,margem)
	if no is Label or no is RichTextLabel:fontes(no)
	for filho in no.get_children():vestir(filho)

static func brasao(tamanho := Vector2(24,28)) -> TextureRect:
	var imagem := TextureRect.new();imagem.texture=BRASAO;imagem.custom_minimum_size=tamanho
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return imagem

static func dicas(no: Control) -> void:
	var tema: Theme=no.theme.duplicate() if no.theme!=null else Theme.new()
	tema.set_font("font","TooltipLabel",FONTE)
	tema.set_font_size("font_size","TooltipLabel",10)
	tema.set_color("font_color","TooltipLabel",TINTA)
	tema.set_stylebox("panel","TooltipPanel",superficie(Color("202c25"),BRONZE,8))
	no.theme=tema
