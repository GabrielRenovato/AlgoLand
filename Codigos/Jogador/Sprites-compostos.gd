extends Node
class_name Composto

var folha_sprite_corpo = {}
var folha_sprite_cabelo = {}
var folha_sprite_roupa = {}

func _init():
	# Inicializa o folha_sprite_corpo (exemplo)
	folha_sprite_corpo = {
		0: load("res://CharacterSprites/Body/body_1.png"),
	}
	
	# Supondo que você tenha arquivos de hair (1).png até hair (107).png
	for i in range(1, 3):  # i vai de 1 até 107
		var recurso = load("res://CharacterSprites/Hair/hair (" + str(i) + ").png")
		if recurso:
			# Se quiser que hair(1).png fique na chave 0, use i - 1
			folha_sprite_cabelo[i - 1] = recurso
		else:
			print("Não foi possível carregar: res://CharacterSprites/Hair/hair (" + str(i) + ").png")
			
	for i in range(1, 13):  # i vai de 1 até 107
		var recurso = load("res://CharacterSprites/Outfit/outfit (" + str(i) + ").png")
		if recurso:
			# Se quiser que hair(1).png fique na chave 0, use i - 1
			folha_sprite_roupa[i - 1] = recurso
		else:
			print("Não foi possível carregar: res://CharacterSprites/Outfit/outfit (" + str(i) + ").png")
