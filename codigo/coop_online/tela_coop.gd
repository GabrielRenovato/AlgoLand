extends CanvasLayer
## Saguão do coop online. Sem sala: criar, entrar pelo código e lista de salas abertas.
## Dentro da sala: quatro vagas lado a lado com o personagem de cada jogador, sem rolagem.
const Conexao := preload("res://codigo/coop_online/conexao_coop.gd")
const Duelo := preload("res://codigo/duelo/conexao_duelo.gd")
const Parceiro := preload("res://codigo/coop_online/parceiro_coop.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
## Mesmo acabamento do menu inicial e do de pausa: moldura de madeira, botões e campos de pergaminho.
const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const COR_TEXTO_ESCURO := Color("49321e")
const COR_SUAVE_ESCURA := Color("7a6648")
## Cores das vagas legíveis sobre o pergaminho.
const CORES_VAGA_ESCURAS: Array[Color] = [Color("2c5c9e"), Color("a8392f"), Color("2f7a36"), Color("8a6410")]
const COR_FUNDO := Color(0.17, 0.11, 0.10, 0.97)
const COR_BORDA := Color(0.55, 0.38, 0.24)
const COR_LINHA := Color(0.25, 0.17, 0.14)
const COR_PALCO := Color(0.12, 0.08, 0.08)
const COR_TEXTO := Color(0.97, 0.90, 0.76)
const COR_SUAVE := Color(0.78, 0.68, 0.55)
const COR_OURO := Color("ffd966")
const COR_PRONTO := Color("8de08d")
const COR_BOTAO := Color(0.34, 0.22, 0.16)
const COR_DESTAQUE := Color(0.27, 0.50, 0.24)
const INTERVALO_LISTA := 4.0

enum Vista { LISTA, SALA }
var acao_inicial := ""
var sessao: Node
var _vista := Vista.LISTA
var _pausou := false
var _corpo: Control
var _mensagem := ""
var _status: Label
var _codigo: LineEdit
var _lista_salas: VBoxContainer
var _vagas: GridContainer
var _ping: Label
var _iniciar: Button
var _assinatura := ""
var _tempo := 0.0
var _tempo_lista := 0.0
var _avatares: Array[Node2D] = []
var _pulsantes: Array[Control] = []

func _ready() -> void:
	layer = 111
	process_mode = Node.PROCESS_MODE_ALWAYS
	sessao = Conexao.obter(get_tree())
	_pausou = not get_tree().paused
	if not sessao.ativo: get_tree().paused = true
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]: painel.set("offset_" + lado, 8 if lado in ["left", "top"] else -8)
	EstiloInicio.painel(painel, false, 12, true)
	add_child(painel)
	_corpo = Control.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	painel.add_child(_corpo)
	sessao.salas_recebidas.connect(_mostrar_salas)
	sessao.mudou.connect(_atualizar)
	sessao.erro.connect(_ao_erro)
	_atualizar()
	if acao_inicial == "criar": _criar_sala()
	elif acao_inicial == "listar": _listar()

func _exit_tree() -> void:
	if _pausou: get_tree().paused = false

func _process(delta: float) -> void:
	_tempo += delta
	for avatar in _avatares:
		if is_instance_valid(avatar): avatar.pose(false, 0, _tempo)
	for no in _pulsantes:
		if is_instance_valid(no): no.modulate.a = 0.5 + 0.3 * sin(_tempo * 3.0)
	if _vista == Vista.SALA:
		if is_instance_valid(_ping): _ping.text = "PING %d MS" % sessao.ping_ms if sessao.ping_ms >= 0 else ""
		if is_instance_valid(_vagas): _vagas.columns = 4 if _largura() >= 420 else 2
	elif sessao.codigo.is_empty():
		_tempo_lista -= delta
		if _tempo_lista <= 0.0:
			_tempo_lista = INTERVALO_LISTA
			_listar(true)

func _largura() -> float:
	return get_viewport().get_visible_rect().size.x

# --- Ações

func _criar_sala() -> void:
	var j := Duelo.jogador_local(get_tree())
	if j != null: sessao.criar(j)
	else: _ao_erro("ENTRE NA PARTIDA PARA CRIAR UMA SALA")

