extends CanvasLayer

const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const ControlesToque := preload("res://codigo/ui/controles_toque.gd")
const TelaCidade := preload("res://codigo/cidade/tela_cidade.gd")
const DialogoIntroducao := preload("res://codigo/introducao/dialogo_introducao.gd")
const DialogoCidade := preload("res://codigo/cidade/dialogo_cidade.gd")
const TelaBau := preload("res://codigo/ui/tela_bau.gd")
const DURACAO_ENTRADA := 0.15
# Como no Diablo: a loja abre na esquerda e o inventário junto na direita, para arrastar itens entre os dois
const TELAS_ACOMPANHANTES := {"mercante": ["inventario"], "bau": ["inventario"]}
# Ações de jogo que dividem botão com os menus (B fecha a tela e também rola; A confirma e também interage: soltas ao
# fechar, senão o A que fechou a conversa já abriria outra)
const ACOES_DO_JOGADOR := ["rolar", "attack", "open_menu"]
# Telas no centro da tela: em vez de deslizar de uma borda, aparecem com fade
const TELAS_CENTRAIS := ["fim_partida", "dormir", "pausa", "conversa_cidade", "mural_cidade", "desafio_arena", "introducao", "guia_pesca"]
# Só se fecha pelo próprio botão (B/Esc e o atalho do inventário são ignorados)
const TELAS_OBRIGATORIAS := ["fim_partida", "introducao"]
# Telas coladas na lateral direita da tela, onde o X de fechar fica no canto
const LATERAIS_DA_DIREITA := ["inventario", "caldeirao", "acampamento", "mistica"]

var _telas_abertas: Array[String] = []

@onready var _telas: Dictionary = {
	"inventario": $TelaInventario,
	"mercante": $TelaMercante,
	"acampamento": $TelaAcampamento,
	"mistica": $TelaMistica,
	"fim_partida": $TelaFimPartida,
	"dormir": $TelaDormir,
	"caldeirao": $TelaCaldeirao,
	"pausa": $TelaPausa,
}
@onready var _paineis: Dictionary = {
	"inventario": $TelaInventario/Sidebar,
	"mercante": $TelaMercante/Painel,
	"acampamento": $TelaAcampamento/Painel,
	"mistica": $TelaMistica/Painel,
	"fim_partida": $TelaFimPartida/Centro/Painel,
	"dormir": $TelaDormir/Centro/Painel,
	"caldeirao": $TelaCaldeirao/Painel,
	"pausa": $TelaPausa/Centro/Painel,
}

func _ready() -> void:
	Introducao.preparar_cena(get_parent())
	var introducao := DialogoIntroducao.new()
	introducao.name = "DialogoIntroducao"
	add_child(introducao)
	_telas["introducao"] = introducao
	_paineis["introducao"] = introducao.painel
	var bau := TelaBau.new()
	bau.name = "TelaBau"
	add_child(bau)
	_telas["bau"] = bau
	_paineis["bau"] = bau.painel
	var guia_pesca := preload("res://codigo/pesca/guia_pesca.gd").new()
	guia_pesca.name = "GuiaPesca"
	add_child(guia_pesca)
	_telas["guia_pesca"] = guia_pesca
	_paineis["guia_pesca"] = guia_pesca.painel
	for nome in ["conversa_cidade", "mural_cidade", "desafio_arena"]:
		var tela: Control = DialogoCidade.new() if nome == "conversa_cidade" else TelaCidade.new()
		tela.name = nome.to_pascal_case()
		tela.modo_mural = nome == "mural_cidade"
		tela.modo_desafio = nome == "desafio_arena"
		add_child(tela)
		_telas[nome] = tela
		_paineis[nome] = tela.painel
	# A pausa para o jogo (get_tree().paused): a Interface precisa continuar recebendo Esc/B para fechá-la
	process_mode = Node.PROCESS_MODE_ALWAYS
	for tela in _telas.values():
		tela.visible = false
	add_to_group("interface")
	# A interface do jogador 2 (metade dele no cooperativo) só abre o que for pedido a ela (EventosJogo.abrir_tela_de/para);
	# os pedidos globais são do jogador 1
	if not EventosJogo.eh_do_p2(self):
		EventosJogo.abrir_tela.connect(_abrir_tela)
		EventosJogo.fechar_tela.connect(_fechar_tela)
	Controle.modo_alterado.connect(_ao_modo_controle)
	# Celular: joystick e botões na tela (somem enquanto uma tela está aberta)
	if Controle.usando_toque:
		# No coop o toque pertence ao P1; o parceiro usa o próprio controle.
		if not EventosJogo.eh_do_p2(self):
			add_child(ControlesToque.new())
		_ajustar_botoes_de_fechar_para_toque()

