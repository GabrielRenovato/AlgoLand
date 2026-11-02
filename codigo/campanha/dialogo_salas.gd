extends CanvasLayer

## Preparação regional e sala com quatro aventureiros, sem executar personagens de jogo.
signal solo
const Sessao := preload("res://codigo/campanha/sessao_expedicao.gd")
const Estilo := preload("res://codigo/ui/estilo_campanha.gd")
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Avatar := preload("res://codigo/jogador/representacao_heroi_3d.gd")
const POSICOES := {"chegada":Vector2(.19,.82),"estrada":Vector2(.28,.61),"vila":Vector2(.35,.52),"pomar":Vector2(.16,.5)}
var regiao := "chegada"
var nome_regiao := ""
var sessao: Node
var painel: PanelContainer
var lista: VBoxContainer
var estado: Label
var atualizar: Button
var criar: Button
var iniciar: Button
var vagas: GridContainer
var corpo: BoxContainer
var informacoes: VBoxContainer
var conteudo: VBoxContainer
var acoes: GridContainer
var entrada_chat: LineEdit
var historico_chat: RichTextLabel
var _chat: VBoxContainer
var _rolagem_corpo: ScrollContainer
var _salas: Array = []
var _avatares: Array[Node2D] = []
var _tempo := 0.0
var _montado := false
var _na_sala := false
var _mensagens: Array[String] = []

func _ready() -> void:
	layer=100
	if sessao==null:sessao=Sessao.obter_expedicao(get_tree())
	var fundo:=ColorRect.new()
	fundo.color=Color(.015,.025,.02,.87)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	painel=PanelContainer.new();painel.name="PreparacaoExpedicao"
	Estilo.painel(painel,false,12,true);fundo.add_child(painel)
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",6);painel.add_child(coluna)
	var titulo := _texto("Preparar expedição",14)
	titulo.add_theme_font_override("font",Estilo.FONTE_TITULO)
	var cabecalho := HBoxContainer.new();cabecalho.add_theme_constant_override("separation",8)
	cabecalho.add_child(Estilo.brasao(Vector2(22,25)));cabecalho.add_child(titulo);coluna.add_child(cabecalho)
	var rolagem:=ScrollContainer.new();rolagem.name="CorpoRolavel"
	_rolagem_corpo=rolagem
	rolagem.resized.connect(func():_dimensionar.call_deferred())
	rolagem.size_flags_vertical=Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	corpo=BoxContainer.new();corpo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	corpo.size_flags_vertical=Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation",8);rolagem.add_child(corpo)
	informacoes=VBoxContainer.new();informacoes.add_theme_constant_override("separation",5)
	conteudo=VBoxContainer.new();conteudo.add_theme_constant_override("separation",5)
	conteudo.size_flags_horizontal=Control.SIZE_EXPAND_FILL;conteudo.size_flags_vertical=Control.SIZE_EXPAND_FILL
	corpo.add_child(informacoes);corpo.add_child(conteudo)
	_chat=VBoxContainer.new();coluna.add_child(_chat)
	estado=_texto("Consultando salas…",8);estado.name="EstadoSala";coluna.add_child(estado)
	acoes=GridContainer.new();acoes.columns=3
	acoes.add_theme_constant_override("h_separation",6);acoes.add_theme_constant_override("v_separation",4);coluna.add_child(acoes)
	sessao.salas_recebidas.connect(_receber_salas)
	sessao.mudou.connect(_atualizar)
	sessao.erro.connect(_erro)
	sessao.mensagem_sala.connect(_mensagem_chat)
	fundo.resized.connect(_dimensionar)
	_montado=true
	_atualizar();_listar()

func _process(delta: float) -> void:
	_tempo+=delta
	for avatar in _avatares:
		if is_instance_valid(avatar):avatar.pose(false,0,_tempo)

func _texto(texto: String,tamanho: int,claro:=false) -> Label:
	var no:=Label.new();no.text=texto
	no.add_theme_font_override("font",Estilo.FONTE);no.add_theme_font_size_override("font_size",tamanho)
	no.add_theme_color_override("font_color",Estilo.VERDE if claro else Estilo.TINTA)
	no.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	no.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return no

