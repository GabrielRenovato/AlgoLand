extends TileMapLayer

const ESTACOES := ["primavera","verao","outono","inverno"]
func _ready() -> void:
	var estacoes: Node = get_parent().get_node("Estacoes")
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)

func _trocar(indice: int) -> void:
	var fonte := tile_set.get_source(0) as TileSetAtlasSource
	fonte.texture = load("res://assets/cenario/cidade/terreno/mana_seed/%s/grama_pedra.png" % ESTACOES[clampi(indice,0,3)])
