extends CanvasLayer

# O set_drag_preview nativo desenha na camada 0 e fica atrás das telas (Interface usa layer 10).
# Este autoload mostra o item arrastado numa camada acima de todas as telas.
const CAMADA_PREVIEW := 100

var _conteudo: Control

func _ready() -> void:
	layer = CAMADA_PREVIEW
	set_process_input(false)

func mostrar(conteudo: Control) -> void:
	esconder()
	_conteudo = conteudo
	_conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_conteudo)
	_conteudo.position = get_viewport().get_mouse_position()
	set_process_input(true)
	# Eventos acumulados chegam uma vez por frame; desligado, o item acompanha cada movimento do mouse
	Input.use_accumulated_input = false

func esconder() -> void:
	set_process_input(false)
	Input.use_accumulated_input = true
	if is_instance_valid(_conteudo):
		_conteudo.queue_free()
	_conteudo = null

func _input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and is_instance_valid(_conteudo):
		_conteudo.position = get_viewport().get_mouse_position()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		esconder()