func _botao(texto: String,acao: Callable,pai: Node,principal:=false) -> Button:
	var no:=Button.new();no.text=texto
	no.size_flags_horizontal=Control.SIZE_EXPAND_FILL;no.custom_minimum_size.y=25
	Estilo.botao(no,principal);no.pressed.connect(acao);pai.add_child(no)
	return no

func _limpar(no: Node) -> void:
	for filho in no.get_children():no.remove_child(filho);filho.queue_free()

func _dimensionar() -> void:
	if not _montado or not is_inside_tree():return
	var tamanho:=get_viewport().get_visible_rect().size
	var compacto:=tamanho.x<480
	corpo.vertical=compacto
	informacoes.custom_minimum_size.x=0 if compacto else 164
	informacoes.size_flags_horizontal=Control.SIZE_EXPAND_FILL if compacto else Control.SIZE_FILL
	corpo.move_child(conteudo,0 if _na_sala else 1)
	conteudo.size_flags_vertical=Control.SIZE_SHRINK_BEGIN if _na_sala else Control.SIZE_EXPAND_FILL
	conteudo.custom_minimum_size.y=maxf(150,_rolagem_corpo.size.y) if _na_sala else 0
	acoes.columns=1 if compacto else 3
	if is_instance_valid(vagas):vagas.columns=4 if tamanho.x>=700 else 2
	painel.custom_minimum_size=Vector2.ZERO
	painel.size=Vector2(minf(920,tamanho.x-16),minf(600,tamanho.y-12))
	painel.position=(tamanho-painel.size)/2

func _listar() -> void:
	if not sessao.codigo.is_empty():return
	estado.text="Consultando salas…";sessao.solicitar("listar",regiao)

func _receber_salas(salas: Array) -> void:
	_salas=salas.filter(func(s):return s.get("campanha")==Sessao.CAMPANHA and s.get("regiao")==regiao)
	_atualizar()

func _montar_informacoes() -> void:
	var dados: Dictionary=preload("res://codigo/campanha/catalogo_campanha.gd").dados().destinos[regiao]
	var quadro:=PanelContainer.new();Estilo.painel(quadro,true,10);informacoes.add_child(quadro)
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",5);quadro.add_child(coluna)
	var imagem:=TextureRect.new();imagem.name="RetratoEstagio"
	var recorte:=AtlasTexture.new();recorte.atlas=preload("res://assets/ui/campanha/mapa_primeira_raiz_cartoon.png")
	var centro: Vector2=POSICOES.get(regiao,Vector2(.35,.5))*Vector2(1536,1024)
	recorte.region=Rect2((centro-Vector2(160,100)).clamp(Vector2.ZERO,Vector2(1216,824)),Vector2(320,200))
	imagem.texture=recorte;imagem.custom_minimum_size.y=38
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	coluna.add_child(imagem);coluna.add_child(_texto(nome_regiao,11,true))
	coluna.add_child(_texto("1–4 aventureiros • padrão",8,true))
	var duracao: String="Encontro e serviços" if dados.tipo=="cidade" else "%d–%d min previstos" % [dados.duracao.prevista[0]/60,dados.duracao.prevista[1]/60]
	coluna.add_child(_texto(duracao,8,true))
	var objetivos := {"chegada":"Encontre os equipamentos.\nResista aos rebentos.\nDerrote o Cerne Partido.","estrada":"Siga os rastros do carreto e encontre os refugiados.","vila":"Conheça os moradores e prepare a próxima expedição.","pomar":"Investigue os sulcos e repare a cerca do pomar."}
	informacoes.add_child(_texto("Objetivos do estágio",10))
	informacoes.add_child(_texto(objetivos.get(regiao,"Explore a região com seu grupo."),9))
	if _na_sala:
		informacoes.add_child(_texto("Sala "+sessao.codigo,10))
		_botao("Copiar código",func():DisplayServer.clipboard_set(sessao.codigo);estado.text="Código da sala copiado.",informacoes)

func _atualizar() -> void:
	if not _montado:return
	_na_sala=not sessao.codigo.is_empty();_avatares.clear()
	_limpar(informacoes);_limpar(conteudo);_limpar(acoes);_limpar(_chat)
	_chat.visible=_na_sala
	_montar_informacoes()
	if _na_sala:_montar_sala()
	else:_montar_lista()
	_dimensionar();_dimensionar.call_deferred()

