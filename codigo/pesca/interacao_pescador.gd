extends "res://codigo/logica/interagivel.gd"

func _ready() -> void:
	nome_tela = "conversa_cidade"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0, -38)
	super._ready()

func pode_interagir_para(jogador: Node2D) -> bool:
	return get_parent().visible and not get_parent().dormindo and jogador != null and jogador.get_world_2d() == get_world_2d() \
		and jogador.movimento_habilitado and not Transicao.ocupada and super.pode_interagir_para(jogador)

func pode_interagir() -> bool:
	return get_parent().visible and not get_parent().dormindo and super.pode_interagir()

func abrir_tela() -> void:
	if pode_interagir_para(Cooperativo._jogador1()):
		Cidade.conversar("nilo",Cooperativo._jogador1())

func abrir_tela_p2() -> void:
	if pode_interagir_para(Cooperativo.jogador2()):
		Cidade.conversar("nilo",Cooperativo.jogador2())
