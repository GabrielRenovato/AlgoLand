extends TileMapLayer

## A neve cobre os patamares, mantendo as faces minerais e a colisão.
const FOLHAS := [
	preload("res://assets/cenario/fendas/pedreiras/spring.png"),
	preload("res://assets/cenario/fendas/pedreiras/summer.png"),
	preload("res://assets/cenario/fendas/pedreiras/autumn.png"),
	preload("res://assets/cenario/fendas/pedreiras/winter.png"),
]
func _ready() -> void:
	tile_set = tile_set.duplicate(true)
	var estacoes: Node = get_parent().get_node("Estacoes")
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)

func _trocar(indice: int) -> void:
	(tile_set.get_source(0) as TileSetAtlasSource).texture = FOLHAS[clampi(indice,0,3)]
