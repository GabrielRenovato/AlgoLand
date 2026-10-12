extends CanvasLayer

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const DURACAO_ENTRADA := 0.15
# Como no Diablo: a loja abre na esquerda e o inventário junto na direita, para arrastar itens entre os dois
const TELAS_ACOMPANHANTES := {"mercante": ["inventario"]}
# Ações de jogo que dividem botão com os menus (B fecha a tela e também rola; A confirma e também ataca)
const ACOES_DO_JOGADOR := ["rolar", "attack"]
# Telas no centro da tela: em vez de deslizar de uma borda, aparecem com fade
const TELAS_CENTRAIS := ["acampamento", "mistica", "fim_partida", "dormir"]
# Só se fecha pelo próprio botão (B/Esc e o atalho do inventário são ignorados)
const TELAS_OBRIGATORIAS := ["fim_partida"]

var _telas_abertas: Array[String] = []

@onready var _telas: Dictionary = {
	"inventario": $TelaInventario,
	"mercante": $TelaMercante,
	"acampamento": $TelaAcampamento,
	"mistica": $TelaMistica,
	"fim_partida": $TelaFimPartida,
	"dormir": $TelaDormir,
	"caldeirao": $TelaCaldeirao,
}
@onready var _paineis: Dictionary = {
	"inventario": $TelaInventario/Sidebar,
	"mercante": $TelaMercante/Painel,
	"acampamento": $TelaAcampamento/Centro/Painel,
	"mistica": $TelaMistica/Centro/Painel,
	"fim_partida": $TelaFimPartida/Centro/Painel,
	"dormir": $TelaDormir/Centro/Painel,
	"caldeirao": $TelaCaldeirao/Painel,
}

func _ready() -> void:
	for tela in _telas.values():
		tela.visible = false
	EventosJogo.abrir_tela.connect(_abrir_tela)
	EventosJogo.fechar_tela.connect(_fechar_tela)
	Controle.modo_alterado.connect(_ao_modo_controle)

func _unhandled_input(evento: InputEvent) -> void:
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
		for nome in _telas_abertas.duplicate():
			_fechar_tela(nome)
		get_viewport().set_input_as_handled()

func _abrir_tela(nome: String, acompanhante := false) -> void:
	if not _telas.has(nome) or _telas_abertas.has(nome):
		return
	# Com a tela de fim de partida aberta nenhuma outra abre por cima
	if _telas_abertas.has("fim_partida") and not nome in TELAS_OBRIGATORIAS:
		return
	# A morte vale mais que qualquer outra tela aberta
	if nome in TELAS_OBRIGATORIAS:
		for outra in _telas_abertas.duplicate():
			_fechar_tela(outra)
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
	if painel in _paineis_centrais():
		painel.modulate.a = 0.0
		painel.create_tween().tween_property(painel, "modulate:a", 1.0, DURACAO_ENTRADA)
		return
	# Calculado pelas âncoras: se a tela fechar no meio da animação, position.x fica no meio do caminho
	var x_final := painel.get_parent_area_size().x * painel.anchor_left + painel.offset_left
	var na_direita := painel.anchor_left >= 1.0
	painel.position.x = x_final + (painel.size.x if na_direita else -painel.size.x)
	var tween := painel.create_tween()
	tween.tween_property(painel, "position:x", x_final, DURACAO_ENTRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _paineis_centrais() -> Array:
	var lista: Array = []
	for nome in TELAS_CENTRAIS:
		lista.append(_paineis[nome])
	return lista

func _definir_acoes_do_jogador_desabilitadas(desabilitar: bool) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador != null:
		jogador.desabilitar_todas_acoes(desabilitar)
