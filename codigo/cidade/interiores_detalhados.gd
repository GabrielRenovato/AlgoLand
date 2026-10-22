extends RefCounted

## Biblioteca pintada4×. Acrescenta apresentação sem alterar o layout físico.
const MANIFESTO := "res://assets/cenario/cidade/interiores_detalhados/manifesto.json"
const RAIZ := "res://assets/cenario/cidade/interiores_detalhados/"
static var _dados: Dictionary = {}

static func dados(chave: String) -> Dictionary:
	if _dados.is_empty():
		_dados = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	return _dados.get(chave, {})

static func preparar(item: Dictionary) -> Dictionary:
	var novo := item.duplicate(true)
	if item.has("texturas") and "/ambientes/" in str(item.texturas[0]):
		var chave := str(item.texturas[0]).split("/ambientes/")[1].trim_suffix("/primavera.png")
		var detalhado := dados(chave)
		if not detalhado.is_empty():
			novo.merge(detalhado, true)
	return novo

static func estacao(no: Node) -> int:
	var atual: int = no.get_tree().root.get_node("Calendario").estacao()
	# Mundos cooperativos podem estar em locais diferentes; a prévia visual
	# pertence ao ancestral da sala, não necessariamente à cena principal.
	var pai := no.get_parent()
	while pai != null:
		var terreno := pai.get_node_or_null("Terrains/Estacoes")
		if terreno != null and terreno.estacao_atual >= 0:
			return int(terreno.estacao_atual)
		pai = pai.get_parent()
	return atual
