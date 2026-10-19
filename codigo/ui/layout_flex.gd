extends Node

## Dimensiona a moldura; os containers internos distribuem e rolam o conteúdo.
@export var caminho_painel: NodePath = ^"../Painel"
@export var central := false
var _painel: PanelContainer
var _largura := 0.0
var _ultima_medida := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel = get_node(caminho_painel)
	_largura = maxf(_painel.size.x, _painel.custom_minimum_size.x)
	if not central: _largura = maxf(_largura, 196.0)
	get_parent().resized.connect(_ajustar)
	_ajustar.call_deferred()

func _process(_delta: float) -> void:
	if _painel.is_visible_in_tree(): _ajustar()

func _ajustar() -> void:
	var tela := get_parent() as Control
	var medida := Vector2(minf(maxf(_largura, _painel.get_combined_minimum_size().x),tela.size.x-16), tela.size.y-16)
	if central:
		var conteudo := _painel.get_node("Linhas/Rolagem/Conteudo") as Container
		var cabecalho := _painel.get_node("Linhas/Cabecalho") as Control
		medida.y = minf(medida.y, conteudo.get_combined_minimum_size().y+cabecalho.get_combined_minimum_size().y+26)
	# A moldura pode crescer enquanto os containers recalculam o texto e o foco.
	# Conferir também o retângulo real, mesmo quando o tamanho desejado não mudou.
	if medida.is_equal_approx(_ultima_medida) and _painel.size.is_equal_approx(medida) and (central or is_equal_approx(_painel.position.y, 8.0)): return
	_ultima_medida = medida
	_painel.custom_minimum_size = medida
	if not central:
		var direita := _painel.anchor_left >= 1.0
		_painel.anchor_top = 0
		_painel.anchor_bottom = 0
		_painel.offset_top = 8
		_painel.offset_bottom = 8+medida.y
		_painel.offset_left = -medida.x-8 if direita else 8.0
		_painel.offset_right = -8.0 if direita else medida.x+8
		# Offsets sequenciais com grow_vertical=BOTH podem preservar a altura antiga.
		_painel.size = medida
		_painel.position.y = 8.0
		_painel.set_meta("offset_entrada",_painel.offset_left)
