extends Control

## Um toque consulta; o gesto de usar ou mover continua pertencendo ao item.
var origem: Control
var item: DadosItem
var painel: PanelContainer
var rolagem: ScrollContainer
var _retangulo: Rect2

static func mostrar(alvo: Control) -> void:
	var interface := EventosJogo.interface_de(alvo)
	if interface==null: return
	var dica := interface.get_node_or_null("DicaItemToque")
	if dica!=null: dica.free()
	dica=load("res://codigo/ui/dica_item_toque.gd").new()
	dica.name="DicaItemToque"
	dica.origem=alvo
	dica.item=alvo.dados
	interface.add_child(dica)

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=MOUSE_FILTER_IGNORE
	z_index=100
	size=get_viewport_rect().size
	_retangulo=origem.get_global_rect()
	var largura := minf(250,size.x-24)
	painel=PanelContainer.new()
	painel.mouse_filter=MOUSE_FILTER_STOP
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").painel(painel,false,10,true)
	add_child(painel)
	rolagem=ScrollContainer.new()
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)
	var conteudo: Control=origem.tooltip_do_item(largura-28,8)
	conteudo.mouse_filter=MOUSE_FILTER_IGNORE
	rolagem.add_child(conteudo)
	conteudo.minimum_size_changed.connect(_ajustar.call_deferred)
	painel.custom_minimum_size=Vector2(largura,0)
	_ajustar()
	# A dica só lê o item; o foco do controle e os gestos continuam no inventário.
	rolagem.focus_mode=Control.FOCUS_NONE

func _ajustar() -> void:
	var largura := painel.custom_minimum_size.x
	var conteudo := rolagem.get_child(0) as Control
	painel.size=Vector2(largura,minf(conteudo.custom_minimum_size.y+20,size.y-24))
	var x := clampf(_retangulo.get_center().x-largura/2,12,size.x-largura-12)
	var y := _retangulo.position.y-painel.size.y-8
	if y<12: y=_retangulo.end.y+8
	y=clampf(y,12,maxf(12,size.y-painel.size.y-12))
	painel.position=Vector2(x,y).round()

func _input(evento: InputEvent) -> void:
	if (evento is InputEventMouseButton or evento is InputEventScreenTouch) and evento.pressed:
		if _retangulo.has_point(evento.position) or not painel.get_global_rect().has_point(evento.position):
			hide()
			queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(origem) or not origem.is_visible_in_tree() or origem.dados!=item or origem.get_global_rect()!=_retangulo or get_viewport_rect().size!=size:
		queue_free()
