extends CanvasLayer
## Saguão do duelo online: lista de salas, criar sala (nome e senha opcional), entrar e a sala com
## os dois lugares, "Pronto" e "Começar" (só o dono). Aberta pelo menu de pausa (Duelo.abrir_tela).
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const ConexaoDuelo := preload("res://codigo/duelo/conexao_duelo.gd")
@onready var Duelo: Node = ConexaoDuelo.obter(get_tree())
const COR_FUNDO := Color(0.17, 0.11, 0.10, 0.96)
const COR_BORDA := Color(0.55, 0.38, 0.24)
const COR_LINHA := Color(0.25, 0.17, 0.14)
const COR_TEXTO := Color(0.97, 0.90, 0.76)
const COR_SUAVE := Color(0.78, 0.68, 0.55)
const COR_PRONTO := Color(0.55, 0.85, 0.45)
const INTERVALO_LISTA := 2.5

enum Vista { LISTA, CRIAR, SENHA, SALA }
var _vista := Vista.LISTA
var _painel: PanelContainer
var _lugares: GridContainer
var _acoes: VBoxContainer
var _conteudo: VBoxContainer
var _status: Label
var _salas: Array = []
var _sala_senha := 0
var _tempo_lista := 0.0
var _pausou := false
var _campo_nome: LineEdit
var _campo_senha: LineEdit
var _rotulo_ping: Label
var _avatares: Array[Node2D] = []
var _tempo_pose := 0.0

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pausou = not get_tree().paused
	get_tree().paused = true
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_painel = PanelContainer.new()
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.offset_left = 8
	_painel.offset_top = 8
	_painel.offset_right = -8
	_painel.offset_bottom = -8
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(5)
	estilo.set_content_margin_all(8)
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	var estrutura := VBoxContainer.new()
	_painel.add_child(estrutura)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	estrutura.add_child(rolagem)
	_acoes = VBoxContainer.new()
	estrutura.add_child(_acoes)
	_conteudo = VBoxContainer.new()
	_conteudo.add_theme_constant_override("separation", 3)
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_conteudo)
	Duelo.salas_recebidas.connect(_ao_receber_salas)
	Duelo.sala_alterada.connect(_ao_sala)
	Duelo.saiu_da_sala.connect(func(): _mostrar(Vista.LISTA))
	Duelo.erro.connect(_ao_erro)
	Duelo.conexao_alterada.connect(func(_c): _atualizar_status())
	Duelo.round_comecou.connect(_ao_partida)
	var jogador: Node2D = Duelo.jogador_local(get_tree())
	if jogador != null: Duelo.conectar(jogador)
	_mostrar(Vista.SALA if not Duelo.sala.is_empty() else Vista.LISTA)
	Duelo.listar()

func _exit_tree() -> void:
	if _pausou: get_tree().paused = false

func _process(delta: float) -> void:
	if is_instance_valid(_lugares):
		_lugares.columns = 2 if get_viewport().get_visible_rect().size.x >= 400 else 1
	_tempo_pose += delta
	for avatar in _avatares:
		if is_instance_valid(avatar): avatar.pose(false, 0, _tempo_pose)
	if _rotulo_ping != null and is_instance_valid(_rotulo_ping):
		_rotulo_ping.visible = Duelo.ping_ms >= 0
		_rotulo_ping.text = "PING %d MS" % Duelo.ping_ms if Duelo.ping_ms >= 0 else ""
	if _vista != Vista.LISTA: return
	_tempo_lista -= delta
	if _tempo_lista <= 0.0:
		_tempo_lista = INTERVALO_LISTA
		Duelo.listar()

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match _vista:
			Vista.LISTA: _fechar()
			Vista.SALA: Duelo.sair_da_sala()
			_: _mostrar(Vista.LISTA)

# --- Vistas

func _mostrar(vista: Vista) -> void:
	_vista = vista
	_avatares.clear()
	for filho in _acoes.get_children():
		_acoes.remove_child(filho)
		filho.queue_free()
	for filho in _conteudo.get_children():
		_conteudo.remove_child(filho)
		filho.queue_free()
	_rotulo_ping = _rotulo("", 8, COR_SUAVE)
	_rotulo_ping.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_acoes.add_child(_rotulo_ping)
	match vista:
		Vista.LISTA: _montar_lista()
		Vista.CRIAR: _montar_criar()
		Vista.SENHA: _montar_senha()
		Vista.SALA: _montar_sala()

