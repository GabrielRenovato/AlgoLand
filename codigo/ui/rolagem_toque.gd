extends Node

## Deixa os eventos alcançarem o ScrollContainer em qualquer lista, inclusive as dinâmicas.
## O arrasto, a inércia e o cancelamento do clique ficam a cargo do gesto nativo do Godot.
func _ready() -> void:
	get_tree().node_added.connect(_ao_no_adicionado)

func _ao_no_adicionado(no: Node) -> void:
	if no is Control:
		_preparar.call_deferred(weakref(no))

func _preparar(referencia: WeakRef) -> void:
	var controle := referencia.get_ref() as Control
	if controle == null or not controle.is_inside_tree() or controle.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	# Esses controles têm um gesto próprio (editar texto ou ajustar uma barra).
	if controle is ScrollContainer or controle is Range or controle is LineEdit or controle is TextEdit:
		return
	var ancestral := controle.get_parent()
	while ancestral != null:
		if ancestral is ScrollContainer:
			controle.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		ancestral = ancestral.get_parent()
