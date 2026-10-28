extends RefCounted
## Composição responsiva da criação; seleção e persistência ficam na tela original.
const Estilo := preload("res://codigo/ui/estilo_criacao_fazenda.gd")
const Previa := preload("res://codigo/ui/previa_heroi_3d.gd")
const Catalogo := preload("res://codigo/dados/roupas_base_3d.gd")
var tela: Control
var _margem: MarginContainer
var _titulos: Array[Label]=[]
var _subtitulo: Label
var _grade_cabelos: GridContainer
var _seletores: Dictionary={}
var _focos: Dictionary={}

func montar(dona: Control):
	tela=dona
	var fundo=preload("res://codigo/ui/fundo_vila_viva.gd").new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	tela.add_child(fundo)
	var sombra := ColorRect.new()
	sombra.color=Color(.18,.20,.13,.38)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter=Control.MOUSE_FILTER_IGNORE
	tela.add_child(sombra)
	_margem=MarginContainer.new()
	_margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","top","right","bottom"]:_margem.add_theme_constant_override("margin_"+lado,10)
	if tela.etapa_coop>0:_margem.add_theme_constant_override("margin_top",30)
	tela.add_child(_margem)
	tela._colunas=BoxContainer.new()
	tela._colunas.add_theme_constant_override("separation",8)
	_margem.add_child(tela._colunas)
	tela._painel_previa=_previa()
	tela._painel_edicao=_editor()
	tela._colunas.add_child(tela._painel_previa)
	tela._colunas.add_child(tela._painel_edicao)
	tela.resized.connect(tela._ajustar_layout)
	ajustar.call_deferred()

func _painel(titulo: String) -> Array:
	var p := PanelContainer.new()
	Estilo.painel(p)
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation",5)
	p.add_child(linhas)
	var r := Estilo.rotulo(titulo,14)
	r.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	linhas.add_child(r)
	_titulos.append(r)
	return [p,linhas]
func _botao(texto: String, principal:=false) -> Button:
	var b := Button.new()
	b.text=texto
	Estilo.botao(b,principal)
	b.custom_minimum_size.y=26
	tela._botoes_estrutura.append(b)
	return b
func _seta(passo: int, chamada: Callable) -> Button:
	var b := Estilo.Seta.new()
	b.direcao=passo
	Estilo.botao(b)
	b.custom_minimum_size=Vector2(24,24)
	b.tooltip_text="Anterior" if passo<0 else "Próximo"
	b.pressed.connect(chamada)
	tela._botoes_estrutura.append(b)
	return b
func _previa() -> Control:
	var par := _painel("PRÉVIA")
	var p: PanelContainer=par[0]
	var linhas: VBoxContainer=par[1]
	tela._linhas_previa=linhas
	var titulo: Label=linhas.get_child(0)
	linhas.remove_child(titulo)
	var cabecalho := HBoxContainer.new()
	linhas.add_child(cabecalho)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	var dado := Estilo.Dado.new()
	Estilo.botao(dado)
	dado.custom_minimum_size=Vector2(24,24)
	dado.tooltip_text="Sortear aparência"
	dado.pressed.connect(tela.sortear)
	tela._botao_aleatorio=dado
	tela._botoes_estrutura.append(dado)
	cabecalho.add_child(dado)
	var moldura := PanelContainer.new()
	moldura.size_flags_vertical=Control.SIZE_EXPAND_FILL
	moldura.add_theme_stylebox_override("panel",Estilo.caixa(Color("a8b28a"),Color("ad8953"),3,1))
	linhas.add_child(moldura)
	var palco := Control.new()
	palco.clip_contents=true
	palco.custom_minimum_size=Vector2(0,80)
	moldura.add_child(palco)
	tela._palco=palco
	var paisagem := Estilo.Palco.new()
	paisagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.add_child(paisagem)
	tela._modelo=Node2D.new()
	palco.add_child(tela._modelo)
	palco.resized.connect(tela._centralizar_previa)
	# Camadas legadas continuam disponíveis para os dados de compatibilidade.
	tela._previa_corpo=tela._nova_camada(tela._textura_corpo)
	tela._previa_roupa=tela._nova_camada(null)
	tela._previa_cabelo=tela._nova_camada(null)
	for camada in [tela._previa_corpo,tela._previa_roupa,tela._previa_cabelo]:camada.hide()
	tela._previa_3d=Previa.new()
	tela._modelo.add_child(tela._previa_3d)
	var girar := HBoxContainer.new()
	girar.alignment=BoxContainer.ALIGNMENT_CENTER
	girar.add_theme_constant_override("separation",4)
	linhas.add_child(girar)
	girar.add_child(_seta(-1,tela._girar.bind(-1)))
	tela._rotulo_girar=Estilo.rotulo("Frente",9)
	tela._rotulo_girar.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tela._rotulo_girar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	girar.add_child(tela._rotulo_girar)
	girar.add_child(_seta(1,tela._girar.bind(1)))
	tela._rotulo_cabelo=Estilo.rotulo("",9)
	tela._rotulo_cabelo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	linhas.add_child(tela._rotulo_cabelo)
	tela._rotulo_roupa=Estilo.rotulo("")
	tela._rotulo_roupa.hide()
	linhas.add_child(tela._rotulo_roupa)
	return p
