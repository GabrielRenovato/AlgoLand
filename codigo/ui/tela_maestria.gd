extends Control
## Nós compactos com ícones; detalhes e ações aparecem apenas ao selecionar um nó.
const Catalogo := preload("res://codigo/dados/catalogo_maestria.gd")
const Estilo := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const TAMANHO_MAPA := Vector2(460,380)
const ICONES := {
	"espada":"espada_basica", "montante":"espada_gemea", "lanca":"lanca_basica", "machado":"machado", "maca":"maca", "arco":"arco_curto", "escudo":"escudo_basico"}
var painel: PanelContainer
var componente: Node
var modelo: RefCounted
var familia := "espada"
var ramo := 0
var zoom := 0.85
var _coluna: VBoxContainer
var _familias: OptionButton
var _resumo: Label
var _progresso: ProgressBar
var _mensagem: Label
var _rolagem: ScrollContainer
var _arvore: Control
var _redistribuir: Button
var _foco_inicial: Button
var _nos: Dictionary = {}
var _posicoes: Dictionary = {}
var _conexoes: Array = []
var _confirmar_reset := false
var _centrar := true
var _selecionado := ""
var _detalhe: PanelContainer
var _detalhe_coluna: VBoxContainer
var _nome: Label
var _descricao: Label
var _requisitos: Label
var _acao: Button
var _fechar_dica: Button
var _atualizacao_pendente := false
var _arrastando := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var cortina:=ColorRect.new()
	cortina.color=Color(0.04,0.06,0.07,0.78)
	cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cortina)
	painel=PanelContainer.new()
	add_child(painel)
	Estilo.painel(painel,false,14,true)
	_coluna=VBoxContainer.new()
	_coluna.add_theme_constant_override("separation",6)
	painel.add_child(_coluna)
	var cabecalho:=HBoxContainer.new()
	_coluna.add_child(cabecalho)
	var titulo:=_rotulo("MAESTRIA",14,Color("efd298"))
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	_foco_inicial=_botao("VOLTAR",func(): EventosJogo.fechar_tela_de(self,"maestria"))
	cabecalho.add_child(_foco_inicial)
	var linha:=HBoxContainer.new()
	_coluna.add_child(linha)
	_familias=OptionButton.new()
	_familias.fit_to_longest_item=false
	_familias.clip_text=true
	_familias.custom_minimum_size=Vector2(90,30)
	_familias.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_familias.add_theme_font_override("font",FONTE)
	_familias.add_theme_font_size_override("font_size",10)
	for f in Catalogo.FAMILIAS:_familias.add_item(Catalogo.NOMES[f])
	_familias.item_selected.connect(func(i):familia=Catalogo.FAMILIAS[i];_selecionado="";_detalhe.hide();_centrar=true;_confirmar_reset=false;atualizar())
	linha.add_child(_familias)
	_resumo=_rotulo("",9)
	_resumo.autowrap_mode=TextServer.AUTOWRAP_OFF
	_resumo.custom_minimum_size.x=90
	_resumo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	linha.add_child(_resumo)
	_progresso=ProgressBar.new()
	_progresso.custom_minimum_size.y=5
	_progresso.show_percentage=false
	var trilho:=StyleBoxFlat.new();trilho.bg_color=Color("182128")
	var preenchido:=StyleBoxFlat.new();preenchido.bg_color=Color("cba45d")
	_progresso.add_theme_stylebox_override("background",trilho)
	_progresso.add_theme_stylebox_override("fill",preenchido)
	_coluna.add_child(_progresso)
	_rolagem=ScrollContainer.new()
	_rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	_rolagem.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	_rolagem.follow_focus=true
	_rolagem.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_rolagem.custom_minimum_size.y=40
	_coluna.add_child(_rolagem)
	_arvore=Control.new()
	_arvore.mouse_filter=Control.MOUSE_FILTER_PASS
	_arvore.draw.connect(_desenhar_ligacoes)
	_arvore.gui_input.connect(_arrastar)
	_rolagem.add_child(_arvore)
	var rodape:=HBoxContainer.new()
	rodape.add_theme_constant_override("separation",4)
	_coluna.add_child(rodape)
	_redistribuir=_botao("REDISTRIBUIR",_resetar)
	_redistribuir.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rodape.add_child(_redistribuir)
	for par in [["-",-0.15],["+",0.15]]:
		var botao:=_botao(par[0],_mudar_zoom.bind(float(par[1])))
		botao.custom_minimum_size.x=32
		botao.tooltip_text="DIMINUIR ARVORE" if par[1]<0 else "AMPLIAR ARVORE"
		rodape.add_child(botao)
	var inicio:=_botao("CENTRO",func():_centrar=true;_centralizar.call_deferred())
	inicio.custom_minimum_size.x=64
	rodape.add_child(inicio)
	_mensagem=_rotulo("Selecione um no para ver detalhes. Arraste para explorar.",8,Color("d6c6a8"))
	_coluna.add_child(_mensagem)
	_montar_detalhe()
	visibility_changed.connect(_ao_abrir)
	resized.connect(_organizar)
	_organizar()
	hide()

