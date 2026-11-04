extends AnimatedSprite2D
## Recurso visual independente; a IA escolhe a ação e mantém o corpo físico separado.
var _registro: Dictionary

func _ready() -> void:
	_registro = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblins_moinho/lanceiro/registro.json"))
	animation_changed.connect(_aplicar_registro)
	_aplicar_registro()

func tocar(acao: String, direcao: String) -> void:
	var nome := acao + "_" + direcao
	if sprite_frames.has_animation(nome):
		play(nome)

func _aplicar_registro() -> void:
	var ficha: Dictionary = _registro.get(String(animation), {})
	offset = Vector2(0, -96)
	scale = Vector2.ONE * float(ficha.get("escala", 0.26))
	flip_h = false
	flip_v = false
