extends AnimatedSprite2D
## Movimento autorado do novo goblin parrudo, com impacto no quadro do corte.
signal impacto_ataque
signal morte_finalizada
var _impactou := false
var _morto := false
func _ready() -> void:
	frame_changed.connect(_ao_quadro)
	animation_finished.connect(_ao_terminar)
func tocar(acao: String, direcao: String = "direita") -> void:
	if _morto: return
	var nome := acao+"_"+direcao
	if not sprite_frames.has_animation(nome): return
	if acao in ["ataque","ferido","morte"]:
		_impactou = false
		stop()
	if acao == "morte": _morto = true
	play(nome)
func reiniciar(direcao: String = "direita") -> void:
	_morto = false
	_impactou = false
	stop()
	play("parado_"+direcao)
func _ao_quadro() -> void:
	if String(animation).begins_with("ataque_") and frame == 4 and not _impactou:
		_impactou = true
		impacto_ataque.emit()
func _ao_terminar() -> void:
	if String(animation).begins_with("ataque_"):
		play("parado_"+String(animation).trim_prefix("ataque_"))
	elif String(animation).begins_with("ferido_"):
		play("parado_"+String(animation).trim_prefix("ferido_"))
	elif String(animation).begins_with("morte_"):
		morte_finalizada.emit()