func _montar_lista() -> void:
	_conteudo.add_child(_rotulo("DUELO ONLINE", 16))
	_status = _rotulo("", 9, COR_SUAVE)
	_conteudo.add_child(_status)
	_atualizar_status()
	_conteudo.add_child(_rotulo("PvP 1 x 1 • MELHOR DE 3 ROUNDS", 10, COR_SUAVE))
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 130)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_conteudo.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.name = "Lista"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(lista)
	_preencher_lista()
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 8)
	var criar := _botao("CRIAR SALA", func(): _mostrar(Vista.CRIAR))
	botoes.add_child(criar)
	botoes.add_child(_botao("ATUALIZAR", Duelo.listar))
	botoes.add_child(_botao("FECHAR", _fechar))
	_acoes.add_child(botoes)
	criar.grab_focus.call_deferred()

func _preencher_lista() -> void:
	var lista := _conteudo.find_child("Lista", true, false)
	if lista == null: return
	for filho in lista.get_children(): filho.queue_free()
	if _salas.is_empty():
		lista.add_child(_rotulo("NENHUMA SALA ABERTA. CRIE UMA!", 10, COR_SUAVE))
		return
	for sala in _salas:
		var cheia := int(sala.jogadores) >= 2
		var em_jogo := str(sala.estado) == "jogo"
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		var titulo := _rotulo("#%d  %s%s\n%d/2 • %s" % [int(sala.id), str(sala.titulo), " (SENHA)" if sala.senha else "", int(sala.jogadores), "EM JOGO" if em_jogo else ("CHEIA" if cheia else "ESPERANDO")], 11)
		titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		linha.add_child(titulo)
		var entrar := _botao("ENTRAR", _entrar.bind(sala))
		entrar.disabled = cheia or em_jogo
		linha.add_child(entrar)
		lista.add_child(linha)

func _montar_criar() -> void:
	_conteudo.add_child(_rotulo("CRIAR SALA", 16))
	_campo_nome = _campo("NOME DA SALA", 24)
	_conteudo.add_child(_campo_nome)
	_campo_senha = _campo("SENHA (OPCIONAL)", 12)
	_campo_senha.secret = true
	_conteudo.add_child(_campo_senha)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 8)
	botoes.add_child(_botao("CRIAR", func(): Duelo.criar(_campo_nome.text.strip_edges(), _campo_senha.text)))
	botoes.add_child(_botao("VOLTAR", func(): _mostrar(Vista.LISTA)))
	_acoes.add_child(botoes)
	_campo_nome.grab_focus.call_deferred()

func _montar_senha() -> void:
	_conteudo.add_child(_rotulo("SALA COM SENHA", 16))
	_campo_senha = _campo("SENHA", 12)
	_campo_senha.secret = true
	_campo_senha.text_submitted.connect(func(_t): Duelo.entrar(_sala_senha, _campo_senha.text))
	_conteudo.add_child(_campo_senha)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 8)
	botoes.add_child(_botao("ENTRAR", func(): Duelo.entrar(_sala_senha, _campo_senha.text)))
	botoes.add_child(_botao("VOLTAR", func(): _mostrar(Vista.LISTA)))
	_acoes.add_child(botoes)
	_campo_senha.grab_focus.call_deferred()

func _montar_sala() -> void:
	var sala: Dictionary = Duelo.sala
	if sala.is_empty():
		_mostrar(Vista.LISTA)
		return
	_conteudo.add_child(_rotulo("SALA %d  -  %s%s" % [int(sala.id), str(sala.titulo), "  (SENHA)" if sala.senha else ""], 14))
	_status = _rotulo("", 9, COR_SUAVE)
	_conteudo.add_child(_status)
	var lugares := GridContainer.new()
	_lugares = lugares
	lugares.columns = 2 if get_viewport().get_visible_rect().size.x >= 400 else 1
	lugares.add_theme_constant_override("h_separation", 12)
	lugares.add_theme_constant_override("v_separation", 8)
	var jogadores: Array = sala.get("jogadores", [])
	for i in 2:
		lugares.add_child(_lugar(jogadores[i] if i < jogadores.size() else {}, sala))
	_conteudo.add_child(lugares)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 8)
	var principal: Button
	if Duelo.sou_dono():
		principal = _botao("COMECAR", Duelo.iniciar)
		var adversario: Dictionary = Duelo.adversario()
		principal.disabled = adversario.is_empty() or not bool(adversario.get("pronto", false))
		_status.text = "ESPERANDO ADVERSARIO" if adversario.is_empty() else ("TUDO PRONTO!" if not principal.disabled else "ESPERANDO O ADVERSARIO FICAR PRONTO")
	else:
		var eu_pronto := false
		for j in jogadores:
			if str(j.id) == Duelo.eu: eu_pronto = bool(j.pronto)
		principal = _botao("CANCELAR" if eu_pronto else "PRONTO", Duelo.marcar_pronto.bind(not eu_pronto))
		_status.text = "ESPERANDO O DONO COMECAR" if eu_pronto else "MARQUE PRONTO QUANDO QUISER LUTAR"
	botoes.add_child(principal)
	botoes.add_child(_botao("SAIR DA SALA", Duelo.sair_da_sala))
	if Duelo.sou_dono() and preload("res://codigo/conta/cliente_conta.gd").obter(get_tree()).logado():
		botoes.add_child(_botao("CONVIDAR", _convidar_amigo))
	_acoes.add_child(botoes)
	principal.grab_focus.call_deferred()

