extends Control

## Relatório da tentativa: recompensas inspecionáveis e placar, sem conceder itens ou XP.
signal explorar
signal rejogar
signal mapa
signal layout_alterado
const Itens := preload("res://codigo/modelos/dados_item.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
const Catalogo := preload("res://codigo/campanha/catalogo_campanha.gd")
const Armas := preload("res://codigo/dados/catalogo_maestria.gd")
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Avatar := preload("res://codigo/jogador/representacao_heroi_3d.gd")
const BASE_FONTE := preload("res://assets/ui/fontes/NotoSans-Regular.ttf")
const BASE_TITULO := preload("res://assets/ui/fontes/NotoSerif-SemiBold.ttf")
const BRASAO := preload("res://assets/ui/resultado_expedicao/brasao_raiz.svg")
const CREME := Color("f4e6c4")
const SUAVE := Color("c1b18b")
const OURO := Color("d1ad62")
const TINTA := Color("352b20")
const VERDE := Color("273d32")
var fonte: FontFile
var fonte_titulo: FontFile
var tela: Control
var painel: PanelContainer
var dados_run: Dictionary = {}
var titulo_estado := "Expedição concluída"
var etapa := "chegada"
var compacto := false
var baixo := false
var rolagem: ScrollContainer
var abas: TabBar
var slots: Array[Button] = []
var detalhe_item: Label
var detalhe_atributos: Label
var _selecionado := -1
var _aba := 1
var _entrada: Tween
var _revelaveis: Array[Control] = []
## Comemoração da entrada: o brasão pula e faíscas douradas sobem atrás do título.
var _brasao: TextureRect
## Só na conclusão de uma etapa (o botão Relatório abre a mesma tela no meio da exploração).
var comemorar := false

# Acabamento nativo: madeira, filetes de latão, encaixes e rebites. Sem textura ampliada.
class Quadro extends PanelContainer:
	func _ready() -> void:resized.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2(3,3),size-Vector2(6,6))
		draw_style_box(_filete(Color("261f18"),Color("987645"),4),r)
		for y in [7.0,size.y-8]:
			draw_line(Vector2(15,y),Vector2(size.x-15,y),Color("6b4b2d"),1)
		for x in [8.0,size.x-9]:
			for y in [8.0,size.y-9]:
				draw_rect(Rect2(Vector2(x-3,y-3),Vector2(6,6)),Color("271e14"))
				draw_circle(Vector2(x,y),2,Color("d2aa65"))
				draw_line(Vector2(x-1,y-1),Vector2(x+1,y-1),Color("f4d69c"),1)
	func _filete(cor: Color,borda: Color,raio: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new();s.bg_color=cor;s.border_color=borda
		s.set_border_width_all(1);s.set_corner_radius_all(raio)
		return s

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fonte=BASE_FONTE.duplicate() as FontFile;fonte_titulo=BASE_TITULO.duplicate() as FontFile
	for f in [fonte,fonte_titulo]:
		f.allow_system_fallback=false;f.multichannel_signed_distance_field=OS.has_feature("web");f.oversampling=2.0
	theme=Theme.new();theme.default_font=fonte;theme.default_font_size=11
	theme.set_color("font_color","TooltipLabel",CREME)
	theme.set_stylebox("panel","TooltipPanel",superficie(Color("202c25"),OURO,8))
	resized.connect(_remontar)
	visibility_changed.connect(_animar_entrada)
	_remontar();hide()

func apresentar(dados: Dictionary,regiao: String,titulo_texto := "Expedição concluída") -> void:
	dados_run=dados.duplicate(true);etapa=regiao;titulo_estado=titulo_texto;_selecionado=-1;_aba=1
	_remontar()

func _remontar() -> void:
	if fonte==null:return
	if _entrada!=null:_entrada.kill()
	if is_instance_valid(tela):remove_child(tela);tela.queue_free()
	slots.clear();_revelaveis.clear();abas=null
	montar(Vector2i(size))

func numero(valor: int) -> String:
	var origem := str(valor);var resultado := ""
	for i in origem.length():
		if i>0 and (origem.length()-i)%3==0:resultado+="."
		resultado+=origem[i]
	return resultado

func superficie(cor: Color,borda: Color,margem := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new();s.bg_color=cor;s.border_color=borda
	s.set_border_width_all(1);s.set_corner_radius_all(4);s.set_content_margin_all(margem)
	# Luz no topo e sombra na base dão volume aos encaixes.
	s.border_width_bottom=2;s.shadow_color=Color(0,0,0,.3);s.shadow_size=2;s.shadow_offset=Vector2(0,1)
	return s

func texto(valor: String,tamanho := 11,cor := CREME,serif := false) -> Label:
	var l := Label.new();l.text=valor
	l.add_theme_font_override("font",fonte_titulo if serif else fonte)
	l.add_theme_font_size_override("font_size",tamanho);l.add_theme_color_override("font_color",cor)
	return l

func coluna(espaco := 6) -> VBoxContainer:
	var c := VBoxContainer.new();c.add_theme_constant_override("separation",espaco);return c

func linha(espaco := 8) -> HBoxContainer:
	var c := HBoxContainer.new();c.add_theme_constant_override("separation",espaco);return c

func caixa(cor: Color,borda: Color,margem := 8.0) -> PanelContainer:
	var c := PanelContainer.new();c.add_theme_stylebox_override("panel",superficie(cor,borda,margem));return c

func divisoria() -> HSeparator:
	var l := HSeparator.new();var s := StyleBoxLine.new();s.color=Color("80663f");s.thickness=1
	l.add_theme_stylebox_override("separator",s);return l

func botao(rotulo: String,principal := false) -> Button:
	var b := Button.new();b.text=rotulo;b.custom_minimum_size.y=28 if baixo else 32
	b.add_theme_font_override("font",fonte_titulo);b.add_theme_font_size_override("font_size",11)
	for estado in ["normal","hover","pressed","focus"]:
		var cor := Color("35513b") if principal else Color("4a3828")
		if estado=="hover":cor=cor.lightened(.15)
		if estado=="pressed":cor=cor.darkened(.22)
		var s := superficie(cor,OURO if principal else Color("997546"),8)
		s.border_width_top=2
		if estado=="focus":s.draw_center=false;s.border_color=CREME;s.set_border_width_all(2)
		b.add_theme_stylebox_override(estado,s)
	for estado in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(estado,CREME)
	return b

func montar(medida: Vector2i) -> void:
	compacto=medida.x<560;baixo=medida.y<430
	tela=Control.new();add_child(tela);tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new();sombra.color=Color(.025,.035,.03,.86)
	tela.add_child(sombra);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margem := MarginContainer.new();tela.add_child(margem);margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","right","top","bottom"]:margem.add_theme_constant_override("margin_"+lado,10 if baixo else 18)
	var centro := CenterContainer.new();margem.add_child(centro)
	painel=Quadro.new();painel.name="QuadroResultado";centro.add_child(painel)
	painel.custom_minimum_size=Vector2(mini(medida.x-(20 if baixo else 36),820),mini(medida.y-(20 if baixo else 36),500))
	painel.add_theme_stylebox_override("panel",superficie(Color("30271c"),Color("bc9253"),10 if baixo or compacto else 20))
	var conteudo := coluna(5 if baixo or compacto else 10);painel.add_child(conteudo)
	var cabeca := linha(10);conteudo.add_child(cabeca);_revelaveis.append(cabeca)
	var brasao := TextureRect.new();brasao.texture=BRASAO;brasao.custom_minimum_size=Vector2(32,38) if baixo or compacto else Vector2(48,54)
	brasao.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;brasao.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cabeca.add_child(brasao)
	_brasao = brasao
	var titulos := coluna(1);titulos.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cabeca.add_child(titulos)
	var vitoria := texto(titulo_estado,17 if baixo or compacto else 24,Color("edd298"),true)
	vitoria.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;titulos.add_child(vitoria)
	var lugar := texto(str(Catalogo.dados().destinos.get(etapa,{}).get("nome",etapa))+" · Primeira Raiz",9 if baixo or compacto else 11,SUAVE)
	lugar.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;titulos.add_child(lugar)
	conteudo.add_child(divisoria())
	# Uma faixa, em vez de quatro cartões competindo com o saque.
	var segundos := int(dados_run.get("tempo",0))
	var faixa := texto("%02d:%02d   ·   %d/%d abates   ·   %d mortes" % [segundos/60,segundos%60,dados_run.get("abates",0),dados_run.get("inimigos",0),dados_run.get("pessoal",{}).get("mortes",0)],10,SUAVE)
	faixa.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;conteudo.add_child(faixa)
	if compacto:
		abas=TabBar.new();abas.add_tab("Saque");abas.add_tab("Combate");abas.current_tab=0 if _aba==1 else 1
		abas.add_theme_font_override("font",fonte_titulo);abas.add_theme_font_size_override("font_size",11)
		for estado in ["tab_selected","tab_unselected","tab_hovered","tab_focus"]:
			abas.add_theme_stylebox_override(estado,superficie(VERDE if estado=="tab_selected" else Color("372b20"),Color("8e7044"),6))
		abas.add_theme_color_override("font_selected_color",CREME);abas.add_theme_color_override("font_unselected_color",SUAVE)
		abas.add_theme_color_override("font_hovered_color",CREME);conteudo.add_child(abas)
	rolagem=ScrollContainer.new();rolagem.size_flags_vertical=Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;conteudo.add_child(rolagem)
	var corpo := HBoxContainer.new();corpo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation",14);rolagem.add_child(corpo)
	var saque := _montar_saque();saque.size_flags_horizontal=Control.SIZE_EXPAND_FILL;corpo.add_child(saque);_revelaveis.append(saque)
	var placar := _montar_placar();placar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;corpo.add_child(placar);_revelaveis.append(placar)
	if compacto:
		var selecionar := func(indice: int):
			_aba=1 if indice==0 else 2;saque.visible=indice==0;placar.visible=indice==1;rolagem.scroll_vertical=0
		abas.tab_changed.connect(selecionar);selecionar.call(abas.current_tab)
	conteudo.add_child(divisoria())
	var rodape := coluna(4);conteudo.add_child(rodape)
	var pendentes: int=dados_run.get("drops",[]).filter(func(d):return not d.recolhido).size()
	var aviso := texto("%d item(ns) no chão. Recolha antes de rejogar." % pendentes if pendentes else "Recompensas recolhidas guardadas na mochila.",9,SUAVE)
	if dados_run.get("drops",[]).is_empty():aviso.text="Nenhuma recompensa nesta tentativa."
	aviso.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rodape.add_child(aviso)
	if titulo_estado=="Clareira pacificada":
		var proximo := texto("Siga a seta até o próximo objetivo.",9,Color("b2c6a0"));proximo.tooltip_text=str(dados_run.get("objetivo",""));rodape.add_child(proximo)
	var acoes := GridContainer.new();acoes.columns=3
	acoes.add_theme_constant_override("h_separation",8);acoes.add_theme_constant_override("v_separation",5);rodape.add_child(acoes)
	for par in [["Explorar",explorar],["Rejogar",rejogar],["Mapa",mapa]]:
		var b := botao(par[0],par[0]=="Explorar");b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;acoes.add_child(b)
		b.pressed.connect(func():par[1].emit())
	layout_alterado.emit()

func _montar_saque() -> VBoxContainer:
	var c := coluna(4 if baixo else 7)
	var titulo := texto("ESPÓLIOS DA EXPEDIÇÃO",12,OURO,true);c.add_child(titulo)
	var drops: Array=dados_run.get("drops",[])
	var recolhidos: int=drops.filter(func(d):return d.recolhido).size()
	c.add_child(texto("%d recolhidos  /  %d encontrados" % [recolhidos,drops.size()],9,SUAVE))
	var grade := GridContainer.new();grade.name="SlotsRecompensas";grade.columns=4 if compacto else 5
	grade.add_theme_constant_override("h_separation",7);grade.add_theme_constant_override("v_separation",7);c.add_child(grade)
	for i in drops.size():
		var item=Itens.de_dict(drops[i].item)
		if item==null:continue
		var b := botao("");b.name="Saque%d" % i;b.custom_minimum_size=Vector2(48,48) if baixo or compacto else Vector2(62,62)
		b.toggle_mode=true;b.set_meta("drop",i)
		var cor: Color=item.cor_raridade();if item.raridade=="comum":cor=Color("9e977c")
		for estado in ["normal","hover","pressed"]:
			var s := superficie(Color("252c27") if estado=="normal" else Color("3c4836"),cor,6)
			s.border_width_bottom=3;s.border_width_top=2
			if estado=="pressed":s.bg_color=Color("43553d");s.border_color=CREME
			b.add_theme_stylebox_override(estado,s)
		grade.add_child(b);slots.append(b)
		var icone := TextureRect.new();icone.texture=Icones.obter(item,get_tree());b.add_child(icone)
		icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icone.offset_left=9;icone.offset_top=7;icone.offset_right=-9;icone.offset_bottom=-10
		icone.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icone.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icone.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var marca := texto("×1" if drops[i].recolhido else "!",8,CREME if drops[i].recolhido else OURO)
		b.add_child(marca);marca.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		marca.offset_right=-4;marca.offset_bottom=-3
		marca.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;marca.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
		marca.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.tooltip_text=item.nome().capitalize()+"\n"+item.nome_raridade().capitalize()+" · "+("Recolhido" if drops[i].recolhido else "No chão")
		b.pressed.connect(_inspecionar_item.bind(i))
	if drops.is_empty():c.add_child(texto("Nenhum item caiu nesta tentativa.",10,SUAVE))
	var detalhe := caixa(Color("e0d0a9"),Color("967645"),6);detalhe.name="InspecaoRecompensa";c.add_child(detalhe)
	detalhe.visible=not drops.is_empty()
	var desc := coluna(3);detalhe.add_child(desc)
	detalhe_item=texto("Selecione uma recompensa",12,TINTA,true);detalhe_item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.add_child(detalhe_item)
	detalhe_atributos=texto("Os detalhes do item aparecem aqui.",10,Color("64523a"));detalhe_atributos.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.add_child(detalhe_atributos)
	for ganho in dados_run.get("maestria",[]):
		var familia: String=str(Armas.NOMES.get(ganho.familia,ganho.familia)).capitalize()
		var treino := texto("+%d XP  ·  %s  ·  Maestria %d" % [ganho.xp,familia,ganho.nivel],10,Color("b2c6a0"));treino.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;c.add_child(treino)
	if not drops.is_empty():
		var escolhido := clampi(_selecionado,0,drops.size()-1)
		if _selecionado<0:
			for i in drops.size():
				if drops[i].item.get("raridade")=="raro":escolhido=i;break
		_selecionar_item(escolhido)
	return c

func _inspecionar_item(indice: int) -> void:
	_selecionar_item(indice)
	# No espaço estreito, leva os atributos selecionados para a área visível.
	if compacto and baixo:rolagem.ensure_control_visible(detalhe_item.get_parent().get_parent())

func _selecionar_item(indice: int) -> void:
	_selecionado=indice
	var d: Dictionary=dados_run.drops[indice];var item=Itens.de_dict(d.item)
	if item==null:return
	for b in slots:b.set_pressed_no_signal(int(b.get_meta("drop"))==indice)
	detalhe_item.text=item.nome().capitalize()
	detalhe_atributos.text=item.nome_raridade().capitalize()+" · Nível %d · " % item.nivel+("Recolhido" if d.recolhido else "No chão")
	var conjunto=preload("res://codigo/dados/conjuntos_armadura.gd").de_tipo(item.tipo)
	if conjunto!=null:
		var valores: Dictionary=conjunto.dados(item.tipo,item.nivel)
		var raridades=preload("res://codigo/dados/raridades.gd")
		detalhe_atributos.text+="\nDefesa +%d · Vitalidade +%d" % [raridades.escalar(int(valores.get("bonus_defesa",0)),item.raridade),raridades.escalar(int(valores.get("bonus_vitalidade",0)),item.raridade)]
	elif preload("res://codigo/dados/acessorios_iniciais.gd").TIPOS.has(item.tipo):
		detalhe_atributos.text+="\n"+str(preload("res://codigo/dados/acessorios_iniciais.gd").TIPOS[item.tipo].texto).capitalize()
	for afixo in item.afixos:
		detalhe_atributos.text+="\n"+preload("res://codigo/dados/raridades.gd").texto_afixo(afixo,item.afixos[afixo]).capitalize()

func _montar_placar() -> VBoxContainer:
	var c := coluna(7);c.add_child(texto("REGISTRO DE COMBATE",12,OURO,true))
	c.add_child(texto("Dano efetivo causado pelo grupo",9,SUAVE))
	var grupo: Array=dados_run.get("grupo",[]);var total := 0
	for p in grupo:total+=int(p.dano)
	if grupo.is_empty():c.add_child(texto("Nenhum combate registrado.",10,SUAVE))
	for i in grupo.size():
		var p: Dictionary=grupo[i]
		var quadro := caixa(VERDE if i==0 else Color("252e28"),Color("ac8b50") if i==0 else Color("59563f"),7);c.add_child(quadro)
		var l := linha(6);quadro.add_child(l)
		var posicao := texto(["I","II","III","IV"][mini(i,3)],15,OURO,true);posicao.custom_minimum_size.x=18
		posicao.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;posicao.size_flags_vertical=Control.SIZE_SHRINK_CENTER;l.add_child(posicao)
		l.add_child(_retrato(str(p.id)))
		var info := coluna(3);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.add_child(info)
		var topo := linha(6);info.add_child(topo)
		var apelido: String=str(p.nome)
		if apelido.is_empty() or apelido=="sem apelido":apelido="Aventureiro"
		var nome := texto(apelido+(" · você" if p.id==dados_run.get("eu","") else ""),10)
		nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nome.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;nome.clip_text=true;topo.add_child(nome)
		nome.tooltip_text=nome.text;topo.add_child(texto(numero(int(p.dano)),12,OURO,true))
		var progresso := linha(5);info.add_child(progresso)
		var percentual := roundi(float(p.dano)*100/maxi(total,1))
		var barra := ProgressBar.new();barra.value=percentual;barra.show_percentage=false;barra.custom_minimum_size=Vector2(20,5)
		barra.size_flags_horizontal=Control.SIZE_EXPAND_FILL;barra.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		barra.add_theme_stylebox_override("background",superficie(Color("15221c"),Color("15221c"),0));barra.add_theme_stylebox_override("fill",superficie(OURO,OURO,0))
		progresso.add_child(barra);progresso.add_child(texto("%d%%" % percentual,9,SUAVE))
	var meu: Dictionary=dados_run.get("pessoal",{})
	var detalhe := texto("Recebido %d   ·   Bloqueios %d   ·   Abates %d" % [meu.get("recebido",0),meu.get("bloqueios",0),meu.get("abates",0)],9,SUAVE)
	detalhe.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;c.add_child(detalhe)
	c.add_child(texto("Chefe: "+("Cerne Partido derrotado" if dados_run.get("chefe",false) else "—"),10,Color("b2c6a0")))
	return c

func _retrato(id: String) -> Control:
	var palco := Control.new();palco.name="RetratoCombatente";palco.custom_minimum_size=Vector2(28,35);palco.clip_contents=true
	var aparencia := {"versao":1}
	var cena := get_parent().get_parent() if get_parent()!=null else null
	if cena!=null and cena.get("jogador") is Node2D:
		if id==dados_run.get("eu",""):aparencia=Visual.do_jogador(cena.jogador)
		elif cena.get("sessao")!=null:aparencia=Visual.normalizar(cena.sessao.perfil_de(id).get("visual",{"versao":1}))
	var avatar := Avatar.new();avatar.aparencia=aparencia;palco.add_child(avatar)
	var ajustar := func():
		var limites := Rect2()
		for sprite in avatar.find_children("*","Sprite2D",true,false):
			if sprite.texture==null or not sprite.is_visible_in_tree():continue
			var imagem: Image=sprite.texture.get_image();if imagem==null:continue
			var quadro := Vector2i(imagem.get_size()/Vector2i(sprite.hframes,sprite.vframes))
			var origem := Vector2i(sprite.frame%sprite.hframes,sprite.frame/sprite.hframes)*quadro
			if sprite.region_enabled:origem=Vector2i(sprite.region_rect.position);quadro=Vector2i(sprite.region_rect.size)
			var pixels: Rect2=imagem.get_region(Rect2i(origem,quadro)).get_used_rect()
			if not pixels.has_area():continue
			var area: Rect2=(avatar.global_transform.affine_inverse()*sprite.global_transform)*Rect2(sprite.get_rect().position+pixels.position,pixels.size)
			limites=area if not limites.has_area() else limites.merge(area)
		if not limites.has_area():limites=Rect2(-12,-32,24,36)
		var escala := minf((palco.size.y-2)/limites.size.y,(palco.size.x-2)/limites.size.x)
		avatar.scale=Vector2.ONE*escala;avatar.position=palco.size/2-limites.get_center()*escala
	avatar.renderizado.connect(ajustar,CONNECT_ONE_SHOT);palco.resized.connect(ajustar)
	return palco

func _animar_entrada() -> void:
	if not is_visible_in_tree():
		if _entrada!=null:_entrada.kill()
		return
	_entrada=create_tween()
	_comemorar.call_deferred()
	for no in _revelaveis:
		no.modulate.a=0
		_entrada.tween_property(no,"modulate:a",1.0,.16).set_trans(Tween.TRANS_SINE)

func _comemorar() -> void:
	if not comemorar or not is_instance_valid(_brasao): return
	comemorar = false
	# Espera o painel se posicionar: antes disso o brasão ainda está fora da tela.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_brasao): return
	Sons.tocar("onda_fim")
	_brasao.pivot_offset = _brasao.size*0.5
	_brasao.scale = Vector2.ONE*0.4
	var pulo := create_tween()
	pulo.tween_property(_brasao,"scale",Vector2.ONE*1.15,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulo.tween_property(_brasao,"scale",Vector2.ONE,0.12)
	var faiscas := CPUParticles2D.new()
	faiscas.amount = 40
	faiscas.lifetime = 1.1
	faiscas.one_shot = true
	faiscas.explosiveness = 0.85
	# Em todas as direções: o brasão fica colado no topo da tela e faíscas para cima saíam de vista.
	faiscas.direction = Vector2.RIGHT
	faiscas.spread = 180.0
	faiscas.initial_velocity_min = 70.0
	faiscas.initial_velocity_max = 150.0
	faiscas.gravity = Vector2(0, 40)
	faiscas.scale_amount_min = 1.5
	faiscas.scale_amount_max = 2.5
	faiscas.color = Color("f2cf72")
	faiscas.position = _brasao.size*0.5
	faiscas.local_coords = true
	faiscas.show_behind_parent = true
	_brasao.add_child(faiscas)
	faiscas.emitting = true
	faiscas.finished.connect(faiscas.queue_free)