func _entrar_pelo_codigo() -> void:
	var j := Duelo.jogador_local(get_tree())
	if j != null: sessao.entrar(j, _codigo.text)
	else: _ao_erro("ENTRE NA PARTIDA PARA ENTRAR EM UMA SALA")

func _listar(silencioso := false) -> void:
	var jogador := Duelo.jogador_local(get_tree())
	if jogador == null:
		if not silencioso: _ao_erro("ENTRE NA PARTIDA PARA VER AS SALAS")
		return
	if not silencioso: _definir_mensagem("BUSCANDO SALAS...")
	sessao.listar(jogador)

func _sair_da_sala() -> void:
	if sessao.ativo: sessao._falhar("VOCE SAIU DO COOP")
	else: sessao.sair()

func _ao_erro(texto: String) -> void: _definir_mensagem(texto)

func _definir_mensagem(texto: String) -> void:
	_mensagem = texto
	if is_instance_valid(_status): _status.text = texto

# --- Estrutura

func _atualizar() -> void:
	if sessao.ativo:
		queue_free()
		return
	if sessao.codigo.is_empty():
		if _vista != Vista.LISTA or _assinatura != "lista":
			_assinatura = "lista"
			_montar_lista()
		return
	# A sala só é refeita quando muda quem está nela ou o estado de alguém; o resto é texto.
	var assinatura := "%s|%s|%s" % [sessao.codigo, sessao.eu, ",".join(PackedStringArray(sessao.jogadores.map(func(j): return "%s:%s" % [str(j.get("id", "")), sessao.esta_conectado(str(j.get("id", "")))])))]
	if assinatura != _assinatura or _vista != Vista.SALA:
		_assinatura = assinatura
		_montar_sala()
	_atualizar_estado_sala()

func _limpar() -> void:
	_avatares.clear()
	_pulsantes.clear()
	_ping = null
	_iniciar = null
	_vagas = null
	_lista_salas = null
	_codigo = null
	for filho in _corpo.get_children():
		_corpo.remove_child(filho)
		filho.queue_free()

func _estrutura() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	_corpo.add_child(v)
	return v

# --- Vista: lista de salas

