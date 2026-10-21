extends RefCounted
## Metadados de apresentação; as medidas lógicas e colisões continuam em exteriores.json.
const MANIFESTO := "res://assets/cenario/cidade/fachadas_detalhadas/manifesto.json"
static var _dados: Dictionary = {}
static func dados(id: String) -> Dictionary:
	if _dados.is_empty() and FileAccess.file_exists(MANIFESTO):
		_dados = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	return _dados.get(id,{})
