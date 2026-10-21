extends Node

## Troca o desenho da cerca da fazenda pela estação visual do terreno (o Estacoes irmão): cada sprite do grupo "cerca" tem a
## peça em metadata/peca ("horizontal", "poste", "vertical"), e as texturas ficam em <PASTA>/<estação>/<peça>.png
## (ferramentas/fazenda/montar_cerca.py: neve no inverno, folhas secas no outono).
const PASTA := "res://assets/cenario/fazenda/cerca/"
const DETALHADA := "res://assets/cenario/fazenda/acabamento_detalhado/"
const ACABAMENTO := preload("res://codigo/cenario/natureza_fazenda.gdshader")
const NOMES := ["primavera", "verao", "outono", "inverno"]
var _materiais := {}

func _ready() -> void:
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null:
		estacoes.estacao_mudou.connect(_aplicar)
		if int(estacoes.estacao_atual) >= 0:
			_aplicar(int(estacoes.estacao_atual))
			return
	_aplicar(Calendario.estacao())

func _aplicar(estacao: int) -> void:
	var nome: String = NOMES[clampi(estacao, 0, 3)]
	var tiny := bool(get_parent().get_meta("visual_tiny", false))
	# Cada mundo cooperativo usa a estação do próprio terreno.
	for cerca in get_parent().get_node("Objetos3D").get_children():
		if not cerca.is_in_group("cerca"): continue
		var peca := String(cerca.get_meta("peca"))
		cerca.texture = load(PASTA + nome + "/" + peca + ".png")
		if not _materiais.has(peca):
			var material := ShaderMaterial.new()
			material.shader = ACABAMENTO
			_materiais[peca] = material
		_materiais[peca].set_shader_parameter("arte", load(DETALHADA + nome + "/cerca_" + peca + ".png"))
		cerca.material = null if tiny else _materiais[peca]
