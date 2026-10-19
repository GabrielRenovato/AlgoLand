extends CharacterBody2D

## Orion usa quadros de 64px, com mão e cajado integrados à pose em cada direção.
const FOLHA := preload("res://assets/npcs/fendas/orion.png")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var gerente: Node
var sprite: Sprite2D
var interacao: Area2D
var _tempo := 0.0

class InteracaoGuia extends "res://codigo/logica/interagivel.gd":
	func pode_interagir_para(jogador: Node2D) -> bool:
		var guia := get_parent()
		return is_instance_valid(guia.gerente) and guia.gerente.etapa==guia.gerente.Etapa.CONCLUIDO and super.pode_interagir_para(jogador)

func _ready() -> void:
	name = "GuiaDoAndar"
	add_to_group("guias_andar")
	collision_layer = 32
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = FOLHA
	sprite.hframes = 7
	sprite.vframes = 4
	sprite.position.y = -3
	add_child(sprite)
	preload("res://codigo/cidade/sombra_cidade.gd").contato(self,17,3,Vector2(0,10))
	var forma := CollisionShape2D.new()
	var corpo := CapsuleShape2D.new()
	corpo.radius = 5
	corpo.height = 12
	forma.shape = corpo
	forma.position.y = 9
	add_child(forma)
	interacao = InteracaoGuia.new()
	interacao.name = "ConversaOrion"
	interacao.nome_tela = "mercante"
	interacao.deslocamento_aviso = Vector2(0,-38)
	add_child(interacao)
	var alcance := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 42
	alcance.shape = circulo
	interacao.add_child(alcance)
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y+9)

func _process(delta: float) -> void:
	_tempo += delta
	var jogador := Cooperativo.jogador_no_ambiente(self)
	if jogador != null:
		var rumo: Vector2 = jogador.global_position-global_position
		var linha := (1 if rumo.x>0 else 3) if absf(rumo.x)>absf(rumo.y) else (0 if rumo.y>=0 else 2)
		sprite.frame = linha*7
	queue_redraw()

func _draw() -> void:
	if _tempo<1.2:
		for i in 8:
			var p := (Vector2.from_angle(i*TAU/8+_tempo)*Vector2(18,7)).round()+Vector2(0,9)
			draw_rect(Rect2(p,Vector2.ONE),Color(.6,.9,.7,1-_tempo/1.2))
