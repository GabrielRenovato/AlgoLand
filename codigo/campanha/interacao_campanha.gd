extends "res://codigo/logica/interagivel.gd"

## Usa o mesmo indicador e ação F/Y/toque dos moradores e objetos do jogo.
var id := ""
var cena_responsavel: Node

func pode_interagir() -> bool:
	var cena:Node=cena_responsavel if is_instance_valid(cena_responsavel) else get_parent()
	return visible and is_instance_valid(cena.jogador) and not cena.jogador.estaMorto \
		and cena.jogador.movimento_habilitado and cena.interface._telas_abertas.is_empty() \
		and cena.alvo_proximo() == id

func disponivel_para_interacao() -> bool:
	return pode_interagir()

func disponivel_isolada() -> bool:
	return pode_interagir()

func abrir_tela() -> void:
	if pode_interagir():
		var cena:Node=cena_responsavel if is_instance_valid(cena_responsavel) else get_parent()
		cena.interagir_proximo()