func _montar_lista() -> void:
	_vista = Vista.LISTA
	_limpar()
	var raiz := _estrutura()
	var estreito := _largura() < 420
	var corpo: BoxContainer = VBoxContainer.new() if estreito else HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(corpo)

	var esquerda := VBoxContainer.new()
	esquerda.add_theme_constant_override("separation", 6)
	if not estreito: esquerda.custom_minimum_size.x = 200
	corpo.add_child(esquerda)
	esquerda.add_child(_rotulo("COOP ONLINE", 16, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT))
	esquerda.add_child(_rotulo("Ate 4 jogadores por sala. Quanto mais gente, mais inimigos e mais vida. Pode comecar sozinho e deixar a sala aberta.", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
	esquerda.add_child(_botao("CRIAR SALA", _criar_sala, COR_DESTAQUE, Vector2(0, 32)))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	esquerda.add_child(linha)
	_codigo = LineEdit.new()
	_codigo.placeholder_text = "CODIGO"
	_codigo.max_length = 12
	_codigo.custom_minimum_size = Vector2(0, 28)
	_codigo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codigo.add_theme_font_override("font", FONTE)
	_codigo.add_theme_font_size_override("font_size", 10)
	EstiloInicio.campo(_codigo)
	_codigo.text_submitted.connect(func(_t): _entrar_pelo_codigo())
	linha.add_child(_codigo)
	linha.add_child(_botao("ENTRAR", _entrar_pelo_codigo, COR_BOTAO, Vector2(78, 30)))
	if not estreito:
		var folga := Control.new()
		folga.size_flags_vertical = Control.SIZE_EXPAND_FILL
		esquerda.add_child(folga)
	esquerda.add_child(_botao("FECHAR", queue_free, COR_LINHA, Vector2(0, 28)))

	var direita := VBoxContainer.new()
	direita.add_theme_constant_override("separation", 5)
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(direita)
	var cabecalho := HBoxContainer.new()
	direita.add_child(cabecalho)
	var titulo := _rotulo("SALAS ABERTAS", 11, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	cabecalho.add_child(_botao("ATUALIZAR", func(): _listar(), COR_BOTAO, Vector2(98, 26)))
	_status = _rotulo(_mensagem, 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT)
	direita.add_child(_status)
	var moldura := PanelContainer.new()
	moldura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moldura.custom_minimum_size.y = 80
	moldura.add_theme_stylebox_override("panel", _caixa(COR_PALCO, COR_LINHA, 3, 1))
	direita.add_child(moldura)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	moldura.add_child(rolagem)
	_lista_salas = VBoxContainer.new()
	_lista_salas.add_theme_constant_override("separation", 4)
	_lista_salas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista_salas)
	_tempo_lista = 0.0

func _mostrar_salas(salas: Array) -> void:
	if _vista != Vista.LISTA or not is_instance_valid(_lista_salas) or not sessao.codigo.is_empty(): return
	for filho in _lista_salas.get_children():
		_lista_salas.remove_child(filho)
		filho.queue_free()
	_definir_mensagem("")
	var validas := salas.filter(func(s): return s is Dictionary)
	if validas.is_empty():
		var vazio := _rotulo("NENHUMA SALA ABERTA\nCRIE A SUA E CHAME OS AMIGOS", 9, COR_SUAVE)
		vazio.custom_minimum_size.y = 70
		vazio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lista_salas.add_child(vazio)
		return
	for sala in validas: _lista_salas.add_child(_linha_sala(sala))

func _linha_sala(sala: Dictionary) -> Control:
	var maximo := int(sala.get("maximo", Conexao.MAX_JOGADORES))
	var jogadores := int(sala.get("jogadores", 1))
	var em_partida := bool(sala.get("em_partida", false))
	var cheia := jogadores >= maximo
	var codigo_sala := str(sala.get("codigo", ""))
	var painel := PanelContainer.new()
	_pergaminho(painel, 16.0, 8.0)
	if em_partida or cheia: painel.modulate = Color(0.8, 0.78, 0.74)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	painel.add_child(linha)
	var texto := VBoxContainer.new()
	texto.add_theme_constant_override("separation", 0)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(texto)
	var nome := _rotulo(str(sala.get("anfitriao", "JOGADOR")), 10, COR_TEXTO_ESCURO, HORIZONTAL_ALIGNMENT_LEFT)
	nome.autowrap_mode = TextServer.AUTOWRAP_OFF
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nome.clip_text = true
	texto.add_child(nome)
	texto.add_child(_rotulo("ANDAR %d" % int(sala.get("andar", 1)), 8, COR_SUAVE_ESCURA, HORIZONTAL_ALIGNMENT_LEFT))
	# Uma pastilha por vaga, na cor do jogador que a ocupa.
	var vagas := HBoxContainer.new()
	vagas.add_theme_constant_override("separation", 2)
	vagas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(vagas)
	for i in maximo:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(8, 12)
		var cor: Color = Parceiro.CORES_VAGA[clampi(i, 0, 3)]
		p.add_theme_stylebox_override("panel", _caixa(cor if i < jogadores else Color(0.12, 0.08, 0.08), cor.darkened(0.2) if i < jogadores else Color(0.4, 0.32, 0.28), 1, 1))
		vagas.add_child(p)
	var contagem := _rotulo("%d/%d" % [jogadores, maximo], 9, COR_SUAVE)
	contagem.custom_minimum_size.x = 24
	linha.add_child(contagem)
	if em_partida or cheia:
		var aviso := _rotulo("EM PARTIDA" if em_partida else "CHEIA", 8, Color("b8a98a"))
		aviso.custom_minimum_size.x = 60
		linha.add_child(aviso)
	else:
		linha.add_child(_botao("ENTRAR", func():
			var j := Duelo.jogador_local(get_tree())
			if j != null: sessao.entrar(j, codigo_sala), COR_DESTAQUE, Vector2(78, 26)))
	return painel

# --- Vista: sala

func _montar_sala() -> void:
	_vista = Vista.SALA
	_limpar()
	var raiz := _estrutura()
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation", 8)
	raiz.add_child(cabecalho)
	cabecalho.add_child(_linha_unica(_rotulo("SALA", 16, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT)))
	var chip := PanelContainer.new()
	_pergaminho(chip, 12.0, 6.0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecalho.add_child(chip)
	chip.add_child(_linha_unica(_rotulo(sessao.codigo, 9, COR_TEXTO_ESCURO)))
	var copiar := _botao("COPIAR", func(): pass, COR_BOTAO, Vector2(74, 26))
	copiar.pressed.connect(func():
		DisplayServer.clipboard_set(sessao.codigo)
		copiar.text = "COPIADO")
	cabecalho.add_child(copiar)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(espaco)
	_ping = _linha_unica(_rotulo("", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
	cabecalho.add_child(_ping)
	_status = _rotulo("", 9, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT)
	raiz.add_child(_status)
	_vagas = GridContainer.new()
	_vagas.columns = 4 if _largura() >= 420 else 2
	_vagas.add_theme_constant_override("h_separation", 6)
	_vagas.add_theme_constant_override("v_separation", 6)
	_vagas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(_vagas)
	for i in Conexao.MAX_JOGADORES: _vagas.add_child(_vaga(i))
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 8)
	raiz.add_child(rodape)
	rodape.add_child(_botao("SAIR DA SALA", _sair_da_sala, COR_LINHA, Vector2(96, 32)))
	if sessao.sou_host() and load("res://codigo/conta/cliente_conta.gd").obter(get_tree()).logado():
		rodape.add_child(_botao("CONVIDAR", func():
			var tela = load("res://codigo/conta/tela_amigos.gd").new()
			tela.convite = {"tipo": "coop", "sala": sessao.codigo, "andar": maxi(1, Progresso.onda_inicial)}
			get_tree().root.add_child(tela), COR_BOTAO, Vector2(74, 32)))
	var folga := Control.new()
	folga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(folga)
	if sessao.sou_host():
		_iniciar = _botao("INICIAR", sessao.iniciar, COR_DESTAQUE, Vector2(150, 32))
		_iniciar.add_theme_font_size_override("font_size", 11)
		_iniciar.clip_text = true
		rodape.add_child(_iniciar)
	else:
		var espera := _rotulo("AGUARDANDO O ANFITRIAO...", 9, COR_SUAVE, HORIZONTAL_ALIGNMENT_RIGHT)
		espera.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rodape.add_child(espera)
		_pulsantes.append(espera)

func _atualizar_estado_sala() -> void:
	var sozinho: bool = sessao.jogadores.size() <= 1
	if is_instance_valid(_iniciar):
		_iniciar.disabled = not sessao.todos_conectados()
		_iniciar.text = "INICIAR SOZINHO" if sozinho else "INICIAR (%d)" % sessao.jogadores.size()
	if not is_instance_valid(_status): return
	if not _mensagem.is_empty() and _mensagem != _status.text: _status.text = _mensagem
	elif sessao.sou_host():
		_status.text = "SALA ABERTA: PASSE O CODIGO AOS AMIGOS OU INICIE QUANDO QUISER" if sozinho else ("TODOS PRONTOS! INICIE QUANDO QUISER" if sessao.todos_conectados() else "CONECTANDO OS JOGADORES...")
	else:
		_status.text = "VOCE ENTROU NA SALA" if sessao.conectado else "CONECTANDO AO ANFITRIAO..."

func _vaga(indice: int) -> Control:
	var cor: Color = Parceiro.CORES_VAGA[indice]
	var ocupada: bool = indice < sessao.jogadores.size()
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pergaminho(painel, 14.0, 10.0)
	if not ocupada: painel.modulate = Color(0.85, 0.83, 0.8)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	painel.add_child(coluna)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var etiqueta := _rotulo("P%d" % (indice + 1), 9, CORES_VAGA_ESCURAS[indice] if ocupada else COR_SUAVE_ESCURA, HORIZONTAL_ALIGNMENT_LEFT)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(etiqueta)
	var palco := Panel.new()
	palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palco.custom_minimum_size = Vector2(0, 64)
	palco.clip_contents = true
	palco.add_theme_stylebox_override("panel", _caixa(COR_PALCO, COR_PALCO, 3, 0))
	coluna.add_child(palco)
	if not ocupada:
		var mais := _rotulo("+", 26, Color(COR_SUAVE, 0.7))
		mais.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mais.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		palco.add_child(mais)
		_pulsantes.append(mais)
		var livre := _rotulo("VAGA ABERTA", 9, COR_SUAVE_ESCURA)
		coluna.add_child(livre)
		coluna.add_child(_rotulo(" ", 8, COR_SUAVE_ESCURA))
		return painel
	var jogador: Dictionary = sessao.jogadores[indice]
	var id := str(jogador.get("id", ""))
	var perfil: Dictionary = jogador.get("perfil", {}) if jogador.get("perfil") is Dictionary else {}
	var dono: bool = id == str(sessao.dono)
	var visual: Dictionary = perfil.get("visual", {}) if perfil.get("visual") is Dictionary else {}
	if not visual.is_empty():
		var sombra := Polygon2D.new()
		sombra.color = Color(0, 0, 0, 0.35)
		var pontos := PackedVector2Array()
		for passo in 20: pontos.append(Vector2(cos(TAU * passo / 20.0) * 17.0, sin(TAU * passo / 20.0) * 5.0))
		sombra.polygon = pontos
		palco.add_child(sombra)
		var avatar := preload("res://codigo/jogador/representacao_heroi_3d.gd").new()
		avatar.aparencia = preload("res://codigo/dados/visual_ranking.gd").normalizar(visual)
		palco.add_child(avatar)
		_avatares.append(avatar)
		palco.resized.connect(func():
			var escala := clampf(palco.size.y / 46.0, 1.0, 3.2)
			avatar.scale = Vector2.ONE * escala
			avatar.position = Vector2(palco.size.x / 2.0, palco.size.y - 8.0)
			sombra.scale = Vector2.ONE * maxf(escala * 0.7, 1.0)
			sombra.position = avatar.position + Vector2(0, 1))
	var nome := _rotulo(str(perfil.get("apelido", "JOGADOR")), 10, CORES_VAGA_ESCURAS[indice], HORIZONTAL_ALIGNMENT_CENTER)
	nome.autowrap_mode = TextServer.AUTOWRAP_OFF
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nome.clip_text = true
	coluna.add_child(nome)
	var pronto: bool = sessao.esta_conectado(id)
	var situacao := "ANFITRIAO" if dono else ("PRONTO" if pronto else "CONECTANDO...")
	var rotulo := _rotulo(situacao + ("  •  VOCE" if id == sessao.eu else ""), 8, Color("8a5a00") if dono else (Color("2f7a36") if pronto else COR_SUAVE_ESCURA), HORIZONTAL_ALIGNMENT_CENTER)
	coluna.add_child(rotulo)
	if not pronto: _pulsantes.append(rotulo)
	return painel

# --- Componentes

## Pergaminho com respiro: a moldura desenhada ocupa ~8 px por lado, e o texto não pode encostar nela.
func _pergaminho(painel: PanelContainer, horizontal := 14.0, vertical := 8.0) -> void:
	EstiloInicio.painel(painel, true, horizontal)
	var margens := EstiloInicio.espaco(horizontal)
	margens.content_margin_top = vertical
	margens.content_margin_bottom = vertical
	painel.add_theme_stylebox_override("panel", margens)

func _caixa(fundo: Color, borda: Color, raio := 3, largura := 1, margem := 0) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fundo
	c.border_color = borda
	c.set_border_width_all(largura)
	c.set_corner_radius_all(raio)
	c.set_content_margin_all(margem)
	return c

func _rotulo(texto: String, tamanho: int, cor := COR_TEXTO, alinhamento := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = alinhamento
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo

## Texto de uma linha só, sem expandir: em cabeçalhos a quebra automática dobraria letra por letra.
func _linha_unica(rotulo: Label) -> Label:
	rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return rotulo

func _botao(texto: String, acao: Callable, cor := COR_BOTAO, minimo := Vector2(0, 30)) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = minimo
	b.clip_text = true
	# Botão principal (verde) = moldura escura do jogo; os demais, pergaminho.
	EstiloInicio.botao(b, cor == COR_DESTAQUE)
	b.pressed.connect(acao)
	return b

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
