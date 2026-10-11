extends Node2D

signal personalizacao_finalizada(indice_cabelo: int, indice_roupa: int, cor: Color, apelido: String)

var cor_cabelo: Color = Color(1, 1, 1, 1)
var apelido: String = ""
var cabelo_atual: int = 0
var roupa_atual: int = 0

# Arrays de texturas para cada tipo de cabelo/roupa
var sprites_cabelo: Array[Texture2D] = []
var sprites_roupa: Array[Texture2D] = []

@onready var sprite_cabelo: Sprite2D = $Cabelo
@onready var sprite_roupa: Sprite2D = $Roupa

func _ready() -> void:
	# 1) Carrega as sprites de cabelo (exemplo de 1 a 27)
	for i in range(1, 3):
		var caminho_cabelo = "res://CharacterSprites/Hair/hair (%d).png" % i
		var recurso_cabelo = load(caminho_cabelo)
		if recurso_cabelo:
			sprites_cabelo.append(recurso_cabelo)
	
	# 2) Carrega as sprites de roupa (exemplo de 1 a 8)
	for i in range(1, 13):
		var caminho_roupa = "res://CharacterSprites/Outfit/outfit (%d).png" % i
		var recurso_roupa = load(caminho_roupa)
		if recurso_roupa:
			sprites_roupa.append(recurso_roupa)

	# (Opcional) Se quiser também arrays para "array_ataque_cabelo" ou "array_ataque_roupa",
	# faça do mesmo jeito, mas lembre que, na personalização, geralmente basta ver a sprite "idle".

	# Por fim, atualiza a aparência inicial
	atualizar_visuais()

# ---------------------------
# TROCA DE COR
# ---------------------------
func definir_cor_cabelo(nova_cor: Color) -> void:
	cor_cabelo = nova_cor
	if sprite_cabelo:
		sprite_cabelo.modulate = nova_cor

# ---------------------------
# TROCA DE CABELO
# ---------------------------
func trocar_cabelo_avancar() -> void:
	if sprites_cabelo.size() > 0:
		cabelo_atual = (cabelo_atual + 1) % sprites_cabelo.size()
		atualizar_visuais()

func trocar_cabelo_voltar() -> void:
	if sprites_cabelo.size() > 0:
		cabelo_atual = (cabelo_atual - 1) % sprites_cabelo.size()
		if cabelo_atual < 0:
			cabelo_atual = sprites_cabelo.size() - 1
		atualizar_visuais()

# ---------------------------
# TROCA DE ROUPA
# ---------------------------
func trocar_roupa_avancar() -> void:
	if sprites_roupa.size() > 0:
		roupa_atual = (roupa_atual + 1) % sprites_roupa.size()
		atualizar_visuais()

func trocar_roupa_voltar() -> void:
	if sprites_roupa.size() > 0:
		roupa_atual = (roupa_atual - 1) % sprites_roupa.size()
		if roupa_atual < 0:
			roupa_atual = sprites_roupa.size() - 1
		atualizar_visuais()

# ---------------------------
# DEFINIR APELIDO
# ---------------------------
func definir_apelido(novo_apelido: String) -> void:
	apelido = novo_apelido

# ---------------------------
# ATUALIZAR SPRITES
# ---------------------------
func atualizar_visuais() -> void:
	# Se tiver cabelo no array, atualiza sprite
	if sprites_cabelo.size() > 0 and cabelo_atual < sprites_cabelo.size():
		sprite_cabelo.texture = sprites_cabelo[cabelo_atual]

	# Se tiver roupa no array, atualiza sprite
	if sprites_roupa.size() > 0 and roupa_atual < sprites_roupa.size():
		sprite_roupa.texture = sprites_roupa[roupa_atual]

	# Aplica a cor no cabelo
	sprite_cabelo.modulate = cor_cabelo

# ---------------------------
# SALVAR PERSONALIZAÇÃO
# ---------------------------
func salvar_personalizacao():
	emit_signal("personalizacao_finalizada", cabelo_atual, roupa_atual, cor_cabelo, apelido)
