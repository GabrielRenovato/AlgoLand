extends CanvasLayer

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const DURACAO_ENTRADA := 0.15
# Como no Diablo: a loja abre na esquerda e o inventário junto na direita, para arrastar itens entre os dois
const TELAS_ACOMPANHANTES := {"mercante": ["inventario"]}

var _telas_abertas: Array[String] = []

@onready var _telas: Dictionary = {
	"inventario": $TelaInventario,
	"mercante": $TelaMercante,
}
@onready var _paineis: Dictionary = {
	"inventario": $TelaInventario/Sidebar,
	"mercante": $TelaMercante/Painel,
}

func _ready() -> void:
	for tela in _telas.values():
		tela.visible = false
	EventosJogo.abrir_tela.connect(_abrir_tela)
	EventosJogo.fechar_tela.connect(_fechar_tela)

func _unhandled_input(evento: InputEvent) -> void:
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

func _abrir_tela(nome: String) -> void:
	if not _telas.has(nome) or _telas_abertas.has(nome):
		return
	_telas[nome].visible = true
	_telas_abertas.append(nome)
	_animar_entrada(_paineis[nome])
	_definir_acoes_do_jogador_desabilitadas(true)
	EventosJogo.tela_aberta.emit(nome)
	for acompanhante in TELAS_ACOMPANHANTES.get(nome, []):
		_abrir_tela(acompanhante)

func _fechar_tela(nome: String) -> void:
	if not _telas_abertas.has(nome):
		return
	_telas_abertas.erase(nome)
	_telas[nome].visible = false
	if _telas_abertas.is_empty():
		_definir_acoes_do_jogador_desabilitadas(false)
	EventosJogo.tela_fechada.emit(nome)
	for acompanhante in TELAS_ACOMPANHANTES.get(nome, []):
		_fechar_tela(acompanhante)

# Desliza a sidebar a partir da borda em que ela está presa
func _animar_entrada(painel: Control) -> void:
	# Calculado pelas âncoras: se a tela fechar no meio da animação, position.x fica no meio do caminho
	var x_final := painel.get_parent_area_size().x * painel.anchor_left + painel.offset_left
	var na_direita := painel.anchor_left >= 1.0
	painel.position.x = x_final + (painel.size.x if na_direita else -painel.size.x)
	var tween := painel.create_tween()
	tween.tween_property(painel, "position:x", x_final, DURACAO_ENTRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _definir_acoes_do_jogador_desabilitadas(desabilitar: bool) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador != null:
		jogador.desabilitar_todas_acoes(desabilitar)
