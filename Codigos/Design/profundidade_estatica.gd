extends Node

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

## Filho auxiliar para objetos parados (barraca, fogueira, mercador): define o z do pai uma vez,
## pela base informada em coordenadas locais do pai
@export var y_base_local: float = 0.0

func _ready() -> void:
	var pai := get_parent() as Node2D
	if pai:
		pai.z_index = Profundidade.z_de(pai.to_global(Vector2(0, y_base_local)).y)
