extends "res://Codigos/Logicas/interagivel.gd"

## Cadeira da casa: F/Y senta o jogador (pose de sentar da página 4 do Character Base, com a roupa dele; Jogador.sentar),
## olhando para a mesa, e ele fica sentado até pedir para levantar (F/Y, B/Esc ou andar), quando volta de pé atrás da
## cadeira. O Character Base não tem animação de beber sentado, então a xícara de café fica na mesa (com fumacinha) e
## não é usada. Não abre tela: reaproveita o aviso e a lógica de "o mais próximo" do interagivel.gd.

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

## Para onde o jogador olha sentado (1 = direita, -1 = esquerda)
@export var lado: int = 1
## Onde o jogador (a origem dele) fica sentado e onde fica ao levantar, em relação à cadeira. Ele levanta atrás da cadeira
## (ao norte): embaixo dela só sobra uma faixa de 8 px antes da parede sul (y 112) e ao lado da cadeira direita fica a
## parede leste, então só ali tem espaço livre para os pés (círculo de 5 px)
@export var assento := Vector2(1, -9)
@export var saida := Vector2(0, -20)
## A xícara de café desta cadeira na mesa (Sprite2D): só enfeite, ganha a fumacinha
@export var cafe: NodePath
## A mesa (Sprite2D): as pernas do jogador sentado passam POR BAIXO dela. A mesa e a cadeira têm a base na mesma faixa de
## 8 px (mesmo z), então a mesa sobe uma faixa e o jogador sentado fica entre os dois: acima da cadeira, abaixo da mesa
@export var mesa: NodePath

var ocupada := false

var _jogador: Node2D

func _ready() -> void:
	super._ready()
	var xicara := get_node_or_null(cafe) as Sprite2D
	if xicara != null:
		xicara.add_child(_novo_vapor())
	var tampo := get_node_or_null(mesa) as Sprite2D
	if tampo != null:
		tampo.z_index = maxi(tampo.z_index, z_da_cadeira() + Profundidade.NIVEIS)

## Livre para sentar: ninguém nela e o jogador de pé e solto
func pode_interagir() -> bool:
	if ocupada:
		return false
	var jogador := get_tree().get_first_node_in_group("character")
	return jogador != null and jogador is CharacterBody2D and not bool(jogador.get("esta_sentado")) and bool(jogador.get("movimento_habilitado")) \
			and not bool(jogador.get("estaMorto"))

func abrir_tela() -> void:
	if pode_interagir():
		_sentar()

func fechar_tela() -> void:
	pass   # sair de perto não faz nada (não há tela)

# --- Sentar e levantar ----------------------------------------------------------------------------------------

## O z da cadeira (do profundidade_grupo: pela base dela, a 8 px dos pés da zona)
func z_da_cadeira() -> int:
	return Profundidade.z_de(global_position.y + 8.0)

func _sentar() -> void:
	_jogador = get_tree().get_first_node_in_group("character") as Node2D
	if _jogador == null:
		return
	ocupada = true
	_aviso.visible = false
	_jogador.pediu_levantar.connect(_levantar, CONNECT_ONE_SHOT)
	# Na frente do encosto (z da cadeira + 1) e atrás da mesa (que subiu uma faixa): as pernas passam por baixo dela
	_jogador.sentar(global_position + assento, lado, z_da_cadeira() + 1)

## Levantar: de pé atrás da cadeira
func _levantar() -> void:
	if not ocupada:
		return
	ocupada = false
	if is_instance_valid(_jogador):
		_jogador.levantar(global_position + saida)
	_jogador = null

# Fumacinha: pontinhos claros que sobem devagar da xícara
func _novo_vapor() -> CPUParticles2D:
	var vapor := CPUParticles2D.new()
	vapor.name = "Vapor"
	vapor.position = Vector2(0, -2)
	vapor.amount = 4
	vapor.lifetime = 1.2
	vapor.direction = Vector2.UP
	vapor.spread = 20.0
	vapor.gravity = Vector2.ZERO
	vapor.initial_velocity_min = 5.0
	vapor.initial_velocity_max = 9.0
	vapor.scale_amount_min = 1.0
	vapor.scale_amount_max = 1.0
	vapor.color = Color(1, 1, 1, 0.7)
	var some := Gradient.new()
	some.set_color(0, Color(1, 1, 1, 1))
	some.set_color(1, Color(1, 1, 1, 0))
	vapor.color_ramp = some
	vapor.z_as_relative = false
	vapor.z_index = 890
	return vapor
