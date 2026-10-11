extends Node

## Acompanha se o jogador está no controle ou no teclado/mouse (o último que foi usado).
## As telas usam isso para dar foco automático aos botões só para quem joga no controle,
## e o cursor do mouse some enquanto o controle está em uso.

signal modo_alterado(usando_controle: bool)

## Inclinação mínima do analógico/gatilho para contar como uso do controle
const ZONA_MORTA := 0.4
## Movimento mínimo do mouse (px) para voltar ao modo teclado/mouse
const MOVIMENTO_MOUSE := 2.0

var usando_controle := false

func _input(evento: InputEvent) -> void:
	var do_controle: bool = evento is InputEventJoypadButton \
			or (evento is InputEventJoypadMotion and absf(evento.axis_value) > ZONA_MORTA)
	var do_teclado: bool = evento is InputEventKey or evento is InputEventMouseButton \
			or (evento is InputEventMouseMotion and evento.relative.length() > MOVIMENTO_MOUSE)
	if do_controle and not usando_controle:
		_definir(true)
	elif do_teclado and usando_controle:
		_definir(false)

func _definir(valor: bool) -> void:
	usando_controle = valor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if valor else Input.MOUSE_MODE_VISIBLE
	modo_alterado.emit(valor)

## Dá foco ao nó só quando o jogador está no controle (no mouse/teclado nada muda)
func focar(no: Control) -> void:
	if usando_controle and is_instance_valid(no) and no.is_visible_in_tree():
		no.grab_focus()