## Convida um amigo da conta para esta sala; o convite leva o número da sala e a senha (se houver).
func _convidar_amigo() -> void:
	var tela = preload("res://codigo/conta/tela_amigos.gd").new()
	tela.convite = {"tipo": "duelo", "sala": "%d|%s" % [int(Duelo.sala.get("id", 0)), Duelo.senha_da_sala], "andar": 1}
	get_tree().root.add_child(tela)

func _lugar(jogador: Dictionary, sala: Dictionary) -> PanelContainer:
	var caixa := PanelContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.size_flags_stretch_ratio = 1.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_LINHA
	estilo.border_color = COR_BORDA if not jogador.is_empty() else COR_LINHA.lightened(0.15)
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(6)
	caixa.add_theme_stylebox_override("panel", estilo)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	caixa.add_child(coluna)
	if jogador.is_empty():
		var vazio := _rotulo("?", 48, COR_SUAVE)
		vazio.custom_minimum_size.y = 112
		coluna.add_child(vazio)
		coluna.add_child(_rotulo("LUGAR LIVRE", 11, COR_SUAVE))
		coluna.add_child(_rotulo("AGUARDANDO ADVERSARIO...", 8, COR_SUAVE))
		return caixa
	var nome := str(jogador.get("apelido", "?")) + ("  (VOCE)" if str(jogador.id) == Duelo.eu else "")
	coluna.add_child(_rotulo(nome, 10))
	var dono := str(jogador.id) == str(sala.get("dono", ""))
	coluna.add_child(_rotulo("DONO DA SALA" if dono else ("PRONTO" if jogador.get("pronto", false) else "NAO ESTA PRONTO"), 8,
		COR_SUAVE if dono else (COR_PRONTO if jogador.get("pronto", false) else COR_SUAVE)))
	var perfil: Dictionary = jogador.get("perfil", {}) if jogador.get("perfil") is Dictionary else {}
	var visual: Dictionary = perfil.get("visual", {}) if perfil.get("visual") is Dictionary else {}
	if visual.is_empty():
		var legado = perfil.get("aparencia_raven", {})
		visual = legado.duplicate(true) if legado is Dictionary else {}
		visual.merge({"versao": 1, "roupas_3d": perfil.get("roupas_3d", {}), "escudo": perfil.get("escudo", false), "arma_mais_usada": perfil.get("arma", "")}, true)
	visual = preload("res://codigo/dados/visual_ranking.gd").normalizar(visual)
	var palco := Control.new()
	palco.custom_minimum_size = Vector2(152, 110)
	palco.clip_contents = true
	coluna.add_child(palco)
	var avatar := preload("res://codigo/jogador/representacao_heroi_3d.gd").new()
	avatar.aparencia = visual
	palco.add_child(avatar)
	avatar.scale = Vector2.ONE * 2.4
	palco.resized.connect(func(): avatar.position = Vector2(palco.size.x / 2.0, 96))
	_avatares.append(avatar)
	var detalhe := _rotulo("TOQUE NOS EQUIPAMENTOS", 9, COR_SUAVE)
	detalhe.custom_minimum_size.y = 20
	coluna.add_child(detalhe)
	var itens: Dictionary = visual.get("equipamentos", {}).duplicate()
	itens["arma"] = visual.get("arma_mais_usada", "")
	itens["escudo"] = "escudo_basico" if visual.get("escudo", false) else ""
	for indice in 6:
		var slot: String = ["cabeca", "corpo", "luvas", "botas", "arma", "escudo"][indice]
		var tipo := str(itens.get(slot, ""))
		var item: DadosItem = null
		if not tipo.is_empty():
			item = DadosItem.new()
			item.tipo = tipo
			item.categoria = slot
			var dados = perfil.get("equipamentos", {})
			var extras = dados.get(slot, {}) if dados is Dictionary else {}
			if extras is Dictionary:
				var nivel = extras.get("nivel", 1)
				item.nivel = clampi(int(nivel), 1, 99) if nivel is float or nivel is int else 1
				var raridade = extras.get("raridade", "comum")
				item.raridade = raridade if raridade in preload("res://codigo/dados/raridades.gd").ORDEM else "comum"
		var casa := _slot_equipamento(slot, item, detalhe)
		palco.add_child(casa)
		var esquerda := indice < 4
		var linha := indice if esquerda else indice - 4
		casa.position = Vector2(0 if esquerda else palco.size.x - 26, linha * 28)
		palco.resized.connect(func(): casa.position.x = 0 if esquerda else palco.size.x - 26)
	return caixa

