extends "res://Codigos/Logicas/interagivel.gd"

## Passagem entre cenas (caverna da arena <-> fazenda, porta da casa): mesma zona e mesmo aviso F/Y do Interagivel, mas
## em vez de abrir uma tela faz a troca de cena com fade (autoload Transicao).
## Escolha: a passagem é por INTERAÇÃO (F/Y) e não ao andar para dentro. Assim a troca nunca acontece sem querer
## (a boca da caverna fica no caminho do acampamento para a floresta) e o jogador vê o aviso antes de decidir.
## Na arena só vale entre as ondas (so_entre_ondas, herdado): no meio da luta a caverna fica fechada.

## Cena de destino (res://...) e nome do ponto de chegada nela (Marker2D "Chegada_<ponto>" do grupo "chegada")
@export_file("*.tscn") var cena_destino: String = ""
@export var ponto_chegada: String = ""

func _ready() -> void:
	# A base libera a interação por nome de tela; esta zona não abre tela, só precisa estar "ativa"
	if nome_tela == "":
		nome_tela = "passagem"
	super._ready()

func pode_interagir() -> bool:
	return cena_destino != "" and not Transicao.ocupada and super.pode_interagir()

func abrir_tela() -> void:
	if pode_interagir():
		Transicao.ir_para(cena_destino, ponto_chegada)

func fechar_tela() -> void:
	pass
