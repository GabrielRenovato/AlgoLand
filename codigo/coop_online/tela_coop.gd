extends CanvasLayer
const Conexao := preload("res://codigo/coop_online/conexao_coop.gd")
const Duelo := preload("res://codigo/duelo/conexao_duelo.gd")
const Parceiro := preload("res://codigo/coop_online/parceiro_coop.gd")
var acao_inicial := ""
var _lista_salas: VBoxContainer
var _atualizar_salas: Button
var sessao: Node
var _status: Label
var _codigo: LineEdit
var _criar: Button
var _entrar: Button
var _iniciar: Button
var _sair: Button
var _pausou := false
var _vagas: GridContainer
var _avatares: Array[Node] = []

func _ready() -> void:
	layer = 111
	process_mode = Node.PROCESS_MODE_ALWAYS
	sessao = Conexao.obter(get_tree())
	_pausou = not get_tree().paused
	if not sessao.ativo: get_tree().paused = true
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.03, 0.06, 0.94)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]: margem.add_theme_constant_override("margin_" + lado, 12)
	add_child(margem)
	var estrutura := VBoxContainer.new()
	estrutura.add_theme_constant_override("separation", 8)
	margem.add_child(estrutura)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	estrutura.add_child(rolagem)
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_theme_constant_override("separation", 8)
	rolagem.add_child(caixa)
	var titulo := _texto("COOP ONLINE DOS ANDARES", 18)
	caixa.add_child(titulo)
	caixa.add_child(_texto("Ate 4 jogadores por sala: quanto mais gente, mais inimigos e mais vida. Pode iniciar sozinho tambem.\nQuem cria a sala e o anfitriao; se ele sair, a sessao termina.", 12))
	_status = _texto("Crie uma sala ou informe o codigo de um amigo.", 13)
	caixa.add_child(_status)
	_codigo = LineEdit.new()
	_codigo.placeholder_text = "CODIGO DA SALA"
	_codigo.max_length = 12
	_codigo.custom_minimum_size.y = 34
	_codigo.add_theme_font_size_override("font_size", 13)
	for tipo in ["normal", "read_only", "focus"]:
		var estilo := _codigo.get_theme_stylebox(tipo).duplicate() as StyleBox
		estilo.content_margin_left = 10
		estilo.content_margin_right = 10
		estilo.content_margin_top = 8
		estilo.content_margin_bottom = 8
		_codigo.add_theme_stylebox_override(tipo, estilo)
	caixa.add_child(_codigo)
	_criar = _botao("CRIAR SALA", func():
		var j := Duelo.jogador_local(get_tree())
		if j != null: sessao.criar(j))
	caixa.add_child(_criar)
	_entrar = _botao("ENTRAR PELO CODIGO", func():
		var j := Duelo.jogador_local(get_tree())
		if j != null: sessao.entrar(j, _codigo.text))
	caixa.add_child(_entrar)
	_atualizar_salas = _botao("VER / ATUALIZAR SALAS", _listar)
	caixa.add_child(_atualizar_salas)
	_lista_salas = VBoxContainer.new()
	_lista_salas.add_theme_constant_override("separation", 8)
	caixa.add_child(_lista_salas)
	_vagas = GridContainer.new()
	_vagas.columns = 4 if get_viewport().get_visible_rect().size.x >= 640 else 2
	_vagas.add_theme_constant_override("h_separation", 6)
	_vagas.add_theme_constant_override("v_separation", 6)
	caixa.add_child(_vagas)
	_iniciar = _botao("INICIAR ANDARES", sessao.iniciar)
	caixa.add_child(_iniciar)
	_sair = _botao("SAIR DA SALA", func():
		if sessao.ativo: sessao._falhar("VOCE SAIU DO COOP")
		else: sessao.sair())
	caixa.add_child(_sair)
	estrutura.add_child(_botao("FECHAR", queue_free))
	sessao.salas_recebidas.connect(_mostrar_salas)
	sessao.mudou.connect(_atualizar)
	sessao.erro.connect(_ao_erro)
	_atualizar()
	if acao_inicial == "criar":
		_criar.pressed.emit()
	elif acao_inicial == "listar": _listar()

func _listar() -> void:
	var jogador := Duelo.jogador_local(get_tree())
	if jogador == null:
		_status.text = "ENTRE NA PARTIDA PARA VER AS SALAS"
		return
	_status.text = "BUSCANDO SALAS..."
	sessao.listar(jogador)

func _mostrar_salas(salas: Array) -> void:
	for filho in _lista_salas.get_children():
		_lista_salas.remove_child(filho)
		filho.queue_free()
	if not sessao.codigo.is_empty(): return
	_status.text = "NENHUMA SALA CRIADA. CRIE A SUA!" if salas.is_empty() else "ESCOLHA UMA SALA PARA ENTRAR"
	for sala in salas:
		if not sala is Dictionary: continue
		var ocupada := bool(sala.get("em_partida", false)) or int(sala.get("jogadores", 0)) >= int(sala.get("maximo", 4))
		var codigo_sala := str(sala.get("codigo", ""))
		var estado := "EM PARTIDA" if sala.get("em_partida", false) else ("CHEIA" if ocupada else "ENTRAR")
		var texto := "%s • ANDAR %d • %d/%d • %s" % [str(sala.get("anfitriao", "JOGADOR")), int(sala.get("andar", 1)), int(sala.get("jogadores", 1)), int(sala.get("maximo", 4)), estado]
		var botao := _botao(texto, func():
			var jogador := Duelo.jogador_local(get_tree())
			if jogador != null: sessao.entrar(jogador, codigo_sala))
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.custom_minimum_size.y = 48
		botao.disabled = ocupada
		_lista_salas.add_child(botao)