func _montar_lista() -> void:
	conteudo.add_child(_texto("Expedições abertas",11))
	var rolagem:=ScrollContainer.new();rolagem.custom_minimum_size.y=98
	rolagem.size_flags_vertical=Control.SIZE_EXPAND_FILL;rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	conteudo.add_child(rolagem)
	lista=VBoxContainer.new();lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation",5);rolagem.add_child(lista)
	if _salas.is_empty():lista.add_child(_texto("Nenhuma expedição aberta\n\nSeja o primeiro a reunir um grupo para este estágio.",10))
	for sala in _salas:
		var codigo:=str(sala.codigo)
		var titulo: String=str(sala.anfitriao).left(24)
		var botao:=_botao("%s  •  %d/%d%s" % [titulo,int(sala.jogadores),int(sala.maximo)," • em jogo" if sala.em_partida else ""],func():sessao.solicitar("entrar",regiao,codigo),lista)
		botao.clip_text=true;botao.tooltip_text="Sala de "+titulo+" • "+codigo
		botao.disabled=sala.em_partida or int(sala.jogadores)>=int(sala.maximo)
	var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",6);conteudo.add_child(linha)
	atualizar=_botao("Atualizar",_listar,linha)
	var rapido:=_botao("Entrar rápido",_entrar_rapido,linha)
	rapido.disabled=not _salas.any(func(s):return not s.em_partida and int(s.jogadores)<int(s.maximo))
	criar=_botao("Criar sala",func():sessao.solicitar("criar",regiao),acoes,true)
	_botao("Jogar só",jogar_solo,acoes);_botao("Voltar",fechar,acoes)
	estado.text="%d sala(s) • progresso e mochila pessoais" % _salas.size()

func _montar_sala() -> void:
	conteudo.add_child(_texto("Seu grupo • %d/4 aventureiros" % sessao.jogadores.size(),11))
	vagas=GridContainer.new();vagas.name="VagasExpedicao";vagas.columns=2
	vagas.add_theme_constant_override("h_separation",6);vagas.add_theme_constant_override("v_separation",6)
	vagas.size_flags_vertical=Control.SIZE_EXPAND_FILL;conteudo.add_child(vagas)
	for i in 4:vagas.add_child(_vaga(i))
	_montar_chat()
	iniciar=_botao("Iniciar expedição" if sessao.sou_host() else "Aguardando anfitrião",func():sessao.iniciar(),acoes,true)
	iniciar.disabled=not sessao.sou_host() or not sessao.todos_conectados()
	_botao("Copiar convite",func():DisplayServer.clipboard_set(sessao.codigo);estado.text="Código copiado. Compartilhe com seus amigos.",acoes)
	_botao("Sair da sala",fechar,acoes)
	estado.text="Grupo pronto. O anfitrião pode iniciar." if sessao.todos_conectados() else "Conectando aventureiros…"

func _vaga(indice: int) -> Control:
	var cartao:=PanelContainer.new();Estilo.painel(cartao,true,9)
	cartao.name="Vaga%d" % (indice+1);cartao.custom_minimum_size=Vector2(0,65)
	cartao.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cartao.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",2);cartao.add_child(coluna)
	if indice>=sessao.jogadores.size():
		coluna.add_child(_texto("Vaga aberta",9,true))
		var mais:=_texto("+",23,true);mais.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		mais.size_flags_vertical=Control.SIZE_EXPAND_FILL;mais.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;coluna.add_child(mais)
		coluna.add_child(_texto("Aguardando aventureiro",7,true))
		return cartao
	var jogador: Dictionary=sessao.jogadores[indice]
	var id:=str(jogador.id)
	var perfil: Dictionary=jogador.get("perfil",{})
	var nome:=_texto(str(perfil.get("apelido","Aventureiro")).left(24),9,true)
	nome.autowrap_mode=TextServer.AUTOWRAP_OFF;nome.clip_text=true;nome.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;coluna.add_child(nome)
	var palco:=Control.new();palco.name="PalcoPersonagem";palco.clip_contents=true
	palco.custom_minimum_size.y=23;palco.size_flags_vertical=Control.SIZE_EXPAND_FILL;coluna.add_child(palco)
	var avatar:=Avatar.new();avatar.aparencia=Visual.normalizar(perfil.get("visual",{"versao":1}))
	palco.add_child(avatar);_avatares.append(avatar)
	var ajustar:=func():
		if not is_instance_valid(avatar):return
		var desenho: Rect2=avatar.get_meta("limites_desenho",Rect2(-12,-32,24,36))
		var escala:=clampf(minf((palco.size.y-6)/maxf(desenho.size.y,1),(palco.size.x-8)/maxf(desenho.size.x,1)),.4,4.0)
		avatar.scale=Vector2.ONE*escala;avatar.position=palco.size/2-desenho.get_center()*escala
	palco.resized.connect(ajustar);ajustar.call_deferred()
	avatar.renderizado.connect(func():_medir_avatar(avatar);ajustar.call(),CONNECT_ONE_SHOT)
	var situacao: String="Líder do grupo" if id==sessao.dono else ("Pronto" if sessao.esta_conectado(id) else "Conectando…")
	if id==sessao.eu:situacao+=" • você"
	coluna.add_child(_texto(situacao,7,true))
	return cartao

