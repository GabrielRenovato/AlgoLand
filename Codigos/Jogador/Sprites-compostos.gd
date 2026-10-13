extends Node
class_name Composto

## Folhas de andar do corpo, de cada cabelo e de cada roupa (a lista completa fica em Codigos/DadosLocais/aparencia.gd)
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")

var folha_sprite_corpo = {}
var folha_sprite_cabelo = {}
var folha_sprite_roupa = {}

func _init():
	folha_sprite_corpo = {
		0: load("res://CharacterSprites/Body/body_1.png"),
	}
	for i in Aparencia.total_cabelos():
		folha_sprite_cabelo[i] = Aparencia.cabelo(i, "andar")
	for i in Aparencia.total_roupas():
		folha_sprite_roupa[i] = Aparencia.roupa(i, "andar")