func _texto(conteudo: String, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = conteudo
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", Color("f7e5bd"))
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size.y = 34
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(acao)
	return b

func _atualizar() -> void:
	if sessao.ativo:
		queue_free()
		return
	var em_sala: bool = not sessao.codigo.is_empty()
	_atualizar_salas.visible = not em_sala
	_lista_salas.visible = not em_sala
	_criar.visible = not em_sala
	_entrar.visible = not em_sala
	_vagas.visible = em_sala
	_iniciar.visible = em_sala and sessao.sou_host()
	_iniciar.disabled = not sessao.todos_conectados()
	_iniciar.text = "INICIAR SOZINHO" if sessao.jogadores.size() <= 1 else "INICIAR ANDARES (%d JOGADORES)" % sessao.jogadores.size()
	_sair.visible = em_sala
	_codigo.editable = not em_sala
	if em_sala:
		_codigo.text = sessao.codigo
		_montar_vagas()
		if sessao.sou_host():
			_status.text = "SALA ABERTA. CHAME AMIGOS COM O CODIGO OU INICIE QUANDO QUISER" if sessao.jogadores.size() <= 1 else ("TODOS PRONTOS! INICIE QUANDO QUISER" if sessao.todos_conectados() else "CONECTANDO OS JOGADORES...")
		else:
			_status.text = "AGUARDANDO O ANFITRIAO INICIAR" if sessao.conectado else "CONECTANDO AO ANFITRIAO..."
	else:
		_status.text = "Crie uma sala ou informe o codigo de um amigo."

## Quatro vagas lado a lado, como no saguao do Grand Chase: personagem, nome e situacao de cada um.
func _montar_vagas() -> void:
	for filho in _vagas.get_children():
		_vagas.remove_child(filho)
		filho.queue_free()
	for i in Conexao.MAX_JOGADORES:
		_vagas.add_child(_vaga(i))

func _vaga(indice: int) -> Control:
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.08, 0.16, 0.95)
	estilo.border_color = Color(0.35, 0.28, 0.4)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.set_content_margin_all(6)
	painel.add_theme_stylebox_override("panel", estilo)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	painel.add_child(coluna)
	var cor: Color = Parceiro.CORES_VAGA[indice]
	coluna.add_child(_texto("JOGADOR %d" % (indice + 1), 9))
	if indice >= sessao.jogadores.size():
		estilo.border_color = Color(0.25, 0.2, 0.3)
		var vazio := Control.new()
		vazio.custom_minimum_size = Vector2(0, 110)
		coluna.add_child(vazio)
		var livre := _texto("VAGA ABERTA", 10)
		livre.modulate = Color(1, 1, 1, 0.5)
		livre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coluna.add_child(livre)
		return painel
	var jogador: Dictionary = sessao.jogadores[indice]
	var id := str(jogador.get("id", ""))
	var perfil: Dictionary = jogador.get("perfil", {}) if jogador.get("perfil") is Dictionary else {}
	estilo.border_color = cor
	estilo.set_border_width_all(2)
	var palco := Control.new()
	palco.custom_minimum_size = Vector2(0, 110)
	palco.clip_contents = true
	coluna.add_child(palco)
	var visual: Dictionary = perfil.get("visual", {}) if perfil.get("visual") is Dictionary else {}
	if not visual.is_empty():
		var avatar := preload("res://codigo/jogador/representacao_heroi_3d.gd").new()
		avatar.aparencia = preload("res://codigo/dados/visual_ranking.gd").normalizar(visual)
		palco.add_child(avatar)
		avatar.scale = Vector2.ONE * 2.2
		palco.resized.connect(func(): avatar.position = Vector2(palco.size.x / 2.0, 100))
	var nome := _texto(str(perfil.get("apelido", "JOGADOR")) + ("  (VOCE)" if id == sessao.eu else ""), 10)
	nome.add_theme_color_override("font_color", cor)
	coluna.add_child(nome)
	var dono: bool = id == str(sessao.dono)
	var situacao := "ANFITRIAO" if dono else ("PRONTO" if sessao.esta_conectado(id) else "CONECTANDO...")
	var rotulo := _texto(situacao, 9)
	rotulo.add_theme_color_override("font_color", Color("ffd966") if dono else (Color("8de08d") if sessao.esta_conectado(id) else Color("b8a98a")))
	coluna.add_child(rotulo)
	return painel

func _ao_erro(texto: String) -> void: _status.text = texto
func _exit_tree() -> void:
	if _pausou: get_tree().paused = false
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
