extends "res://codigo/logica/interagivel.gd"

## A interação pertence à bigorna; usa a mesma entrada e o mesmo dono da interface.
func _ready() -> void:
	super._ready()
	var trabalho := preload("res://codigo/cidade/trabalho_ferreiro.gd").new()
	trabalho.name = "TrabalhoFerreiro"
	add_child(trabalho)