func _editor() -> Control:
	var par := _painel("SEU PERSONAGEM" if tela.modo_edicao else "UM NOVO COMEÇO")
	var p: PanelContainer=par[0]
	var linhas: VBoxContainer=par[1]
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	p.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tela._linhas_edicao=linhas
	_subtitulo=Estilo.rotulo("Uma aventura com a sua cara.",9)
	_subtitulo.add_theme_color_override("font_color",Color("8d714a"))
	linhas.add_child(_subtitulo)
	var nome := HBoxContainer.new()
	nome.add_theme_constant_override("separation",6)
	linhas.add_child(nome)
	tela._rotulo_nome=Estilo.rotulo("NOME",9)
	nome.add_child(tela._rotulo_nome)
	var campo := LineEdit.new()
	campo.placeholder_text="Como quer ser chamado?"
	campo.max_length=tela.MAX_APELIDO
	campo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	campo.custom_minimum_size.y=26
	campo.add_theme_font_override("font",Estilo.FONTE)
	campo.add_theme_font_size_override("font_size",10)
	campo.add_theme_color_override("font_color",Estilo.TINTA)
	campo.add_theme_color_override("font_placeholder_color",Color("a38c65"))
	campo.add_theme_color_override("caret_color",Estilo.TINTA)
	campo.add_theme_stylebox_override("normal",Estilo.caixa(Color("fff0c9"),Color("b49562"),6,1))
	campo.add_theme_stylebox_override("focus",Estilo.caixa(Color("fff5dc"),Color("95703c"),6,2))
	campo.text_changed.connect(tela._ao_nome_alterado)
	campo.gui_input.connect(tela._ao_entrada_nome)
	tela._campo_nome=campo
	nome.add_child(campo)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation",3)
	linhas.add_child(abas)
	var grupo := ButtonGroup.new()
	for i in 3:
		var b := _botao(["VISUAL","ROUPAS","CORES"][i])
		b.toggle_mode=true
		b.button_group=grupo
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.pressed.connect(tela._abrir_aba.bind(i))
		abas.add_child(b)
		tela._botoes_aba.append(b)
	tela._conteudo=Control.new()
	tela._conteudo.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tela._conteudo.custom_minimum_size.y=24
	linhas.add_child(tela._conteudo)
	tela._conteudo.resized.connect(tela._ajustar_paginas)
	tela._paginas.assign([_visual(),_roupas(),_cores()])
	for pagina in tela._paginas:
		pagina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tela._conteudo.add_child(pagina)
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation",6)
	linhas.add_child(rodape)
	tela._botao_voltar=_botao("VOLTAR")
	tela._botao_voltar.pressed.connect(tela.voltar)
	rodape.add_child(tela._botao_voltar)
	tela._botao_confirmar=_botao("COMEÇAR",true)
	tela._botao_confirmar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tela._botao_confirmar.pressed.connect(tela.confirmar)
	rodape.add_child(tela._botao_confirmar)
	return p
func _rolagem() -> Array:
	var r := ScrollContainer.new()
	r.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	r.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",7)
	r.add_child(v)
	return [r,v]
func _amostra(cor: Color, dica: String) -> Button:
	var b := Button.new()
	Estilo.botao(b)
	Estilo.amostra(b,false)
	b.custom_minimum_size=Vector2(22,22)
	b.tooltip_text=dica
	var preenchimento := ColorRect.new()
	preenchimento.color=cor
	preenchimento.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preenchimento.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preenchimento.offset_left=4
	preenchimento.offset_top=4
	preenchimento.offset_right=-4
	preenchimento.offset_bottom=-4
	b.add_child(preenchimento)
	return b
