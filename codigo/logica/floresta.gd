extends Node2D

## Raiz da floresta entre a vila e a fazenda (cenas/floresta.tscn, gerada por ferramentas/floresta/gerar_floresta.py): prende a
## câmera ao mapa e veste o terreno com o mesmo acabamento detalhado da fazenda (grama e terra pintadas, árvores e pedras
## nas quatro estações). Tem lago para pescar, árvores e pedras para as ferramentas e a estrada que liga a vila à fazenda.

## Retângulo do mapa em coordenadas do terreno (o gerador escreve o valor certo)
@export var limites: Rect2 = Rect2(0, 0, 1408, 864)

func _ready() -> void:
	# Presença visual de outros jogadores online (o servidor separa por mapa)
	var lobby := preload("res://codigo/cidade/lobby_cidade.gd").new()
	lobby.mapa = 2
	add_child(lobby)
	var terreno := get_node("Terrains")
	var natureza := preload("res://codigo/cenario/natureza_fazenda.gd").new()
	natureza.configurar(terreno)
	var estacoes := terreno.get_node("Estacoes")
	var chao := preload("res://codigo/cenario/chao_fazenda.gd").new()
	chao.configurar(terreno, estacoes)
	estacoes.estacao_mudou.connect(chao.aplicar)
	chao.aplicar(maxi(estacoes.estacao_atual, 0))
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

## Estação mostrada agora (a do terreno, que acompanha o calendário e a prévia do F3): as placas usam
func estacao_visual() -> int:
	var estacoes := get_node_or_null("Terrains/Estacoes")
	return int(estacoes.estacao_atual) if estacoes != null and estacoes.estacao_atual >= 0 else Calendario.estacao()
