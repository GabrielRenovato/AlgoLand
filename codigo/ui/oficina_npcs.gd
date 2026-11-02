extends Control
## Ferramenta local: usa o rig real, exporta fichas e não altera o personagem do jogador.
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Catalogo=preload("res://codigo/dados/roupas_base_3d.gd")
const Estilo=preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const Variacao=preload("res://codigo/dados/variacao_npcs.gd")
const Acessorios=preload("res://codigo/npcs/acessorios_npc_3d.gd")
var ficha:Dictionary={}
var visual:Node2D
var _grid:GridContainer
var _palco:Control
var _conteudo:VBoxContainer
var _perfil:OptionButton
var _morador:OptionButton
var _movimento:OptionButton
var _semente:SpinBox
var _nome:LineEdit
var _estado:Label
var _seletores:Dictionary={}
var _direcao:=0
var _andar:=false
var _conversar:=false
var _corpo:=false
var _tempo:=0.0
var _montando:=false
var _idade:OptionButton
var _altura:HSlider
var _corpulencia:HSlider
var _acessorios:Dictionary={}
var _cores:Dictionary={}
var _sincronizando:=false

func _ready() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Abra a oficina pelo launcher isolado.")
		get_tree().quit(1);return
	_montando=true
	var fundo:=ColorRect.new()
	fundo.color=Color("243a38")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem:=MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for borda in ["left","top","right","bottom"]:margem.add_theme_constant_override("margin_"+borda,12)
	add_child(margem)
	var raiz:=VBoxContainer.new()
	raiz.add_theme_constant_override("separation",8)
	margem.add_child(raiz)
	var titulo:=Label.new()
	titulo.text="Oficina de NPCs"
	titulo.add_theme_font_size_override("font_size",16)
	raiz.add_child(titulo)
	_grid=GridContainer.new()
	_grid.columns=2
	_grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",12)
	raiz.add_child(_grid)
	_palco=Control.new()
	_palco.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_palco.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_grid.add_child(_palco)
	var painel:=PanelContainer.new()
	painel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	painel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	Estilo.painel(painel,false,14)
	_grid.add_child(painel)
	var rolagem:=ScrollContainer.new()
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)
	_conteudo=VBoxContainer.new()
	_conteudo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_conteudo.add_theme_constant_override("separation",6)
	rolagem.add_child(_conteudo)
	_rotulo("Morador da cidade")
	_morador=OptionButton.new()
	_morador.fit_to_longest_item=false
	_morador.add_item("NPC livre")
	var moradores:=Elenco.dados()
	for id in moradores:
		_morador.add_item(moradores[id].nome)
		_morador.set_item_metadata(_morador.item_count-1,id)
	_conteudo.add_child(_morador)
	_morador.item_selected.connect(_selecionar_morador)
	_rotulo("Movimento")
	_movimento=OptionButton.new()
	_movimento.add_item("Neutro")
	_movimento.add_item("Feminino")
	_conteudo.add_child(_movimento)
	_movimento.item_selected.connect(func(indice):
		ficha.movimento="feminino" if indice==1 else "neutro"
		visual.perfil_movimento=ficha.movimento)
	_rotulo("Ofício")
	_perfil=OptionButton.new()
	for perfil in Gerador.PERFIS:_perfil.add_item(Gerador.PERFIS[perfil].nome)
	_conteudo.add_child(_perfil)
	_perfil.item_selected.connect(func(_i):gerar())
	_rotulo("Semente")
	_semente=SpinBox.new()
	_semente.max_value=999999999
	_semente.value=1
	_conteudo.add_child(_semente)
	Estilo.campo(_semente.get_line_edit())
	_semente.value_changed.connect(func(_v):gerar())
	_rotulo("Nome")
	_nome=LineEdit.new()
	Estilo.campo(_nome)
	_conteudo.add_child(_nome)
	_nome.text_changed.connect(func(texto):ficha.nome=texto.left(32))
	for categoria in Catalogo.CATEGORIAS:
		_rotulo({"camisa":"Parte de cima","calca":"Parte de baixo","calcado":"Calçado","cabelo":"Cabelo"}[categoria])
		var opcao:=OptionButton.new()
		opcao.fit_to_longest_item=false
		for modelo in Catalogo.MODELOS[categoria]:opcao.add_item(modelo.nome)
		_conteudo.add_child(opcao)
		_seletores[categoria]=opcao
		opcao.item_selected.connect(_mudar_peca.bind(categoria))
	if Variacao.ATIVA:_montar_variedade()
	_botao("Outro NPC",func():_semente.value+=1)
	_botao("Virar",func():_direcao=(_direcao+1)%4)
	_botao("Parado / andando",func():_andar=not _andar;_conversar=false)
	_botao("Conversar",func():_conversar=not _conversar)
	_botao("Ver corpo / vestir",_alternar_corpo)
	_botao("Salvar ficha",_escolher_arquivo)
	_estado=Label.new()
	_estado.text="Corpo, roupas e cabelo independentes."
	_estado.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_estado.add_theme_font_size_override("font_size",9)
	raiz.add_child(_estado)
	resized.connect(_ajustar)
	_palco.resized.connect(_ajustar_visual)
	_montando=false
	gerar()
	_ajustar()

