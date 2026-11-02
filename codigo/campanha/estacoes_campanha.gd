extends Node
## Compatibilidade de consulta com os recursos sazonais existentes.
var estacao_atual := -1
func definir_estacao(indice: int, _imediato := true) -> void:
	get_parent().definir_estacao(indice)
