extends Node2D

## Raiz da cena da fazenda (cenas/fazenda.tscn, gerada por ferramentas/fazenda/gerar_fazenda.py): prende a câmera
## ao mapa, para a tela nunca mostrar o vazio além da borda da grama. A casa (casa.tscn) não precisa disso: o cômodo
## é menor que a tela e fica cercado de escuro.

## Retângulo do mapa em coordenadas do terreno (o gerador escreve o valor certo)
@export var limites: Rect2 = Rect2(0, 0, 960, 672)

func _ready() -> void:
	var jogador := get_node_or_null("Jogador")
	if jogador == null or jogador.get("camera") == null:
		return
	var canto := to_global(limites.position)
	var camera: Camera2D = jogador.camera
	camera.limit_left = int(canto.x)
	camera.limit_top = int(canto.y)
	camera.limit_right = int(canto.x + limites.size.x)
	camera.limit_bottom = int(canto.y + limites.size.y)
	camera.reset_smoothing()
