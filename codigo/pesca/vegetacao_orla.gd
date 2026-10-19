extends "res://codigo/cidade/decoracao_vila.gd"

## Moldura natural da enseada: mesmas arvores, arbustos, bases e quatro estacoes da vila.
func _ready() -> void:
	name = "VegetacaoOrla"
	var modelos := {}
	for item in JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)):
		if item["p"] in ["vegetacao/arvore","vegetacao/arbusto"] and not modelos.has(item["p"]):
			modelos[item["p"]] = item
	var corpo := StaticBody2D.new()
	corpo.name = "Obstaculos"
	corpo.collision_layer = CAMADA_OBSTACULOS
	corpo.collision_mask = 0
	add_child(corpo)
	var grupos := {
		"vegetacao/arvore": [Vector2(16,80),Vector2(88,64),Vector2(176,48),Vector2(248,48),
			Vector2(432,40),Vector2(516,48),Vector2(612,56),Vector2(690,104),
			Vector2(16,172),Vector2(40,264),Vector2(696,220)],
		"vegetacao/arbusto": [Vector2(110,88),Vector2(260,68),Vector2(414,64),Vector2(608,88),
			Vector2(96,240),Vector2(76,300),Vector2(666,252),Vector2(666,144)],
	}
	for tipo in grupos:
		for base: Vector2 in grupos[tipo]:
			var dados: Dictionary = modelos[tipo].duplicate(true)
			dados["x"] = base.x
			dados["y"] = base.y
			_montar_item(corpo,dados)
