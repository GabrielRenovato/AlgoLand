@tool
extends Node2D

## Construção editável: cada camada pode ser pintada no editor usando o TileSet novo.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
@export var area_visual := Rect2(-120, -144, 240, 144)

func _ready() -> void:
	if not Engine.is_editor_hint():
		z_as_relative = false
		z_index = Profundidade.z_de(global_position.y)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var jogador := get_tree().get_first_node_in_group("character") as Node2D
	if jogador == null:
		return
	var ponto := to_local(jogador.global_position + Vector2(0, 11))
	var atras := ponto.y < 0 and area_visual.has_point(ponto)
	modulate.a = move_toward(modulate.a, 0.5 if atras else 1.0, delta * 6)