## Celular: o X das telas é de 10 unidades (pequeno para o dedo) e, nas laterais da direita (mochila, caldeirão), fica colado no canto
## da tela. O X passa para o lado esquerdo do título, cresce um pouco e ganha uma área de toque maior (um botão transparente de 56x16 por
## cima, na altura da faixa do título para não cobrir os itens que vêm logo abaixo)
const AREA_TOQUE_FECHAR := Vector2(56, 16)
## Quanto o X cresce em cada lado (10 -> 12 unidades)
const CRESCER_X := 1.0

func _ajustar_botoes_de_fechar_para_toque() -> void:
	for nome in _telas:
		for botao: TextureButton in _telas[nome].find_children("BotaoFechar", "TextureButton", true, false):
			var no_canto_direito: bool = botao.anchor_left >= 1.0 and nome in LATERAIS_DA_DIREITA
			var area := Button.new()
			area.name = "AreaFechar"
			area.flat = true
			area.focus_mode = Control.FOCUS_NONE
			for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
				area.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
			area.set_meta(Sons.META_SOM_PROPRIO, true)
			area.pressed.connect(_fechar_tela.bind(nome))
			area.anchor_top = 0.0
			area.anchor_bottom = 0.0
			area.offset_top = 0.0
			area.offset_bottom = AREA_TOQUE_FECHAR.y
			botao.offset_top -= CRESCER_X
			botao.offset_bottom += CRESCER_X
			if no_canto_direito:
				# O X vai para a esquerda do título
				var largura := botao.offset_right - botao.offset_left
				botao.anchor_left = 0.0
				botao.anchor_right = 0.0
				# Bem junto da borda: o título da mochila (centrado) começa em x 18
				botao.offset_left = 3.0
				botao.offset_right = 3.0 + largura + 2.0 * CRESCER_X
				botao.grow_horizontal = Control.GROW_DIRECTION_END
				area.anchor_left = 0.0
				area.anchor_right = 0.0
				area.offset_left = 0.0
				area.offset_right = AREA_TOQUE_FECHAR.x
			else:
				botao.offset_left -= 2.0 * CRESCER_X
				area.anchor_left = botao.anchor_left
				area.anchor_right = botao.anchor_right
				area.offset_left = botao.offset_right - AREA_TOQUE_FECHAR.x
				area.offset_right = botao.offset_right + 4.0
			botao.get_parent().add_child(area)

func _unhandled_input(evento: InputEvent) -> void:
	if _telas_abertas.has("introducao"):
		get_viewport().set_input_as_handled()
		return
	# Na tela de fim de partida só o botão dela segue em frente
	if _telas_abertas.has("fim_partida"):
		if evento.is_action_pressed("open_inventory") or evento.is_action_pressed("close_menu"):
			get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("open_inventory"):
		if _telas_abertas.has("inventario"):
			_fechar_tela("inventario")
		else:
			_abrir_tela("inventario")
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("close_menu") and not _telas_abertas.is_empty():
		# Dentro de OPCOES ou da confirmação da pausa, Esc/B só volta ao menu da pausa
		if _telas_abertas.has("pausa") and _telas["pausa"].voltar_subtela():
			get_viewport().set_input_as_handled()
			return
		for nome in _telas_abertas.duplicate():
			_fechar_tela(nome)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("pausar"):
		# Esc sem nenhuma tela aberta abre a pausa (o jogador sentado só se levanta: o mesmo Esc o levanta)
		var jogador := EventosJogo.dono(self)
		if _telas_abertas.is_empty() and not (jogador != null and bool(jogador.get("esta_sentado"))):
			_abrir_tela("pausa")
			get_viewport().set_input_as_handled()
		elif _telas_abertas == ["pausa"]:
			_fechar_tela("pausa")
			get_viewport().set_input_as_handled()

