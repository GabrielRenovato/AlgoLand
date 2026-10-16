extends Area2D

# Flecha disparada pelo arco. Os golpes passam pelo jogador (aplicar_golpe)
# para que dano, crítico, roubo de vida e encantamentos valham também à distância.

const ObjetosRefinados := preload("res://codigo/dados/objetos_refinados.gd")
const TEXTURA := preload("res://assets/personagens/Arco/flecha.png")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const VELOCIDADE := 320.0
const ALCANCE := 280.0
const CAMADA_INIMIGOS := 4
const CAMADA_MUNDO := 64

var _direcao: Vector2 = Vector2.RIGHT
var _jogador: Node = null
var _percorrido: float = 0.0
var _acertou: bool = false

func _init() -> void:
	collision_layer = 0
	collision_mask = CAMADA_INIMIGOS | CAMADA_MUNDO
	monitorable = false
	var forma := CircleShape2D.new()
	forma.radius = 3.0
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	add_child(colisao)
	var sprite := Sprite2D.new()
	ObjetosRefinados.aplicar(sprite, TEXTURA)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	body_entered.connect(_ao_alvo_entrar)
	area_entered.connect(_ao_alvo_entrar)

func iniciar(jogador: Node, direcao: Vector2) -> void:
	_jogador = jogador
	_direcao = direcao.normalized()
	# O sprite da flecha aponta para a esquerda
	rotation = _direcao.angle() + PI

func _physics_process(delta: float) -> void:
	var passo := VELOCIDADE * delta
	global_position += _direcao * passo
	# A flecha sai na altura do peito: os "pés" dela ficam um pouco abaixo
	z_index = Profundidade.z_de(global_position.y + 10.0) + Profundidade.NIVEIS - 1
	_percorrido += passo
	if _percorrido >= ALCANCE:
		queue_free()

func _ao_alvo_entrar(alvo: Node) -> void:
	if _acertou:
		return
	if alvo.is_in_group("hurtbox_inimigo"):
		alvo = alvo.get_parent()
		if not is_instance_valid(alvo):
			return
	if not alvo.is_in_group("enemy"):
		# Qualquer outra coisa nas camadas de máscara é parede/obstáculo
		_acertou = true
		queue_free()
		return
	# Inimigo já morto não bloqueia a flecha
	if "esta_morto" in alvo and alvo.esta_morto:
		return
	_acertou = true
	if is_instance_valid(_jogador):
		_jogador.aplicar_golpe(alvo, _direcao)
	queue_free()
