extends Area2D
class_name ProjetilJatoAgua

## Jato estreito da Válvula Errante; o aviso do inimigo antecede o projétil.
@export var velocidade := 225.0
@export var alcance := 170.0
var dano := 7
var direcao := Vector2.RIGHT
var _percorrido := 0.0
var _atingidos: Array[Node] = []

func _ready() -> void:
	direcao = direcao.normalized()
	rotation = direcao.angle()
	area_entered.connect(_ao_atingir)
	get_tree().create_timer(1.1).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var passo := velocidade * delta
	global_position += direcao * passo
	_percorrido += passo
	if _percorrido >= alcance: queue_free()

func _ao_atingir(area: Area2D) -> void:
	var alvo := area.get_parent()
	if alvo == null or _atingidos.has(alvo): return
	if not alvo.is_in_group("jogadores") or bool(alvo.get("invulneravel")): return
	_atingidos.append(alvo)
	alvo.receber_dano(dano, direcao * 120.0)
	queue_free()
