extends "inimigo_generico.gd"

const Projetil := preload("res://codigo/inimigos/projetil_esqueleto.gd")
@export_enum("contato", "flecha", "magia") var tipo_ataque := "contato"
var _distancia_combate := 0.0
const DISTANCIA_POR_QUADRO := 8.0

func _ready() -> void:
	_distancia_combate = raio_parada
	super()
	# A base circular serve para andar. Cabeça e tronco também recebem a lâmina.
	var atingivel := Area2D.new()
	atingivel.name = "AreaDano"
	atingivel.collision_layer = 4
	atingivel.collision_mask = 0
	atingivel.monitoring = false
	atingivel.add_to_group("hurtbox_inimigo")
	var forma := CollisionShape2D.new()
	var corpo := CapsuleShape2D.new()
	corpo.radius = 6.0
	corpo.height = 32.0
	forma.shape = corpo
	atingivel.add_child(forma)
	add_child(atingivel)

func _physics_process(delta: float) -> void:
	if tipo_ataque != "contato" and not esta_morto:
		var alvo := obter_jogador()
		# Aproxima-se se houver um obstáculo na linha de tiro, em vez de ficar parado atrás dele.
		raio_parada = _distancia_combate if alvo != null and _tem_visada(alvo) else 7.0
	super(delta)

func _animar(delta: float) -> void:
	if esta_morto or _estado != "andar":
		super(delta)
		return
	var deslocamento := get_real_velocity().length() * delta
	if get_real_velocity().length() < 1.5:
		# Terceiro quadro da caminhada é a passagem, com os pés apoiados.
		_quadro = 2.0
	else:
		_quadro += deslocamento / (DISTANCIA_POR_QUADRO * maxf(scale.x, 1.0))
	_aplicar_quadro()

func _tem_visada(alvo: Node2D) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, alvo.global_position, 64)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func _iniciar_ataque(direcao: Vector2) -> void:
	if esta_morto or esta_atordoado():
		return
	if tipo_ataque == "contato":
		super(direcao)
		return
	var alvo := obter_jogador()
	if alvo == null or not _tem_visada(alvo):
		return
	var destino := alvo.global_position
	super(direcao)
	# Solta o disparo no terceiro quadro (o impacto), mirando onde o jogador estava na preparação.
	await get_tree().create_timer(2.0 / fps_ataque).timeout
	if esta_morto or esta_atordoado() or not is_instance_valid(alvo):
		return
	var disparo := Projetil.new()
	disparo.tipo = tipo_ataque
	disparo.dano = obter_dano()
	disparo.alvo = alvo
	disparo.origem = global_position
	disparo.destino = destino
	# O ataque pendente sai junto com seu dono ao pular a onda ou derrotá-lo.
	add_child(disparo)