func _rotulo(texto: String) -> void:
	var label:=Label.new()
	label.text=texto
	label.add_theme_font_size_override("font_size",10)
	_conteudo.add_child(label)

func _botao(texto: String,acao: Callable) -> void:
	var botao:=Button.new()
	botao.text=texto
	botao.custom_minimum_size.y=28
	Estilo.botao(botao)
	botao.pressed.connect(acao)
	_conteudo.add_child(botao)

func gerar() -> void:
	if _montando:return
	_morador.select(0)
	var perfil:String=Gerador.PERFIS.keys()[_perfil.selected]
	ficha=Gerador.gerar(int(_semente.value),perfil)
	_mostrar_ficha()

func _selecionar_morador(indice: int) -> void:
	_morador.select(indice)
	if indice==0:
		gerar()
		return
	var id:String=_morador.get_item_metadata(indice)
	ficha=Elenco.ficha(id)
	_perfil.select(Gerador.PERFIS.keys().find(ficha.perfil))
	_semente.set_value_no_signal(ficha.semente)
	_mostrar_ficha()

func _mostrar_ficha() -> void:
	_nome.text=ficha.nome
	_movimento.select(1 if ficha.movimento=="feminino" else 0)
	for categoria in Catalogo.CATEGORIAS:
		for i in Catalogo.MODELOS[categoria].size():
			if Catalogo.MODELOS[categoria][i].id==ficha.aparencia.roupas_3d[categoria]:_seletores[categoria].select(i)
	_sincronizar_variedade()
	_aplicar_visual()

func _aplicar_visual() -> void:
	if visual!=null:
		_palco.remove_child(visual)
		visual.queue_free()
	var infantil:bool=ficha.get("faixa_etaria","")=="crianca"
	for seletor in _seletores.values():seletor.disabled=infantil
	_movimento.disabled=infantil
	if infantil:
		visual=load("res://codigo/npcs/manequim_infantil_3d.gd").new()
		visual.traje_infantil=ficha.traje_infantil
		visual.cabelo_infantil=ficha.cabelo_infantil
	else:
		visual=load("res://codigo/jogador/representacao_heroi_3d.gd").new()
	visual.aparencia=ficha.aparencia
	visual.armadura_npc=ficha.get("armadura_npc","")
	visual.perfil_movimento=ficha.movimento
	_palco.add_child(visual)
	visual.heroi.acabamento_pixel_art=true
	_aplicar_visibilidade()
	_reaplicar_variedade()
	_ajustar_visual()

## Idade, corpo, cores e acessórios (variacao_npcs.gd). Os controles espelham ficha.variacao.
func _montar_variedade() -> void:
	_rotulo("Idade")
	_idade=OptionButton.new()
	for nome in ["Jovem","Adulto","Idoso"]:_idade.add_item(nome)
	_conteudo.add_child(_idade)
	_idade.item_selected.connect(_mudar_idade)
	_rotulo("Altura")
	_altura=_barra(0.85,1.12,func(v):_mudar_variacao("altura",v))
	_rotulo("Corpulência")
	_corpulencia=_barra(0.85,1.2,func(v):_mudar_variacao("corpulencia",v))
	_rotulo("Cores das roupas")
	for categoria in Variacao.CATEGORIAS_COR:
		var seletor:=ColorPickerButton.new()
		seletor.edit_alpha=false
		seletor.text={"camisa":"Parte de cima","calca":"Parte de baixo","calcado":"Calçado"}[categoria]
		seletor.custom_minimum_size.y=22
		_conteudo.add_child(seletor)
		_cores[categoria]=seletor
		seletor.color_changed.connect(func(cor):
			if _sincronizando:return
			ficha.variacao.cores[categoria]=cor.to_html(false)
			_reaplicar_variedade())
	_rotulo("Acessórios")
	for id in Variacao.ACESSORIOS:
		var caixa:=CheckBox.new()
		caixa.text=Variacao.ACESSORIOS[id].nome
		_conteudo.add_child(caixa)
		_acessorios[id]=caixa
		caixa.toggled.connect(func(ligado):
			if _sincronizando:return
			var lista:Array=ficha.variacao.acessorios
			if ligado and not id in lista:lista.append(id)
			if not ligado:lista.erase(id)
			_reaplicar_variedade())
	_botao("Sortear cores",_sortear_cores)

