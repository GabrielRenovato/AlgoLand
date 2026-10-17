extends "res://codigo/logica/interagivel.gd"

## Passagem entre cenas (caverna da arena <-> fazenda, porta da casa): mesma zona e mesmo aviso F/Y do Interagivel, mas
## em vez de abrir uma tela faz a troca de cena com fade (autoload Transicao).
## Escolha: a passagem é por INTERAÇÃO (F/Y) e não ao andar para dentro. Assim a troca nunca acontece sem querer
## (a boca da caverna fica no caminho do acampamento para a floresta) e o jogador vê o aviso antes de decidir.
## Na arena só vale entre as ondas (so_entre_ondas, herdado): no meio da luta a caverna fica fechada.

## Cena de destino (res://...) e nome do ponto de chegada nela (Marker2D "Chegada_<ponto>" do grupo "chegada")
@export_file("*.tscn") var cena_destino: String = ""
@export var ponto_chegada: String = ""
## Saída pela borda do mapa (trilha da cidade para a fazenda): com uma direção, não há aviso nem F/Y; o jogador que
## entra na zona andando para essa direção atravessa na hora, com o fade da Transicao. Zero = passagem por interação.
@export var direcao_saida := Vector2.ZERO

func _ready() -> void:
	# A base libera a interação por nome de tela; esta zona não abre tela, só precisa estar "ativa"
	if nome_tela == "":
		nome_tela = "passagem"
	super._ready()

func pode_interagir() -> bool:
	return cena_destino != "" and not Transicao.ocupada and super.pode_interagir()

func abrir_tela() -> void:
	_atravessar(Cooperativo._jogador1())

func _atravessar(jogador: Node2D) -> void:
	if not pode_interagir() or jogador == null or not jogador.movimento_habilitado:
		return
	if Cooperativo.com_dois() and cena_destino != "res://cenas/cenario.tscn" and Cooperativo.cena_de(self).scene_file_path != "res://cenas/cenario.tscn":
		Cooperativo.viajar_local(jogador, cena_destino, ponto_chegada)
	else:
		Transicao.ir_para(cena_destino, ponto_chegada)

func fechar_tela() -> void:
	pass

func abrir_tela_p2() -> void:
	_atravessar(Cooperativo.jogador2())

# --- Saída pela borda ---------------------------------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if direcao_saida == Vector2.ZERO:
		return
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogadores") and corpo.velocity.dot(direcao_saida) > 1.0:
			_atravessar.call_deferred(corpo)

func _process(delta: float) -> void:
	if direcao_saida != Vector2.ZERO:
		_aviso.hide()
	else:
		super._process(delta)

func disponivel_para_interacao() -> bool:
	return direcao_saida == Vector2.ZERO and super.disponivel_para_interacao()

func disponivel_para_p2() -> bool:
	return direcao_saida == Vector2.ZERO and super.disponivel_para_p2()

func disponivel_isolada() -> bool:
	return direcao_saida == Vector2.ZERO and super.disponivel_isolada()

func disponivel_isolada_p2() -> bool:
	return direcao_saida == Vector2.ZERO and super.disponivel_isolada_p2()