## A aparência é a mesma da mochila, mas a inspeção nunca equipa, arrasta ou grava itens.
func _slot_equipamento(categoria: String, item: DadosItem, detalhe: Label) -> Control:
	var botao := Button.new()
	botao.name = "Equipamento_" + categoria
	botao.custom_minimum_size = Vector2(26, 26)
	botao.size = Vector2(26, 26)
	var casa = preload("res://cenas/ui/componentes/slot_ui.tscn").instantiate()
	casa.item_atual = item
	var regioes := {"arma": Vector2(162, 50), "cabeca": Vector2(194, 50), "corpo": Vector2(210, 66), "luvas": Vector2(194, 82), "botas": Vector2(194, 98), "escudo": Vector2(162, 98)}
	var icone := AtlasTexture.new()
	icone.atlas = preload("res://assets/ui/Cute RPG - Icons (1)/Cute RPG - Icons/16x16/CuteRPG_Icons06.png")
	icone.region = Rect2(regioes[categoria], Vector2(12, 12))
	casa.icone_vazio = icone
	casa.scale = Vector2.ONE * 1.3
	botao.add_child(casa)
	casa.ready.connect(func():
		casa.aplicar_acabamento_detalhado()
		_sem_interacao(casa))
	var descricao := categoria.to_upper() + ": VAZIO"
	if item != null: descricao = "%s • NV %d • %s" % [item.nome(), item.nivel, item.nome_raridade()]
	botao.tooltip_text = descricao
	botao.pressed.connect(func(): detalhe.text = descricao)
	botao.focus_entered.connect(func(): detalhe.text = descricao)
	return botao

func _sem_interacao(no: Node) -> void:
	if no is Control:
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no.focus_mode = Control.FOCUS_NONE
	for filho in no.get_children(): _sem_interacao(filho)

# --- Eventos

func _entrar(sala: Dictionary) -> void:
	if sala.senha:
		_sala_senha = int(sala.id)
		_mostrar(Vista.SENHA)
	else:
		Duelo.entrar(int(sala.id))

func _ao_receber_salas(salas: Array) -> void:
	_salas = salas
	if _vista == Vista.LISTA: _preencher_lista()

func _ao_sala(_sala: Dictionary) -> void:
	_mostrar(Vista.SALA)

func _ao_erro(codigo: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = Duelo.texto_erro(codigo)
		_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

func _ao_partida(_dados: Dictionary) -> void:
	# A partida começou: a conexão leva os dois para a arena (conexao_duelo.gd).
	queue_free()

func _atualizar_status() -> void:
	if _status == null or not is_instance_valid(_status): return
	_status.remove_theme_color_override("font_color")
	if Duelo.endereco().is_empty(): _status.text = Duelo.texto_erro("sem_servidor")
	elif Duelo.conectado(): _status.text = "CONECTADO - ESCOLHA UMA SALA OU CRIE A SUA"
	else: _status.text = "CONECTANDO..."

func _fechar() -> void:
	if Duelo.sala.is_empty(): Duelo.desconectar()
	queue_free()

# --- Peças de interface

func _rotulo(texto: String, tamanho: int, cor := COR_TEXTO) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.add_theme_font_override("font", FONTE)
	botao.add_theme_font_size_override("font_size", 10)
	botao.custom_minimum_size = Vector2(76, 34)
	botao.pressed.connect(acao)
	return botao

func _campo(dica: String, maximo: int) -> LineEdit:
	var campo := LineEdit.new()
	campo.placeholder_text = dica
	campo.max_length = maximo
	campo.add_theme_font_override("font", FONTE)
	campo.add_theme_font_size_override("font_size", 11)
	campo.custom_minimum_size = Vector2(0, 34)
	return campo
