extends Node

## Veste os mapas de floresta que não têm as árvores "gentle" (andares 6 e 10, as Ruínas) com o mesmo acabamento detalhado
## dos bosques (floresta_detalhada.gd): grama e terra pintadas, árvores, pedras e barrancos nas quatro estações. Só muda a
## apresentação; células, colisões e navegação seguem as do mapa. Mesmo gesto de gentle_sazonal.gd::_instalar_detalhes.
func _ready() -> void:
	_instalar.call_deferred()

func _instalar() -> void:
	var terreno := get_parent()
	if terreno.has_node("FlorestaDetalhada"):
		return
	var detalhes := preload("res://codigo/fendas/floresta_detalhada.gd").new()
	detalhes.name = "FlorestaDetalhada"
	terreno.add_child(detalhes)
