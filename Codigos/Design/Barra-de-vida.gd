extends Node2D

@export var vida_maxima: int = 30
var vida_atual: int = vida_maxima

@onready var sprite_barra: Sprite2D = $Sprite2D

# Armazena a largura original da textura
var largura_original: float = 0.0

func _ready() -> void:
	# Ativamos a região para poder recortar a textura
	sprite_barra.region_enabled = true

	# Garante que o 'region_rect' comece do tamanho total da textura
	# (supondo que sprite_barra.texture não seja null).
	if sprite_barra.texture:
		sprite_barra.region_rect.size = sprite_barra.texture.get_size()
		largura_original = sprite_barra.texture.get_size().x
	
	# Ajuste inicial (caso queira começar em 100% de vida)
	definir_vida_atual(vida_maxima)

func definir_vida_atual(valor: int) -> void:
	vida_atual = clamp(valor, 0, vida_maxima)
	# se quiser chamar atualizar_barra aqui, então passamos valor também
	atualizar_barra(valor)

func atualizar_barra(nova_vida: int) -> void:
	vida_atual = clamp(nova_vida, 0, vida_maxima)
	if not sprite_barra.texture:
		return

	var proporcao = float(vida_atual) / float(vida_maxima)
	var retangulo = sprite_barra.region_rect
	retangulo.size.x = largura_original * proporcao
	sprite_barra.region_rect = retangulo
