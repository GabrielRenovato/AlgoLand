extends AnimatedSprite2D
## Recurso direcional com pontos de impacto; o controlador de combate consome os sinais.
signal impacto_combo(golpe: int)
signal combo_encerrado
signal morte_finalizada

var _impactos_emitidos := {}
var _morto := false

func _ready() -> void:
	frame_changed.connect(_ao_quadro)
	animation_finished.connect(_ao_terminar)

func tocar(acao: String, direcao: String = "direita") -> void:
	if _morto: return
	var nome := acao + "_" + direcao
	if not sprite_frames.has_animation(nome):
		return
	if acao in ["combo","ferido","morte"]:
		_impactos_emitidos.clear()
		stop()
	if acao == "morte": _morto = true
	play(nome)

func reiniciar(direcao: String = "direita") -> void:
	_morto = false
	_impactos_emitidos.clear()
	stop()
	play("parado_"+direcao)

func _ao_quadro() -> void:
	if not String(animation).begins_with("combo_") or frame not in [1,5,9] or _impactos_emitidos.has(frame):
		return
	_impactos_emitidos[frame] = true
	impacto_combo.emit(1 + int(frame / 4))

func _ao_terminar() -> void:
	if String(animation).begins_with("combo_"):
		var direcao := String(animation).trim_prefix("combo_")
		play("parado_"+direcao)
		combo_encerrado.emit()
	elif String(animation).begins_with("ferido_"):
		play("parado_"+String(animation).trim_prefix("ferido_"))
	elif String(animation).begins_with("morte_"):
		morte_finalizada.emit()
