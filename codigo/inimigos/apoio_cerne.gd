extends "res://codigo/inimigos/inimigo_base.gd"

## Raiz de apoio cortável, simulada apenas pelo anfitrião e sem saque da arena.
func _ready() -> void:
	eh_lacaio=true
	super()
func _physics_process(_delta: float) -> void:
	_atualizar_ordem_desenho()
func morrer() -> void:
	if esta_morto:return
	esta_morto=true
	inimigo_morreu.emit()
	queue_free()
