extends Node2D

@export var velocidade_flutuacao: float = 30.0
@export var tempo_vida: float = 1.0

var tempo_vida_inicial: float

func _ready() -> void:
	tempo_vida_inicial = tempo_vida

func definir_dano(valor_dano: int, cor: Color = Color.WHITE):
	$Rotulo.text = str(valor_dano)
	$Rotulo.modulate = cor

func _process(delta: float) -> void:
	position.y -= velocidade_flutuacao * delta
	tempo_vida -= delta
	var progresso = 1.0 - (tempo_vida / tempo_vida_inicial)
	scale = Vector2(1,1).lerp(Vector2(0,0), progresso)
	if tempo_vida <= 0:
		queue_free()
