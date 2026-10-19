extends Node2D

var max_enemies: int = 110
var current_wave: int = 1
var wave_interval: float = 10.0  # Intervalo entre as waves

const Portal := preload("res://codigo/cidade/portal_arena.gd")
const CirculoProximaOnda := preload("res://codigo/logica/circulo_proxima_onda.gd")
## Onde fica o círculo da próxima onda em relação à base do portal (na praça de terra, à direita da chegada)
const DESLOCAMENTO_CIRCULO := Vector2(64, 0)

# A arena só se alcança pelo portal da cidade (Transicao.entrar_na_arena): a onda começa na chegada e, entre as ondas,
# a janela do ferreiro em modo arena (tela_mercante.gd) decide entre a próxima onda e a volta para a cidade. O portal da
# arena (onde o jogador chega) a reabre; é também por ele que o Bento entra na aula da primeira onda (aula_arena.gd).

func _ready() -> void:
	# No prólogo a sequência monta o próprio portal (PortalDoResgate), com a volta para a vila
	if not Introducao.ativa():
		_montar_portal()
		var mineracao := preload("res://codigo/logica/mineracao_arena.gd").new()
		mineracao.name = "MineracaoArena"
		add_child(mineracao)

func _montar_portal() -> void:
	var portal := Portal.new()
	portal.name = "PortalDaArena"
	var chegada: Node2D = get_node("Terrains/Chegada_portal")
	portal.position = to_local(chegada.global_position) - Vector2(0, 24)
	add_child(portal)
	var zona: Node = portal.get_node("InteracaoPortal")
	zona.nome_tela = "mercante"
	zona.so_entre_ondas = true
	var circulo := CirculoProximaOnda.new()
	circulo.name = "CirculoProximaOnda"
	circulo.position = portal.position + DESLOCAMENTO_CIRCULO
	add_child(circulo)

func start_wave() -> void:
	pass# Pode emitir um sinal ou chamar métodos em cada spawner
