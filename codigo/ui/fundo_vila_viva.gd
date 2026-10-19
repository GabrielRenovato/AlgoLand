extends TextureRect

## Cenario de apresentacao isolado. Camera e moradores sao locais; nenhum estado do jogo e escrito.
const Ator := preload("res://codigo/ui/morador_vitrine.gd")
const ESTACOES := ["primavera","verao","outono","inverno"]
var _vista: SubViewport
var _camera: Camera2D
var _fundo: Sprite2D
var _moradores: Array[Node2D] = []
var _rotas: Array = []
var _indices := {}
var _sentidos := {}
var _curva := Curve2D.new()
var _distancia := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vista = SubViewport.new()
	_vista.disable_3d = true
	_vista.snap_2d_transforms_to_pixel = false
	_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vista.world_2d = World2D.new()
	_vista.gui_disable_input = true
	add_child(_vista)
	texture = _vista.get_texture()
	var mundo := Node2D.new()
	mundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vista.add_child(mundo)
	_fundo = Sprite2D.new()
	_fundo.centered = false
	_fundo.z_index = -1
	mundo.add_child(_fundo)
	_aplicar_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(_aplicar_estacao)
	var atores := Node2D.new()
	atores.y_sort_enabled = true
	mundo.add_child(atores)
	var metadados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/fundos_menu/rotas.json"))
	for dados_rota in metadados["rotas"]:
		var rota := PackedVector2Array()
		for ponto in dados_rota: rota.append(Vector2(ponto[0],ponto[1]))
		_rotas.append(rota)
	var ids := ["lia","mercador","curandeira","bardo","bento","mistica"]
	for i in ids.size():
		var ator := Ator.new()
		ator.id = ids[i]
		ator.velocidade = 16+i%3*2
		ator.position = _rotas[i%_rotas.size()][0]
		atores.add_child(ator)
		_moradores.append(ator)
		_indices[ator] = i%_rotas.size()
		_sentidos[ator] = 1 if i%2 == 0 else -1
		_proxima_rota(ator)
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 704
	_camera.limit_bottom = 576
	_camera.position_smoothing_enabled = false
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	mundo.add_child(_camera)
	var pontos := [Vector2(336,288),Vector2(400,320),Vector2(416,384),Vector2(352,432),Vector2(288,400),Vector2(288,320)]
	for i in pontos.size()+1:
		var indice := i%pontos.size()
		var tangente: Vector2 = (pontos[(indice+1)%pontos.size()]-pontos[(indice-1+pontos.size())%pontos.size()])*0.16
		_curva.add_point(pontos[indice],-tangente,tangente)
	resized.connect(_ajustar)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	_atualizar_camera(0)

func _aplicar_estacao(estacao: int) -> void:
	_fundo.texture = load("res://assets/ui/fundos_menu/%s.png" % ESTACOES[clampi(estacao,0,3)])

func _ajustar() -> void:
	if _vista == null: return
	# Renderizar na resolucao de exibicao permite mover a camera por pixels da tela,
	# preservando o filtro nearest e o tamanho dos sprites, sem saltos de um pixel logico ampliado.
	var escala := Vector2(get_viewport().get_texture().get_size()) / get_viewport_rect().size
	var tamanho := Vector2i((size*escala).round())
	_vista.size = Vector2i(maxi(1,tamanho.x),maxi(1,tamanho.y))
	_camera.zoom = escala

func _atualizar_camera(delta: float) -> void:
	_distancia = fposmod(_distancia+delta*7,_curva.get_baked_length())
	_camera.position = _curva.sample_baked(_distancia,true)-Vector2(48,0)
	_camera.force_update_scroll()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _camera == null: return
	_atualizar_camera(delta)
	for ator in _moradores:
		if ator.caminho.is_empty(): _proxima_rota(ator)

func _proxima_rota(ator: Node2D) -> void:
	var indice: int = _indices[ator]
	var sentido: int = _sentidos[ator]
	var rota: PackedVector2Array = _rotas[indice] if sentido > 0 else _rotas[(indice-1+_rotas.size())%_rotas.size()]
	ator.caminho = rota.duplicate()
	if sentido < 0: ator.caminho.reverse()
	_indices[ator] = (indice+sentido+_rotas.size())%_rotas.size()