func _rotulo(texto: String,tamanho: int,cor:=Color("f0e5cb")) -> Label:
	var label:=Label.new()
	label.text=texto
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",FONTE)
	label.add_theme_font_size_override("font_size",tamanho)
	label.add_theme_color_override("font_color",cor)
	return label

func _botao(texto: String,acao: Callable) -> Button:
	var botao:=Button.new()
	botao.text=texto
	botao.custom_minimum_size=Vector2(64,30)
	botao.clip_text=true
	Estilo.botao(botao)
	botao.pressed.connect(acao)
	return botao

func _montar_detalhe() -> void:
	_detalhe=PanelContainer.new()
	_detalhe.z_index=10
	var fundo:=StyleBoxFlat.new()
	fundo.bg_color=Color("17232b")
	fundo.border_color=Color("d6b772")
	fundo.set_border_width_all(1)
	fundo.set_content_margin_all(12)
	fundo.shadow_color=Color(0,0,0,0.65)
	fundo.shadow_size=5
	_detalhe.add_theme_stylebox_override("panel",fundo)
	add_child(_detalhe)
	_detalhe_coluna=VBoxContainer.new()
	_detalhe_coluna.add_theme_constant_override("separation",7)
	_detalhe.add_child(_detalhe_coluna)
	_nome=_rotulo("",11,Color("f1cf83"))
	_detalhe_coluna.add_child(_nome)
	_descricao=_rotulo("",10)
	_detalhe_coluna.add_child(_descricao)
	_requisitos=_rotulo("",8,Color("c9c6b8"))
	_detalhe_coluna.add_child(_requisitos)
	_acao=_botao("APRENDER",_escolher)
	_detalhe_coluna.add_child(_acao)
	_fechar_dica=_botao("FECHAR DETALHES",_fechar_detalhe)
	_detalhe_coluna.add_child(_fechar_dica)
	_detalhe.hide()

func _ao_abrir() -> void:
	if not visible:return
	var dono:=EventosJogo.dono(self)
	if dono==null or dono.get("maestria")==null:return
	componente=dono.maestria;modelo=componente.modelo
	if not modelo.alterado.is_connected(_agendar):modelo.alterado.connect(_agendar)
	familia=componente.familia_atual()
	if familia.is_empty():familia="espada"
	_confirmar_reset=false;_selecionado="";_detalhe.hide();_centrar=true
	atualizar()
	# As molduras e a quebra de linhas assentam depois da primeira abertura em cada viewport.
	for i in 3:
		await get_tree().process_frame
		if not is_visible_in_tree(): return
		_organizar()
	_centrar=true
	_centralizar()

func _agendar() -> void:
	if not visible or _atualizacao_pendente:return
	_atualizacao_pendente=true
	atualizar.call_deferred()

func _organizar() -> void:
	if painel==null:return
	var margens:=Controle.margens_seguras()
	var esquerda:=10.0+margens.x
	var direita:=size.x-10.0-margens.z
	var largura:=minf(760.0,direita-esquerda)
	painel.position=Vector2((esquerda+direita-largura)*0.5,8+margens.y)
	painel.size=Vector2(largura,maxf(100,size.y-16-margens.y-margens.w))
	if _detalhe!=null and _detalhe.visible:_posicionar_detalhe.call_deferred()
	if _centrar:_centralizar.call_deferred()