func _visual() -> Control:
	var par := _rolagem()
	var v: VBoxContainer=par[1]
	v.add_child(Estilo.rotulo("PENTEADO",9))
	_grade_cabelos=GridContainer.new()
	_grade_cabelos.columns=3
	_grade_cabelos.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_grade_cabelos.add_theme_constant_override("h_separation",3)
	_grade_cabelos.add_theme_constant_override("v_separation",3)
	v.add_child(_grade_cabelos)
	tela._opcoes_3d.cabelo=[]
	var grupo := ButtonGroup.new()
	for m in Catalogo.MODELOS.cabelo:
		var b := _botao(m.nome)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.toggle_mode=true
		b.button_group=grupo
		b.pressed.connect(tela._escolher_peca_3d.bind("cabelo",m.id))
		_grade_cabelos.add_child(b)
		tela._opcoes_3d.cabelo.append([m.id,b])
	var tons := HBoxContainer.new()
	tons.add_theme_constant_override("separation",4)
	v.add_child(tons)
	tela._rotulo_pele=Estilo.rotulo("PELE",9)
	tela._rotulo_pele.custom_minimum_size.x=32
	tons.add_child(tela._rotulo_pele)
	for i in 3:
		var b := _amostra(Previa.HeroiBase3D.PELES[i],"Tom de pele %d"%(i+1))
		b.pressed.connect(tela._escolher_pele.bind(i))
		tons.add_child(b)
		tela._botoes_pele.append(b)
	var olhos := HBoxContainer.new()
	olhos.add_theme_constant_override("separation",3)
	v.add_child(olhos)
	var rotulo := Estilo.rotulo("OLHOS",9)
	rotulo.custom_minimum_size.x=32
	olhos.add_child(rotulo)
	for i in tela.CORES_OLHOS.size():
		var b := _amostra(tela.CORES_OLHOS[i],"Cor dos olhos %d"%(i+1))
		b.pressed.connect(tela._escolher_olhos.bind(i))
		olhos.add_child(b)
		tela._botoes_olhos.append(b)
	var dica := Estilo.rotulo("A cor do cabelo fica na aba CORES.",9)
	dica.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_color_override("font_color",Color("8d714a"))
	v.add_child(dica)
	return par[0]
func _roupas() -> Control:
	var par := _rolagem()
	var v: VBoxContainer=par[1]
	v.add_theme_constant_override("separation",3)
	for categoria in ["camisa","calca","calcado"]:
		var titulo := HBoxContainer.new()
		v.add_child(titulo)
		var r := Estilo.rotulo({"camisa":"PARTE DE CIMA","calca":"PARTE DE BAIXO","calcado":"CALÇADO"}[categoria],9)
		r.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		titulo.add_child(r)
		var indice := Estilo.rotulo("",9)
		indice.add_theme_color_override("font_color",Color("967448"))
		titulo.add_child(indice)
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation",4)
		v.add_child(linha)
		var anterior := _seta(-1,_mudar_peca.bind(categoria,-1))
		linha.add_child(anterior)
		var valor := Estilo.rotulo("",10)
		valor.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		valor.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		valor.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		valor.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		linha.add_child(valor)
		linha.add_child(_seta(1,_mudar_peca.bind(categoria,1)))
		_seletores[categoria]={"valor":valor,"indice":indice}
		_focos[categoria]=anterior
		# Mantém a API de seleção usada pelo editor e pelas verificações de save.
		tela._opcoes_3d[categoria]=[]
		for m in Catalogo.MODELOS[categoria]:
			var b := Button.new()
			b.hide()
			b.pressed.connect(tela._escolher_peca_3d.bind(categoria,m.id))
			v.add_child(b)
			tela._opcoes_3d[categoria].append([m.id,b])
	return par[0]
func _mudar_peca(categoria: String, passo: int):
	var lista: Array=Catalogo.MODELOS[categoria]
	var atual := 0
	for i in lista.size():
		if lista[i].id==tela.roupas_3d[categoria]:atual=i
	tela._escolher_peca_3d(categoria,lista[posmod(atual+passo,lista.size())].id)
