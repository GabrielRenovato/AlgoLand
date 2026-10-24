extends "res://codigo/logica/interagivel.gd"

## Cadeira da casa: F/Y senta o jogador (pose de sentar da página 4 do Character Base, com a roupa dele; Jogador.sentar),
## olhando para a mesa, e ele fica sentado até pedir para levantar (F/Y, B/Esc ou andar), quando volta de pé atrás da
## cadeira. Não abre tela: reaproveita o aviso e a lógica de "o mais próximo" do interagivel.gd.

const Profundidade := preload("res://codigo/globais/profundidade.gd")

## Para onde o jogador olha sentado (1 = direita, -1 = esquerda)
@export var lado: int = 1
## Banco de mesa: 1 = senta de frente (a mesa está abaixo), -1 = de costas (a mesa está acima), 0 = de lado (lado)
@export var frente: int = 0
## Onde o jogador (a origem dele) fica sentado e onde fica ao levantar, em relação à cadeira. Ele levanta atrás da cadeira
## (ao norte): embaixo dela só sobra uma faixa de 8 px antes da parede sul (y 112) e ao lado da cadeira direita fica a
## parede leste, então só ali tem espaço livre para os pés (círculo de 5 px)
@export var assento := Vector2(1, -9)
@export var saida := Vector2(0, -20)
## A mesa (Sprite2D): as pernas do jogador sentado passam POR BAIXO dela. A mesa e a cadeira têm a base na mesma faixa de
## 8 px (mesmo z), então a mesa sobe uma faixa e o jogador sentado fica entre os dois: acima da cadeira, abaixo da mesa
@export var mesa: NodePath

var ocupada := false

var _jogador: Node2D

func _ready() -> void:
	add_to_group("assentos")
	super._ready()
	var tampo := get_node_or_null(mesa) as Sprite2D
	if tampo != null:
		tampo.z_index = maxi(tampo.z_index, z_da_cadeira() + Profundidade.NIVEIS)

## Livre para sentar: ninguém nela e o jogador de pé e solto
func pode_interagir() -> bool:
	return pode_interagir_para(Cooperativo._jogador1())

func pode_interagir_para(jogador: Node2D) -> bool:
	return not ocupada and jogador != null and jogador.get_world_2d() == get_world_2d() \
			and jogador is CharacterBody2D and not bool(jogador.get("esta_sentado")) and bool(jogador.get("movimento_habilitado")) \
			and not bool(jogador.get("estaMorto"))

## Banco vazio vence o morador sentado ao lado na disputa do F (pedido de 2026-10-16)
func prioridade_interacao() -> int:
	return 1

func abrir_tela() -> void:
	if pode_interagir():
		_sentar()

func fechar_tela() -> void:
	pass   # sair de perto não faz nada (não há tela)

# --- Sentar e levantar ----------------------------------------------------------------------------------------

## O z da cadeira (do profundidade_grupo: pela base dela, a 8 px dos pés da zona)
func z_da_cadeira() -> int:
	return Profundidade.z_de(global_position.y + 8.0)

## O jogador 2 também senta (cooperativo)
func abrir_tela_p2() -> void:
	var p2 := Cooperativo.jogador2()
	if pode_interagir_para(p2):
		_sentar(p2)

func _sentar(quem: Node2D = null) -> void:
	var candidato: Node2D = quem if quem != null else Cooperativo._jogador1()
	if not pode_interagir_para(candidato):
		return
	_jogador = candidato
	ocupada = true
	_aviso.visible = false
	_jogador.pediu_levantar.connect(_levantar, CONNECT_ONE_SHOT)
	_jogador.set("assento_atual", self)
	# Na frente do encosto (z da cadeira + 1) e atrás da mesa (que subiu uma faixa): as pernas passam por baixo dela
	# De costas o banco fica na frente das pernas (o jogador um nível abaixo dele); de lado e de frente, acima
	var z := z_da_cadeira() - 1 if frente < 0 else z_da_cadeira() + 1
	_jogador.sentar(global_position + assento, lado, z, frente)

## Levantar: de pé atrás da cadeira
func _levantar() -> void:
	if not ocupada:
		return
	ocupada = false
	if is_instance_valid(_jogador):
		_jogador.levantar(global_position + saida)
		_jogador.set("assento_atual", null)
	_jogador = null

# --- Sentado: mesa da taverna e vizinhos ---------------------------------------------------------------------

## Até onde fica "a mesma mesa" (os bancos de frente um para o outro ficam a 54 px)
const DISTANCIA_VIZINHO := 64.0

func _process(delta: float) -> void:
	super._process(delta)
	# Sentado com algo para fazer (cardápio, vizinho): o aviso do botão fica sobre o assento
	if ocupada and is_instance_valid(_jogador) and _tem_acao_sentado(_jogador):
		_aviso.visible = true

## O botão de interagir do jogador sentado (Jogador._atualizar_sentado). true = usou (não levanta)
func interagir_sentado(quem: Node2D) -> bool:
	var vizinhos := _vizinhos(quem)
	if _na_mesa_da_taverna(quem):
		Cidade.abrir_mesa(quem, vizinhos)
		return true
	if not vizinhos.is_empty():
		Cidade.conversar(vizinhos[0], quem)
		return true
	return false

func _tem_acao_sentado(quem: Node2D) -> bool:
	return _na_mesa_da_taverna(quem) or not _vizinhos(quem).is_empty()

func _na_mesa_da_taverna(quem: Node2D) -> bool:
	var cena := Cooperativo.cena_de(self)
	var rotina: Node = cena.get_node_or_null("RotinaTaverna") if cena != null else null
	return rotina != null and rotina.mesa_do_jogador(quem) != Vector2.INF

## Moradores sentados ou parados perto deste assento (ids, do mais perto ao mais longe)
func _vizinhos(quem: Node2D) -> Array:
	var perto: Array = []
	for morador in get_tree().get_nodes_in_group("moradores_cidade"):
		if not morador.visible or morador.dormindo or morador.get_world_2d() != quem.get_world_2d():
			continue
		var distancia: float = morador.global_position.distance_to(quem.global_position)
		if distancia <= DISTANCIA_VIZINHO:
			perto.append([distancia, morador.id])
	perto.sort_custom(func(a, b): return a[0] < b[0])
	return perto.map(func(par): return par[1])