func _abrir_tela(nome: String, acompanhante := false) -> void:
	if not Introducao.permite_tela(nome):
		return
	if not _telas.has(nome):
		return
	if nome == "inventario" and acompanhante:
		_telas[nome].selecionar_aba(false)
		_ajustar_mochila(nome)
	if _telas_abertas.has(nome):
		return
	# Com a tela de fim de partida aberta nenhuma outra abre por cima
	if _telas_abertas.has("fim_partida") and not nome in TELAS_OBRIGATORIAS:
		return
	# A morte vale mais que qualquer outra tela aberta
	if nome in TELAS_OBRIGATORIAS:
		for outra in _telas_abertas.duplicate():
			_fechar_tela(outra)
	_ajustar_mochila(nome)
	_telas[nome].visible = true
	# Botões que as telas montam por código (loja, acampamento, Mística) só existem depois de visíveis
	Sons.ligar_botoes(_telas[nome])
	_telas_abertas.append(nome)
	_animar_entrada(_paineis[nome])
	_definir_acoes_do_jogador_desabilitadas(true)
	EventosJogo.tela_aberta.emit(nome)
	for outra in TELAS_ACOMPANHANTES.get(nome, []):
		_abrir_tela(outra, true)
	# No controle o foco vai para a tela pedida (não para a que abriu junto)
	if not acompanhante:
		_focar_tela(nome)

## A mochila mantém os slots nativos: ao lado da loja usa quatro colunas em vez de encolher.
func _ajustar_mochila(nome: String) -> void:
	if nome != "inventario" or not get_viewport().has_meta("dono"):
		return
	var disponivel := get_viewport().get_visible_rect().size.x
	for outra in TELAS_ACOMPANHANTES:
		if outra in _telas_abertas:
			var painel: Control = _paineis[outra]
			var inicio := get_viewport().get_visible_rect().size.x * painel.anchor_left + float(painel.get_meta("offset_entrada", painel.offset_left))
			disponivel -= inicio + painel.size.x
	_telas["inventario"].ajustar_largura(minf(210.0, maxf(110.0, floorf(disponivel))))

func _fechar_tela(nome: String) -> void:
	if not _telas_abertas.has(nome):
		return
	_telas_abertas.erase(nome)
	_telas[nome].visible = false
	if _telas_abertas.is_empty():
		_definir_acoes_do_jogador_desabilitadas(false)
		# Com algum botão em foco o jogador não ataca; e o B/A que fechou a tela não pode rolar/atacar
		get_viewport().gui_release_focus()
		for acao in ACOES_DO_JOGADOR:
			Input.action_release(acao)
	else:
		_focar_tela(_telas_abertas[0])
	EventosJogo.tela_fechada.emit(nome)
	for outra in TELAS_ACOMPANHANTES.get(nome, []):
		_fechar_tela(outra)

func _focar_tela(nome: String) -> void:
	var tela: Node = _telas[nome]
	if tela.has_method("focar_inicio"):
		tela.focar_inicio()

# Pegou o controle com uma tela aberta e nada em foco: foca a tela principal
func _ao_modo_controle(usando_controle: bool) -> void:
	if usando_controle and not _telas_abertas.is_empty() and get_viewport().gui_get_focus_owner() == null:
		_focar_tela(_telas_abertas[0])
		# o toque que acordou o controle só acende o foco, sem já andar uma posição
		get_viewport().set_input_as_handled()

# Desliza a sidebar a partir da borda em que ela está presa
func _animar_entrada(painel: Control) -> void:
	var anterior: Tween = painel.get_meta("animacao_entrada") if painel.has_meta("animacao_entrada") else null
	if anterior != null and anterior.is_valid():
		anterior.kill()
	if painel in _paineis_centrais():
		painel.modulate.a = 0.0
		var animacao := painel.create_tween()
		painel.set_meta("animacao_entrada", animacao)
		animacao.tween_property(painel, "modulate:a", 1.0, DURACAO_ENTRADA)
		return
	# Calculado pelas âncoras: se a tela fechar no meio da animação, position.x fica no meio do caminho
	# position também altera offset_left: guardar o destino antes da primeira animação.
	if not painel.has_meta("offset_entrada"):
		painel.set_meta("offset_entrada", painel.offset_left)
	var x_final := painel.get_parent_area_size().x * painel.anchor_left + float(painel.get_meta("offset_entrada"))
	var na_direita := painel.anchor_left >= 1.0
	painel.position.x = x_final + (painel.size.x if na_direita else -painel.size.x)
	var tween := painel.create_tween()
	painel.set_meta("animacao_entrada", tween)
	tween.tween_property(painel, "position:x", x_final, DURACAO_ENTRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _paineis_centrais() -> Array:
	var lista: Array = []
	for nome in TELAS_CENTRAIS:
		lista.append(_paineis[nome])
	return lista

func _definir_acoes_do_jogador_desabilitadas(desabilitar: bool) -> void:
	var jogador := EventosJogo.dono(self)
	if jogador != null:
		jogador.desabilitar_todas_acoes(desabilitar or Introducao.cinematica)
