extends Node2D

## Portal da arena: arco frontal4x sazonal, com nove quadros de redemoinho
## em cidade/complementos/portal/. Interagir (F/Y) abre o desafio, teleporta para a arena e
## inicia a onda. A origem do nó é a base do arco: o sprite, o brilho e a colisão se medem a partir dela.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const SombraCidade := preload("res://codigo/cidade/sombra_cidade.gd")
const InteragivelCidade := preload("res://codigo/logica/interagivel.gd")
const QUADROS := 9
const LARGURA := 48
const ALTURA := 64
## Pixels transparentes embaixo do arco na folha (o arco termina a 58 px do topo)
const BASE_NA_FOLHA := 58.0
const QUADROS_POR_SEGUNDO := 8.0
## Colisão dos pilares (o arco inteiro é mais alto que o jogador, a colisão é só o pé dele)
const COLISAO := Vector2(34, 8)
const COR_BRILHO := Color(0.55, 0.62, 1.0)

func _ready() -> void:
	z_index = Profundidade.z_de(global_position.y)
	_montar_sprite()
	SombraCidade.projetar(self, "objetos/portal", 38.0, 46.0)
	_montar_colisao()
	_montar_brilho()
	_montar_interacao()

func _montar_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Arco"
	sprite.centered = false
	sprite.offset = Vector2(-LARGURA / 2.0, -BASE_NA_FOLHA)
	add_child(sprite)
	preload("res://codigo/cidade/detalhe_ambiente.gd").instalar(self,sprite,preload("res://codigo/cidade/enfeites_detalhados.gd").dados("portal"))

func _montar_colisao() -> void:
	var corpo := StaticBody2D.new()
	corpo.name = "Colisao"
	# Mesma camada dos obstáculos da cidade
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = COLISAO
	forma.shape = retangulo
	forma.position = Vector2(0, -COLISAO.y / 2.0)
	corpo.add_child(forma)
	add_child(corpo)

## Luz do redemoinho: aparece mais à noite e pulsa devagar
func _montar_brilho() -> void:
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 128
	textura.height = 128
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1, 0.5)
	var luz := PointLight2D.new()
	luz.name = "BrilhoPortal"
	luz.texture = textura
	luz.color = COR_BRILHO
	luz.energy = 0.8
	luz.texture_scale = 1.3
	luz.position = Vector2(0, -26)
	add_child(luz)
	var pulso := luz.create_tween().set_loops()
	pulso.tween_property(luz, "energy", 1.1, 1.2).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(luz, "energy", 0.6, 1.2).set_trans(Tween.TRANS_SINE)

func _montar_interacao() -> void:
	var zona := InteragivelCidade.new()
	zona.name = "InteracaoPortal"
	zona.nome_tela = "desafio_arena"
	zona.so_entre_ondas = false
	zona.deslocamento_aviso = Vector2(0, -62)
	zona.position = Vector2(0, 6)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 30
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)
