extends RefCounted

const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")

static func criar_flash(pai: Node, posicao_global: Vector2, cor: Color, energia: float, escala: float, duracao: float) -> void:
	if not is_instance_valid(pai):
		return
	var luz := PointLight2D.new()
	luz.texture = TEXTURA_LUZ
	luz.color = cor
	luz.energy = energia
	luz.texture_scale = escala
	luz.shadow_enabled = false
	pai.add_child(luz)
	luz.global_position = posicao_global
	var tween := luz.create_tween()
	tween.tween_property(luz, "energy", 0.0, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(luz.queue_free)