func _montar_chat() -> void:
	var caixa:=VBoxContainer.new();caixa.add_theme_constant_override("separation",3);_chat.add_child(caixa)
	historico_chat=RichTextLabel.new();historico_chat.name="ConversaSala"
	historico_chat.custom_minimum_size.y=20;historico_chat.bbcode_enabled=false;historico_chat.scroll_following=true
	historico_chat.add_theme_color_override("default_color",Estilo.TINTA)
	historico_chat.add_theme_font_override("normal_font",Estilo.FONTE);historico_chat.add_theme_font_size_override("normal_font_size",8)
	historico_chat.text="Conversa do grupo\n"+"\n".join(_mensagens);caixa.add_child(historico_chat)
	var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",4);caixa.add_child(linha)
	entrada_chat=LineEdit.new();entrada_chat.placeholder_text="Converse com o grupo…";entrada_chat.max_length=180
	entrada_chat.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	entrada_chat.add_theme_font_size_override("font_size",8);entrada_chat.custom_minimum_size.y=23
	Estilo.campo(entrada_chat)
	linha.add_child(entrada_chat);entrada_chat.text_submitted.connect(func(_mensagem):_enviar_chat())
	var enviar:=_botao("Enviar",_enviar_chat,linha)
	enviar.size_flags_horizontal=Control.SIZE_FILL;enviar.custom_minimum_size.x=52

func _medir_avatar(avatar: Node2D) -> void:
	var limites:=Rect2()
	for sprite in avatar.find_children("*","Sprite2D",true,false):
		if sprite.texture==null or not sprite.is_visible_in_tree():continue
		var imagem: Image=sprite.texture.get_image()
		if imagem==null or imagem.is_empty():continue
		var quadro:=Vector2i(imagem.get_size()/Vector2i(sprite.hframes,sprite.vframes))
		var origem:=Vector2i(sprite.frame%sprite.hframes,sprite.frame/sprite.hframes)*quadro
		if sprite.region_enabled:
			origem=Vector2i(sprite.region_rect.position);quadro=Vector2i(sprite.region_rect.size)
		var pixels: Rect2=imagem.get_region(Rect2i(origem,quadro)).get_used_rect()
		if not pixels.has_area():continue
		var local:=Rect2(sprite.get_rect().position+pixels.position,pixels.size)
		var relativo: Transform2D=avatar.global_transform.affine_inverse()*sprite.global_transform
		var area: Rect2=relativo*local
		limites=area if not limites.has_area() else limites.merge(area)
	if limites.has_area():avatar.set_meta("limites_desenho",limites)

func _enviar_chat() -> void:
	if sessao.enviar_chat(entrada_chat.text):entrada_chat.clear()

func _mensagem_chat(autor: String,texto: String) -> void:
	_mensagens.append(autor+": "+texto)
	while _mensagens.size()>30:_mensagens.pop_front()
	if is_instance_valid(historico_chat):historico_chat.text="\n".join(_mensagens)

func _entrar_rapido() -> void:
	for sala in _salas:
		if not sala.em_partida and int(sala.jogadores)<int(sala.maximo):sessao.solicitar("entrar",regiao,str(sala.codigo));return

func _erro(texto: String) -> void:estado.text=texto
func jogar_solo() -> void:
	sessao.sair();solo.emit();queue_free()
func fechar() -> void:
	sessao.sair();queue_free()
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		fechar();get_viewport().set_input_as_handled()
