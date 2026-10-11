extends "Inimigo-base.gd"
class_name SlimeEscorregadio
var esta_atacando_atualmente = false

## Variações de cor sorteadas no spawn; preenchidas na cena com as 20 cores do pacote
@export var texturas: Array[Texture2D] = []

func _ready() -> void:
	if texturas.size() > 0:
		sprite.texture = texturas[randi() % texturas.size()]
	super()

func _physics_process(delta: float) -> void:
	super(delta)
	if esta_morto or not pode_atacar:
		return
	var alvo := obter_jogador()
	if alvo and global_position.distance_to(alvo.global_position) < alcance_ataque:
		atacar_jogador()

# O dano vem do toque (aplicar_dano_contato na base); aqui é só a animação
func atacar_jogador() -> void:
	if esta_atacando_atualmente:
		return

	esta_atacando_atualmente = true
	esta_atacando = true
	pode_atacar = false

	var dir_para_jogador := obter_jogador().global_position - global_position

	definir_animacao("attack")

	var vetor_blend = Vector2.ZERO
	if abs(dir_para_jogador.x) > abs(dir_para_jogador.y):
		vetor_blend.x = sign(dir_para_jogador.x)
	else:
		vetor_blend.y = sign(dir_para_jogador.y)

	arvore_animacao.set("parameters/attack/blend_position", vetor_blend)

	await get_tree().create_timer(0.3).timeout
	if esta_morto:
		return

	definir_animacao("run")

	await get_tree().create_timer(tempo_recarga_ataque).timeout

	pode_atacar = true
	esta_atacando = false
	esta_atacando_atualmente = false