func atualizar() -> void:
	_atualizacao_pendente=false
	if modelo==null:return
	var foco:=get_viewport().gui_get_focus_owner()
	var id_foco:=str(foco.get_meta("habilidade","")) if foco!=null else ""
	for filho in _arvore.get_children():_arvore.remove_child(filho);filho.queue_free()
	_nos.clear();_posicoes.clear();_conexoes.clear()
	_familias.select(Catalogo.FAMILIAS.find(familia))
	var n:int=modelo.nivel(familia)
	_resumo.text="%d / 100\n%d PONTOS" % [n,modelo.disponiveis(familia)]
	var xp:int=modelo.experiencia[familia]
	_progresso.min_value=Catalogo.xp_para_nivel(n)
	_progresso.max_value=Catalogo.xp_para_nivel(n+1) if n<100 else xp+1
	_progresso.value=xp
	_progresso.tooltip_text="DOMINIO %d / %d" % [xp,Catalogo.xp_para_nivel(n+1)]
	_arvore.custom_minimum_size=TAMANHO_MAPA*zoom
	_arvore.size=Vector2(maxf(TAMANHO_MAPA.x*zoom,painel.size.x-40),TAMANHO_MAPA.y*zoom)
	_no_visual("raiz",Vector2(230,20),_icone(familia),true,true)
	_no_visual("fundamentos",Vector2(290,52),_icone(familia),n>=5 or modelo.legado or familia in ["arco","escudo"],true)
	_conexoes.append(["raiz","fundamentos"])
	for r in 3:
		var titulo:=_rotulo(Catalogo.RAMOS[familia][r],8,Color("d6bd85"))
		titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		titulo.position=_posicao_mapa(Vector2(44+r*130,65))
		titulo.size=Vector2(112*zoom,26)
		titulo.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_arvore.add_child(titulo)
	for dado in Catalogo.nos(familia):
		var x:float=100.0+dado.ramo*130.0
		if dado.degrau%2==1:x+=-38 if dado.ramo==0 else (38 if dado.ramo==2 else 0)
		var p:=Vector2(x,100+dado.degrau*48)
		var aprendida:bool=dado.id in modelo.aprendidos
		_no_visual(dado.id,p,_icone_no(dado),aprendida,modelo.motivo_aprender(dado.id).is_empty())
		_conexoes.append(["raiz" if dado.requisito.is_empty() else dado.requisito,dado.id])
	for dado in Catalogo.nos(familia):
		var botao:Button=_nos[dado.id]
		botao.focus_neighbor_top=botao.get_path_to(_nos[dado.requisito] if not dado.requisito.is_empty() else _nos.raiz)
		if dado.degrau<5:botao.focus_neighbor_bottom=botao.get_path_to(_nos["%s_%d_%d" % [familia,dado.ramo,dado.degrau+1]])
		if dado.ramo>0:botao.focus_neighbor_left=botao.get_path_to(_nos["%s_%d_%d" % [familia,dado.ramo-1,dado.degrau]])
		if dado.ramo<2:botao.focus_neighbor_right=botao.get_path_to(_nos["%s_%d_%d" % [familia,dado.ramo+1,dado.degrau]])
	_redistribuir.disabled=not componente.pode_redistribuir()
	_redistribuir.text="CONFIRMAR" if _confirmar_reset else "REDISTRIBUIR"
	_redistribuir.tooltip_text="DEVOLVE OS PONTOS DESTA ARMA, MANTENDO A EXPERIENCIA" if not _redistribuir.disabled else "VISITE A CIDADE PARA REDISTRIBUIR"
	_arvore.queue_redraw()
	_organizar()
	if not id_foco.is_empty() and _nos.has(id_foco):_nos[id_foco].grab_focus()
	if _detalhe.visible:_atualizar_detalhe()
	_centralizar.call_deferred()

func _posicao_mapa(p: Vector2) -> Vector2:
	return p*zoom+Vector2(maxf(0,(painel.size.x-40-TAMANHO_MAPA.x*zoom)*0.5),0)

func _icone(f: String) -> Texture2D:
	return load("res://assets/personagens/raven_fantasy/icones/%s.png" % ICONES[f])

func _icone_no(dado: Dictionary) -> Texture2D:
	if dado.tipo in ["tecnica","finalizador"]:return _icone(dado.familia)
	if dado.ramo==2:return _icone("escudo")
	if dado.ramo==1:return _icone("machado")
	return load("res://assets/ui/sem org/3 Icons/Icons_10.png")

