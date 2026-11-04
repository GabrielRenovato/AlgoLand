extends "res://codigo/cidade/lobby_cidade.gd"
## Praça pública da campanha; presença independente das salas de expedição.
var _ligados: Dictionary = {}
func _ready() -> void:
	mapa=4
	super._ready()
func sessao_de(jogador: Node2D) -> Node:
	var sessao: Node=super.sessao_de(jogador)
	if sessao!=null and not _ligados.has(sessao.get_instance_id()):
		_ligados[sessao.get_instance_id()]=true
		sessao.definir_online(true,false)
	return sessao
