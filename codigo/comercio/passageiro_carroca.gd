extends Node2D

## Cópia visual da pose de sentar: não altera posição, animação nem equipamento do jogador.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
var corpo: Sprite2D
var cabelo: Sprite2D
var roupa: Sprite2D

func configurar(jogador: Node2D) -> void:
	corpo = _camada()
	cabelo = _camada()
	roupa = _camada()
	Aparencia.aplicar_corpo(corpo, "sentado", jogador.roupa_atual, jogador.pecas_cavaleiro, jogador.raizes_armadura)
	Aparencia.aplicar_cabelo(cabelo, jogador.cabelo_atual, "sentado", jogador.roupa_atual, jogador.pecas_cavaleiro, jogador.raizes_armadura)
	cabelo.modulate = jogador.cor_cabelo
	Aparencia.aplicar_roupa(roupa, jogador.roupa_atual, "sentado", jogador.pecas_cavaleiro, jogador.raizes_armadura)
	Aparencia.aplicar_cartola(cabelo, roupa, "sentado", jogador.roupa_atual, jogador.pecas_cavaleiro, jogador.raizes_armadura)
	for camada in [corpo, cabelo, roupa]:
		camada.frame = 51 # Página 4, sentado olhando para a direita.

func _camada() -> Sprite2D:
	var camada := Sprite2D.new()
	camada.hframes = 8
	camada.vframes = 8
	camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(camada)
	return camada