func _no_visual(id: String,p: Vector2,icone: Texture2D,aprendido: bool,disponivel: bool) -> void:
	var botao:=Button.new()
	botao.set_meta("habilidade",id)
	var alvo:=maxf(32,30*zoom)
	botao.position=(_posicao_mapa(p)-Vector2.ONE*alvo*0.5).round()
	botao.size=Vector2.ONE*roundf(alvo)
	botao.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	botao.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	botao.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	var foco:=StyleBoxFlat.new();foco.draw_center=false;foco.border_color=Color("f7dfa0");foco.set_border_width_all(1)
	botao.add_theme_stylebox_override("focus",foco)
	botao.pressed.connect(_abrir_detalhe.bind(id))
	_arvore.add_child(botao)
	_nos[id]=botao;_posicoes[id]=botao.position+botao.size*0.5
	var quadro:=PanelContainer.new()
	quadro.name="Quadrado"
	quadro.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lado:=roundf(24*zoom)
	quadro.position=(Vector2.ONE*(alvo-lado)*0.5).round()
	quadro.size=Vector2.ONE*lado
	var fundo:=StyleBoxFlat.new()
	fundo.bg_color=Color("514637") if aprendido else Color("1c2830")
	fundo.border_color=Color("efc66e") if aprendido else (Color("a69a77") if disponivel else Color("4c5a60"))
	fundo.set_border_width_all(2 if aprendido else 1)
	fundo.set_content_margin_all(3*zoom)
	quadro.add_theme_stylebox_override("panel",fundo)
	botao.add_child(quadro)
	var imagem:=TextureRect.new()
	imagem.texture=icone
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	imagem.modulate=Color.WHITE if aprendido or disponivel else Color(0.45,0.48,0.49)
	quadro.add_child(imagem)
	if modelo.equipados.has(familia):
		var selecao:Dictionary=modelo.equipados[familia]
		var texto:=str(selecao.tecnicas.find(id)+1) if id in selecao.tecnicas else ("F" if id==selecao.finalizador else "")
		if not texto.is_empty():
			var marca:=_rotulo(texto,8,Color("fff0a7"))
			marca.position=Vector2(alvo-7,-4);marca.size=Vector2(10,12)
			marca.add_theme_constant_override("outline_size",2)
			marca.add_theme_color_override("font_outline_color",Color("151c22"))
			marca.mouse_filter=Control.MOUSE_FILTER_IGNORE
			botao.add_child(marca)

func _desenhar_ligacoes() -> void:
	for par in _conexoes:
		var a:Vector2=_posicoes[par[0]]
		var b:Vector2=_posicoes[par[1]]
		var aprendida:bool=par[1] in modelo.aprendidos or par[1]=="fundamentos" and (modelo.nivel(familia)>=5 or modelo.legado or familia in ["arco","escudo"])
		var cor:=Color("a78a4f") if aprendida else Color("465057")
		var meio:Vector2=(a+b)*0.5
		_arvore.draw_polyline(PackedVector2Array([a,Vector2(a.x,meio.y),Vector2(b.x,meio.y),b]),cor,2*zoom,true)

func _abrir_detalhe(id: String) -> void:
	_selecionado=id
	_detalhe.show()
	_atualizar_detalhe()
	Controle.focar(_acao if not _acao.disabled else _fechar_dica)