func _barra(minimo: float,maximo: float,acao: Callable) -> HSlider:
	var barra:=HSlider.new()
	barra.min_value=minimo
	barra.max_value=maximo
	barra.step=0.01
	barra.custom_minimum_size.y=18
	_conteudo.add_child(barra)
	barra.value_changed.connect(func(v):
		if not _sincronizando:acao.call(v))
	return barra

func _mudar_variacao(campo: String,valor: float) -> void:
	if not ficha.has("variacao"):return
	ficha.variacao[campo]=valor
	_reaplicar_variedade()

func _mudar_idade(indice: int) -> void:
	if not ficha.has("variacao"):return
	var idade:String=Variacao.IDADES[indice]
	ficha.variacao.idade=idade
	ficha.variacao.postura=0.08 if idade=="idoso" else 0.0
	if idade=="idoso":
		var cinza:=Color(Variacao.CINZA_IDOSO)
		ficha.aparencia.cor=[cinza.r,cinza.g,cinza.b,1.0]
		_aplicar_visual()
	_reaplicar_variedade()
	_sincronizar_variedade()

func _sortear_cores() -> void:
	if not ficha.has("variacao"):return
	var rng:=RandomNumberGenerator.new()
	rng.randomize()
	var paleta:Dictionary=Variacao.PALETAS[ficha.perfil]
	for categoria in Variacao.CATEGORIAS_COR:
		var opcoes:Array=paleta[categoria]
		ficha.variacao.cores[categoria]=Variacao._cor_variada(opcoes[rng.randi_range(0,opcoes.size()-1)],rng)
	_reaplicar_variedade()
	_sincronizar_variedade()

func _reaplicar_variedade() -> void:
	if visual!=null:Acessorios.aplicar(visual,ficha)

func _sincronizar_variedade() -> void:
	if _idade==null or not ficha.has("variacao"):return
	_sincronizando=true
	var v:Dictionary=ficha.variacao
	_idade.select(maxi(0,Variacao.IDADES.find(str(v.get("idade","adulto")))))
	_altura.set_value_no_signal(float(v.get("altura",1.0)))
	_corpulencia.set_value_no_signal(float(v.get("corpulencia",1.0)))
	for categoria in _cores:_cores[categoria].color=Color(str(v.cores.get(categoria,"ffffff")))
	for id in _acessorios:_acessorios[id].set_pressed_no_signal(id in v.get("acessorios",[]))
	_sincronizando=false

func _mudar_peca(indice: int,categoria: String) -> void:
	_seletores[categoria].select(indice)
	ficha.aparencia.roupas_3d[categoria]=Catalogo.MODELOS[categoria][indice].id
	# Conserva o mesmo corpo e rig enquanto troca só as peças.
	visual.mostrar(ficha.aparencia,ficha.aparencia.roupas_3d,_direcao)
	_reaplicar_variedade()

func _alternar_corpo() -> void:
	_corpo=not _corpo
	_aplicar_visibilidade()

func _aplicar_visibilidade() -> void:
	visual.heroi.pecas_visiveis=0 if _corpo else 15
	visual.pecas_armadura_npc=0 if _corpo else 15
	visual.heroi._armaduras.atualizar()

func _ajustar() -> void:
	if _grid==null:return
	_grid.columns=2 if size.x>=480 else 1
	_palco.custom_minimum_size=Vector2(150,clampf(size.y*.34,72,170) if _grid.columns==1 else 170)
	_ajustar_visual()

func _ajustar_visual() -> void:
	if visual==null:return
	var escala:=clampf(minf(_palco.size.x/100.0,_palco.size.y/64.0),1.0,5.0)
	visual.scale=Vector2.ONE*escala
	visual.position=Vector2(_palco.size.x/2,_palco.size.y*.85)

func _process(delta: float) -> void:
	_tempo+=delta
	if visual!=null:
		if _conversar:visual.pose_conversa(_direcao,_tempo)
		else:visual.pose_caminhada(_andar,_direcao,_tempo)

func _escolher_arquivo() -> void:
	var dialogo:=FileDialog.new()
	dialogo.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	dialogo.access=FileDialog.ACCESS_FILESYSTEM
	dialogo.filters=PackedStringArray(["*.json ; Ficha de NPC"])
	dialogo.current_file=ficha.id+".json"
	dialogo.file_selected.connect(func(caminho):
		_estado.text="Ficha salva." if Gerador.salvar(ficha,caminho)==OK else "Não foi possível salvar a ficha."
		dialogo.queue_free())
	dialogo.canceled.connect(dialogo.queue_free)
	add_child(dialogo)
	dialogo.popup_centered_ratio(.8)
