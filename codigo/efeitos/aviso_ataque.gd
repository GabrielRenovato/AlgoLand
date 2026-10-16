extends Node2D

## Um único tile repetido, recortado pela área real de qualquer habilidade.
var _superficie: Polygon2D

func _ready() -> void:
	_superficie = Polygon2D.new()
	_superficie.texture = load("res://assets/efeitos/avisos/perigo.png")
	_superficie.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_superficie.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var material_aviso := CanvasItemMaterial.new()
	material_aviso.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_superficie.material = material_aviso
	add_child(_superficie)

func definir_area(pontos: PackedVector2Array) -> void:
	if pontos.size() < 3 or Geometry2D.triangulate_polygon(pontos).is_empty():
		_superficie.polygon = PackedVector2Array()
		return
	_superficie.polygon = pontos
	# UV em pixels do mundo evita esticar o tile em círculos, cones e áreas grandes.
	_superficie.uv = global_transform * pontos

func animar(relogio: float, em_impacto: bool = false) -> void:
	_superficie.self_modulate.a = 0.6 if em_impacto else 0.65 + 0.2 * sin(relogio * 8)
