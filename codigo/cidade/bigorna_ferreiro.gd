extends "res://codigo/logica/interagivel.gd"

## A interação pertence à bigorna; usa a mesma entrada e o mesmo dono da interface.
func _ready() -> void:
	super._ready()
	var trabalho := preload("res://codigo/cidade/trabalho_ferreiro.gd").new()
	trabalho.name = "TrabalhoFerreiro"
	add_child(trabalho)

func _montar_aviso() -> void:
	super._montar_aviso()
	_aviso.texture = preload("res://assets/ui/bosque/slot.png")
	_aviso.scale = Vector2.ONE
	_rotulo_tecla.position = Vector2(-12,-12)
	_rotulo_tecla.size = Vector2(24,24)
	_rotulo_tecla.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icone_tecla.position = Vector2(2,2)
	_icone_tecla.size = Vector2(20,20)
