extends Node

## Troca o desenho da cerca da fazenda pela estação visual do terreno (o Estacoes irmão): cada sprite do grupo "cerca" tem a
## peça em metadata/peca ("horizontal", "poste", "vertical"), e as texturas ficam em <PASTA>/<estação>/<peça>.png
## (ferramentas/fazenda/montar_cerca.py: neve no inverno, folhas secas no outono).
const PASTA := "res://assets/cenario/fazenda/cerca/"
const NOMES := ["primavera", "verao", "outono", "inverno"]

func _ready() -> void:
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null:
		estacoes.estacao_mudou.connect(_aplicar)
		if int(estacoes.estacao_atual) >= 0:
			_aplicar(int(estacoes.estacao_atual))
			return
	_aplicar(Calendario.estacao())

func _aplicar(estacao: int) -> void:
	for cerca in get_tree().get_nodes_in_group("cerca"):
		cerca.texture = load(PASTA + NOMES[clampi(estacao, 0, 3)] + "/" + String(cerca.get_meta("peca")) + ".png")
