extends CanvasLayer

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")

var _telas_abertas: Array[String] = []

@onready var _telas: Dictionary = {
	"inventario": $TelaInventario,
	"mercante": $TelaMercante,
}

func _ready() -> void:
	for tela in _telas.values():
		tela.visible = false
	EventosJogo.abrir_tela.connect(_abrir_tela)
	EventosJogo.fechar_tela.connect(_fechar_tela)

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("open_inventory"):
		# Com o mercante aberto o inventário é a fonte dos itens arrastados para a bigorna
		if _telas_abertas.has("inventario"):
			_fechar_tela("inventario")
		else:
			_abrir_tela("inventario")
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("close_menu") and not _telas_abertas.is_empty():
		_fechar_tela(_telas_abertas.back())
		get_viewport().set_input_as_handled()

func _abrir_tela(nome: String) -> void:
	if not _telas.has(nome) or _telas_abertas.has(nome):
		return
	_telas[nome].visible = true
	_telas_abertas.append(nome)
	_definir_acoes_do_jogador_desabilitadas(true)
	EventosJogo.tela_aberta.emit(nome)

func _fechar_tela(nome: String) -> void:
	if not _telas_abertas.has(nome):
		return
	_telas_abertas.erase(nome)
	_telas[nome].visible = false
	if _telas_abertas.is_empty():
		_definir_acoes_do_jogador_desabilitadas(false)
	EventosJogo.tela_fechada.emit(nome)

func _definir_acoes_do_jogador_desabilitadas(desabilitar: bool) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador != null:
		jogador.desabilitar_todas_acoes(desabilitar)