func _atualizar_detalhe() -> void:
	var dado:=Catalogo.no(_selecionado)
	if dado.is_empty():
		_nome.text=Catalogo.NOMES[familia] if _selecionado=="raiz" else "COMBO DE TRES GOLPES"
		_descricao.text="Use esta familia em combates reais. A experiencia permanece ao trocar de equipamento e ao morrer." if _selecionado=="raiz" else "A maestria 5 libera o terceiro golpe. Personagens anteriores conservam seus fundamentos."
		_requisitos.text="APRENDIZADO PELO USO" if _selecionado=="raiz" else ("FUNDAMENTO DESBLOQUEADO" if modelo.nivel(familia)>=5 or modelo.legado else "REQUER MAESTRIA 5")
		if _selecionado=="fundamentos" and familia in ["arco","escudo"]:
			_nome.text="ESCUDADA APOS APARO" if familia=="escudo" else "SEQUENCIA DE DISPAROS"
			_descricao.text="Aparar com o escudo abre uma escudada. Um finalizador aprendido e equipado substitui essa resposta." if familia=="escudo" else "Tres disparos proximos formam uma sequencia. Um finalizador aprendido e equipado substitui o terceiro."
			_requisitos.text="MECANICA DE COMBATE"
		_acao.hide()
	else:
		_nome.text=dado.nome
		_descricao.text=dado.descricao
		var aprendida:bool=dado.id in modelo.aprendidos
		var selecao:Dictionary=modelo.equipados[familia]
		var equipada:bool=dado.id in selecao.tecnicas or dado.id==selecao.finalizador
		_requisitos.text="%s | MAESTRIA %d | CUSTO: 1 PONTO" % [str(dado.tipo).to_upper(),dado.nivel]
		if not dado.requisito.is_empty():_requisitos.text+="\nREQUER: "+Catalogo.no(dado.requisito).nome
		if aprendida:_requisitos.text+="\nAPRENDIDA"+(" / EQUIPADA" if equipada else "")
		var motivo:String=modelo.motivo_aprender(dado.id)
		_acao.text=("PASSIVA ATIVA" if dado.tipo=="passiva" else "RETIRAR" if equipada else "EQUIPAR") if aprendida else ("APRENDER" if motivo.is_empty() else motivo)
		_acao.disabled=(aprendida and dado.tipo=="passiva") or (not aprendida and not motivo.is_empty()) or not modelo.pronto
		_acao.show()
	_detalhe.size.x=minf(270,size.x-32)
	_detalhe.size.y=0
	_posicionar_detalhe.call_deferred()

func _posicionar_detalhe() -> void:
	if not _detalhe.visible:return
	_detalhe.size.y=0
	var pos:=size*0.5-_detalhe.size*0.5
	if _nos.has(_selecionado):
		var alvo:Rect2=_nos[_selecionado].get_global_rect()
		pos=alvo.end+Vector2(8,6)
	_detalhe.position=Vector2(clampf(pos.x,12,maxf(12,size.x-_detalhe.size.x-12)),clampf(pos.y,12,maxf(12,size.y-_detalhe.size.y-12)))

func _fechar_detalhe() -> void:
	_detalhe.hide()
	if _nos.has(_selecionado):Controle.focar(_nos[_selecionado])

func _escolher() -> void:
	if Catalogo.no(_selecionado).is_empty():return
	var erro:Error=modelo.equipar(_selecionado) if _selecionado in modelo.aprendidos else modelo.aprender(_selecionado)
	_mensagem.text="ESCOLHA SALVA" if erro==OK else ("RETIRE UMA TECNICA: LIMITE DE DUAS" if erro==ERR_OUT_OF_MEMORY else "NAO FOI POSSIVEL SALVAR")
	atualizar()

func _resetar() -> void:
	if not componente.pode_redistribuir():return
	if not _confirmar_reset:
		_confirmar_reset=true;_mensagem.text="CONFIRME PARA DEVOLVER OS PONTOS. A EXPERIENCIA PERMANECE."
		atualizar();return
	var erro:Error=modelo.redistribuir(familia)
	_confirmar_reset=false
	_mensagem.text="PONTOS DEVOLVIDOS" if erro==OK else "NAO FOI POSSIVEL SALVAR"
	atualizar()

func _mudar_zoom(passo: float) -> void:
	zoom=clampf(zoom+passo,0.7,1.6)
	_centrar=true
	atualizar()

func _centralizar() -> void:
	if not _centrar or _rolagem==null:return
	_rolagem.scroll_horizontal=roundi(maxf(0,(_arvore.size.x-_rolagem.size.x)*0.5))
	_rolagem.scroll_vertical=0
	_centrar=false

func _arrastar(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
		_arrastando=evento.pressed

func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree():return
	if evento is InputEventMouseButton and not evento.pressed:_arrastando=false
	if _arrastando and evento is InputEventMouseMotion:
		_rolagem.scroll_horizontal-=roundi(evento.relative.x)
		_rolagem.scroll_vertical-=roundi(evento.relative.y)
		get_viewport().set_input_as_handled()
	if not _detalhe.visible:return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("close_menu"):
		get_viewport().set_input_as_handled();_fechar_detalhe()
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index==MOUSE_BUTTON_LEFT and not (_detalhe.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,_detalhe.size)).has_point(evento.position):
		_detalhe.hide()

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	_organizar()
	if _detalhe.visible:_posicionar_detalhe()

func focar_inicio() -> void:
	Controle.focar(_nos.get("raiz",_foco_inicial))
