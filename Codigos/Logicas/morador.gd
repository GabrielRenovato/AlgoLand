extends CharacterBody2D

## Morador do acampamento: só aparece depois de contratado (Progresso) e some durante as ondas, como o mercador.
## Se tiver `nome_tela`, a zona de interação abre essa tela (ex.: a Mística).

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

@export var id_morador: String = ""
@export var textura: Texture2D
@export var quadro: int = 0
## Tela aberta ao interagir; vazio = só decoração (Curandeira e Bardo agem em segundo plano)
@export var nome_tela: String = ""

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _colisao: CollisionShape2D = $CollisionShape2D
@onready var _interacao: Area2D = $Interacao

var _em_onda: bool = false

func _ready() -> void:
	add_to_group("moradores")
	_sprite.texture = textura
	_sprite.frame = quadro
	_interacao.nome_tela = nome_tela
	Progresso.morador_contratado.connect(_ao_morador_contratado)
	_atualizar_presenca()
	_conectar_gerenciador.call_deferred()

func _conectar_gerenciador() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null:
		return
	gerenciador.onda_iniciada.connect(_ao_onda_iniciada)
	gerenciador.onda_completada.connect(_ao_onda_terminada)
	gerenciador.sinal_ondas_paradas.connect(_ao_onda_terminada.bind(0))
	_em_onda = gerenciador.onda_em_andamento
	_atualizar_presenca()

func _ao_onda_iniciada(_onda: int) -> void:
	_em_onda = true
	_atualizar_presenca()

func _ao_onda_terminada(_onda: int) -> void:
	_em_onda = false
	_atualizar_presenca()

func _ao_morador_contratado(id: String) -> void:
	if id != id_morador:
		return
	_atualizar_presenca()
	# Chegada: surge com um fade
	_sprite.modulate.a = 0.0
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 0.6)

func _atualizar_presenca() -> void:
	var presente := Progresso.tem_morador(id_morador) and not _em_onda
	visible = presente
	_colisao.set_deferred("disabled", not presente)
	_interacao.set_deferred("monitoring", presente and nome_tela != "")
