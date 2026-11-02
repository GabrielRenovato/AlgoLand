extends Control

## Ilustração fixa do domínio; a câmera enquadra os pontos de viagem em cada tela.
const TAMANHO := Vector2(1536,1024)
var camada := Control.new()
var imagem := TextureRect.new()
var fundo := ColorRect.new()
var foco := Vector2(0.35,0.46)
var _arrastando := false
var _movimento: Tween

func _ready() -> void:
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	camada.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fundo.color=Color("167f94")
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	add_child(camada)
	imagem.texture=preload("res://assets/ui/campanha/mapa_primeira_raiz_cartoon.png")
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camada.add_child(imagem)
	resized.connect(ajustar)
	gui_input.connect(_navegar)

func ajustar() -> void:
	if size.x<=0 or size.y<=0:return
	var escala:=maxf(size.x/TAMANHO.x,size.y/TAMANHO.y)
	camada.size=TAMANHO*escala
	imagem.size=camada.size
	focar(foco,false)

func retangulo_mapa() -> Rect2:
	return Rect2(camada.global_position,camada.size)

func cobertura_agua() -> Rect2:
	return fundo.get_global_rect()

func focar(ponto: Vector2,animar:=true) -> void:
	foco=ponto
	if _movimento!=null:_movimento.kill()
	var centro:=Vector2(size.x/2,(48+size.y-74)/2)
	var destino:=_limitar(centro-ponto*camada.size)
	if animar and is_visible_in_tree():
		_movimento=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_movimento.tween_property(camada,"position",destino,0.25)
	else:camada.position=destino

func _limitar(posicao: Vector2) -> Vector2:
	return Vector2(clampf(posicao.x,minf(0,size.x-camada.size.x),0),clampf(posicao.y,size.y-camada.size.y-90,90))

func deslocar(delta: Vector2) -> void:
	if _movimento!=null:_movimento.kill()
	camada.position=_limitar(camada.position+delta)
	foco=(size/2-camada.position)/camada.size

func _navegar(evento: InputEvent) -> void:
	if evento is InputEventMouse and evento.device==InputEvent.DEVICE_ID_EMULATION:return
	if evento is InputEventMouseButton and evento.button_index==MOUSE_BUTTON_LEFT:
		_arrastando=evento.pressed
		accept_event()
	elif evento is InputEventMouseMotion and _arrastando:
		deslocar(evento.relative)
		accept_event()
	elif evento is InputEventScreenTouch:
		_arrastando=evento.pressed
		accept_event()
	elif evento is InputEventScreenDrag:
		deslocar(evento.relative)
		accept_event()
