extends "res://codigo/campanha/interacao_campanha.gd"

## Preserva F/Y/toque e o candidato único da cena, acrescentando o roteiro local.
var roteiro: Node

func abrir_tela() -> void:
	if pode_interagir() and is_instance_valid(roteiro): roteiro.interagir(id)
