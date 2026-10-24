extends Node2D

## Cantinhos da floresta (cenas/terreno_floresta.tscn, gerada por ferramentas/floresta/gerar_floresta.py): o cantinho de pesca
## do lago e o acampamento dos lenhadores. Reaproveita os móveis do cais da praia (banco em que se senta, suporte de varas,
## caixas de peixe, com colisão) e a biblioteca 4× sazonal da praia para os adornos soltos (troncos, capim, pedras).
const MobiliarioCais := preload("res://codigo/pesca/mobiliario_cais.gd")
const ArtePraia := preload("res://codigo/pesca/arte_praia.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")

## [tipo, x, y]: móveis do cais (tipos de MobiliarioCais)
@export var moveis: Array = []
## [tipo, x, y, largura_da_colisao, altura_da_colisao]: adornos sazonais soltos; colisão 0 = só visual
@export var adornos: Array = []

func _ready() -> void:
	z_as_relative = false
	MobiliarioCais.montar(self, moveis)
	var corpo := StaticBody2D.new()
	corpo.name = "ColisaoAdornos"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	for item: Array in adornos:
		var base := Vector2(float(item[1]), float(item[2]))
		var no := Node2D.new()
		no.name = "%s_%d_%d" % [item[0], int(base.x), int(base.y)]
		no.position = base
		no.z_index = Profundidade.z_de(base.y)
		add_child(no)
		var sprite := Sprite2D.new()
		sprite.centered = false
		no.add_child(sprite)
		ArtePraia.aplicar(sprite, String(item[0]), no)
		if float(item[3]) > 0.0:
			var forma := CollisionShape2D.new()
			var caixa := RectangleShape2D.new()
			caixa.size = Vector2(float(item[3]), float(item[4]))
			forma.shape = caixa
			forma.position = base - Vector2(0, caixa.size.y / 2.0)
			corpo.add_child(forma)
