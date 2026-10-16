extends Node
class_name Composto

## Folhas de andar do corpo, de cada cabelo e de cada roupa (a lista completa fica em codigo/dados/aparencia.gd)
const Aparencia := preload("res://codigo/dados/aparencia.gd")

var folha_sprite_corpo = {}
var folha_sprite_cabelo = {}
var folha_sprite_roupa = {}

func _init():
	folha_sprite_corpo = {
		0: Aparencia.corpo("andar", 0, 0),
	}
	for i in Aparencia.total_cabelos():
		folha_sprite_cabelo[i] = Aparencia.cabelo_refinado(i, "andar")
	for i in Aparencia.total_roupas():
		folha_sprite_roupa[i] = Aparencia.roupa_refinada(i, "andar")
