extends Node2D

## A folha corre para cima; a moldura e a rampa permanecem na fachada.
var _abertura := 1.0
var interna := false

var _folha: Node2D

func _ready() -> void:
	_abertura = 1.0 if Fazenda.bando.portinha_aberta() else 0.0
	_folha = preload("res://codigo/fazenda/folha_portinha.gd").new()
	_folha.name = "FolhaInterna" if interna else "FolhaExterna"
	_folha.position = Vector2(-6,-5) if interna else Vector2(-5,-11)
	_folha.tamanho = Vector2(12,14) if interna else Vector2(10,11)
	_folha.abertura = _abertura
	_folha.visible = _abertura < 0.999
	_folha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_folha.z_index = 1
	add_child(_folha)

func _process(delta: float) -> void:
	var alvo := 1.0 if Fazenda.bando.portinha_aberta() else 0.0
	_abertura = move_toward(_abertura,alvo,delta*2)
	_folha.visible = _abertura < 0.999
	_folha.abertura = _abertura
	_folha.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if interna: return
	# A moldura pertence à fachada. Só esconde a tela da portinha quando abre.
	draw_rect(Rect2(-5,-11,10,11),Color("291d17"))

func usar_folha_externa() -> void:
	# Tábuas da própria rampa: tampa de madeira fechada, sem a tela/vão visível.
	_folha.textura = preload("res://assets/cenario/fazenda/galinheiro/nivel_1_primavera.png")
	_folha.regiao = Rect2(134,132,7,10)
	_folha.queue_redraw()
