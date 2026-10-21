extends RefCounted
## Apresentação em alta resolução, independente da geometria do layout.
const MANIFESTO := "res://assets/cenario/cidade/enfeites_detalhados/manifesto.json"
static var _dados: Dictionary = {}
static func dados(id: String) -> Dictionary:
	if _dados.is_empty() and FileAccess.file_exists(MANIFESTO):
		_dados = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
		var complementos:="res://assets/cenario/cidade/complementos/manifesto.json"
		if FileAccess.file_exists(complementos):
			_dados.merge(JSON.parse_string(FileAccess.get_file_as_string(complementos)),false)
	return _dados.get(id,{})
