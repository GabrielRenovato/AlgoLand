extends SubViewportContainer

## Uma metade da tela dividida do cooperativo (Cooperativo.gd): mostra o mesmo mundo com a câmera de um jogador e a
## interface (HUD e telas) dele. A do jogador 1 repassa a entrada normal (teclado, mouse e o controle dele); a do
## jogador 2 não repassa nada sozinha: o Cooperativo empurra só os eventos do controle do jogador 2 para ela.

var repassar_entrada := true

func _propagate_input_event(_evento: InputEvent) -> bool:
	return repassar_entrada