func _cores() -> Control:
	var par := _rolagem()
	var v: VBoxContainer=par[1]
	v.add_child(Estilo.rotulo("COR DO CABELO",9))
	tela._grade_cores=GridContainer.new()
	tela._grade_cores.columns=10
	tela._grade_cores.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_child(tela._grade_cores)
	for i in tela.PALETA.size():
		var b := _amostra(tela.PALETA[i],"Cor do cabelo %d"%(i+1))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.pressed.connect(tela._escolher_cor.bind(tela.PALETA[i]))
		tela._grade_cores.add_child(b)
		tela._casas_cor.append(b)
	tela._titulo_cor=Estilo.rotulo("AJUSTE FINO",9)
	v.add_child(tela._titulo_cor)
	tela._slider_matiz=tela._novo_slider(v,"MATIZ",360)
	tela._slider_saturacao=tela._novo_slider(v,"FORÇA",100)
	tela._slider_brilho=tela._novo_slider(v,"BRILHO",100)
	for slider in [tela._slider_matiz,tela._slider_saturacao,tela._slider_brilho]:
		slider.value_changed.connect(tela._ao_slider_alterado)
		slider.get_parent().get_child(0).add_theme_color_override("font_color",Estilo.TINTA)
	return par[0]
func atualizar_seletores():
	for categoria in _seletores:
		var lista: Array=Catalogo.MODELOS[categoria]
		for i in lista.size():
			if lista[i].id!=tela.roupas_3d[categoria]:continue
			_seletores[categoria].valor.text=String(lista[i].nome).replace(" com meia-calça","").replace(" de mangas","").replace(" antigo","")
			_seletores[categoria].indice.text="%d / %d"%[i+1,lista.size()]
func focar_roupa():
	Controle.focar(_focos.camisa)
func ajustar():
	if tela._colunas==null:return
	var retrato: bool=tela.size.y>=400 and tela.size.y>tela.size.x*1.2
	tela._compacto=tela.size.x<500 or tela.size.y<300
	tela._minimo=tela.size.x<360 and not retrato
	tela._colunas.vertical=retrato
	tela._painel_previa.custom_minimum_size=Vector2(0,160) if retrato else Vector2(80 if tela._minimo else (130 if tela._compacto else 168),0)
	tela._painel_previa.size_flags_vertical=Control.SIZE_FILL if retrato else Control.SIZE_EXPAND_FILL
	tela._painel_edicao.custom_minimum_size=Vector2.ZERO
	tela._rotulo_nome.visible=not tela._minimo
	for painel in [tela._painel_previa, tela._painel_edicao]:
		var caixa: StyleBoxFlat=painel.get_theme_stylebox("panel")
		for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:caixa.set_content_margin(lado,6 if tela._minimo else 10)
	_subtitulo.visible=not tela._compacto
	for r in _titulos:r.add_theme_font_size_override("font_size",11 if tela._compacto else 14)
	for b in tela._botoes_estrutura:
		b.add_theme_font_size_override("font_size",8 if tela._minimo else (9 if tela._compacto else 10))
		b.custom_minimum_size.y=22 if tela._compacto else 26
	tela._campo_nome.add_theme_font_size_override("font_size",8 if tela._minimo else (9 if tela._compacto else 10))
	tela._campo_nome.custom_minimum_size.y=22 if tela._compacto else 26
	for linhas in [tela._linhas_previa,tela._linhas_edicao]:linhas.add_theme_constant_override("separation",4 if tela._compacto else 5)
	tela._rotulo_cabelo.visible=not retrato and not tela._minimo
	tela._centralizar_previa.call_deferred()
	ajustar_controles.call_deferred()
func ajustar_controles():
	if tela._conteudo==null:return
	var largura: float=tela._conteudo.size.x
	_grade_cabelos.columns=3 if largura>=230 else (2 if largura>=155 else 1)
	var colunas := 10 if largura>=270 else (8 if largura>=210 else 6)
	tela._grade_cores.columns=colunas
	tela._grade_cores.add_theme_constant_override("h_separation",3)
	tela._grade_cores.add_theme_constant_override("v_separation",3)
	for b in tela._casas_cor:b.custom_minimum_size=Vector2(18 if tela._compacto else 24,20 if tela._compacto else 24)
	var lado := minf(22.0,floorf((largura-40-15)/6.0))
	for b in tela._botoes_olhos:b.custom_minimum_size=Vector2(maxf(12,lado),22)
