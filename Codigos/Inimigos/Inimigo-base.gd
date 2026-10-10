extends CharacterBody2D
class_name InimigoBase

const EfeitosLuz := preload("res://Codigos/Efeitos/efeitos_luz.gd")

# -----------------------------
# CONFIGURAÇÕES DE MOVIMENTO
# -----------------------------
@export var velocidade: int = 50
@export var aceleracao: float = 400.0
# Perto do centro do jogador o slime para de empurrar na direção dele
@export var raio_parada: float = 4.0
@export var desaceleracao_knockback: float = 900.0
# O slime tem cerca de 17 px; um alcance maior fazia a multidão se afastar demais
@export var alcance_separacao: float = 18.0
@export var forca_separacao: float = 40.0
var ultima_direcao_horizontal: float = 1.0  # 1 para direita, -1 para esquerda
## Distância da origem até os pés do sprite, para decidir se fica na frente ou atrás do jogador
@export var altura_pes: float = 5.0
# Pés do jogador ficam 11 px abaixo da origem (quadro de 64 centralizado)
const PES_JOGADOR := 11.0
const Z_ATRAS_JOGADOR := 1
# Acima das partes do jogador (até z 5) e abaixo das copas das árvores (z 10)
const Z_FRENTE_JOGADOR := 6

# -----------------------------
# CONFIGURAÇÕES DE ATAQUE
# -----------------------------
@export var tempo_recarga_ataque: float = 1.8
@export var alcance_ataque: float = 20.0   # Distância mínima para disparar a animação de ataque
var pode_atacar: bool = true
@export var dano: float = 12.0

# -----------------------------
# VARIÁVEIS DE VIDA
# -----------------------------
@export var vida: int = 30
@export var usar_barra_vida: bool = true
var esta_morto: bool = false

# -----------------------------
# ESTADOS
# -----------------------------
var esta_recuando: bool = false
var esta_atacando: bool = false

# -----------------------------
# NÓS DE ANIMAÇÃO E COLISÃO
# -----------------------------
# Opcionais: o golem anima o Sprite2D por código e não tem AnimationTree
@onready var arvore_animacao: AnimationTree = get_node_or_null("AnimationTree")
@onready var estado_animacao = arvore_animacao.get("parameters/playback") if arvore_animacao else null
@onready var posicao_blend = arvore_animacao.get("parameters/run/blend_position") if arvore_animacao else Vector2.ZERO
@onready var sprite = $Texture  # Nó do sprite para efeito de piscar

var _jogador_cache: Node2D

const COR_QUEIMANDO := Color(1.0, 0.65, 0.45)
const COR_CONGELADO := Color(0.6, 0.85, 1.0)
var _queimadura_restante := 0.0
var _queimadura_dano := 0
var _queimadura_intervalo := 0.5
var _queimadura_acumulado := 0.0
var _queimadura_cor := Color.WHITE
var _lentidao := 0.0
var _lentidao_restante := 0.0

signal atingiu_jogador
signal inimigo_morreu

func _ready() -> void:
	if arvore_animacao:
		arvore_animacao.active = true
		definir_animacao("run")

	# Chefes mostram a vida no HUD em vez da barrinha sobre a cabeça
	if usar_barra_vida and not has_node("HPBar"):
		var cena_barra_hp = preload("res://cenas/barra-de-vida.tscn")
		var instancia_barra_hp = cena_barra_hp.instantiate()
		instancia_barra_hp.name = "HPBar"
		add_child(instancia_barra_hp)
		instancia_barra_hp.position = Vector2(0, -22)

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_atualizar_ordem_desenho()

	if esta_recuando:
		velocity = velocity.move_toward(Vector2.ZERO, desaceleracao_knockback * delta)
		move_and_slide()
		return

	var desejada := calcular_separacao()
	var alvo := obter_jogador()
	if alvo:
		var para_alvo := alvo.global_position - global_position
		if para_alvo.length() > raio_parada:
			desejada += para_alvo.normalized() * velocidade * (1.0 - _lentidao)
	velocity = velocity.move_toward(desejada, aceleracao * delta)
	if velocity.length() > 1.0:
		definir_direcao_animacao(velocity)
	move_and_slide()
	aplicar_dano_contato()

# As partes do jogador usam z 2 a 5; com z fixo o inimigo ficava sempre por cima (ou sempre por baixo).
# Compara os pés dos dois: quem está mais abaixo na tela é desenhado na frente
func _atualizar_ordem_desenho() -> void:
	var jogador := obter_jogador()
	if jogador == null:
		return
	var na_frente := global_position.y + altura_pes > jogador.global_position.y + PES_JOGADOR
	z_index = Z_FRENTE_JOGADOR if na_frente else Z_ATRAS_JOGADOR

func calcular_separacao() -> Vector2:
	var vetor_repulsao := Vector2.ZERO
	for outro in get_tree().get_nodes_in_group("enemy"):
		if outro == self:
			continue
		var diff: Vector2 = global_position - outro.global_position
		var dist := diff.length()
		if dist >= alcance_separacao:
			continue
		# Slimes sobrepostos têm diff zero: sem um empurrão aleatório a normalização gera NaN
		if dist < 0.01:
			vetor_repulsao += Vector2.from_angle(randf() * TAU)
			continue
		vetor_repulsao += (diff / dist) * (1.0 - dist / alcance_separacao)
	return (vetor_repulsao * forca_separacao).limit_length(forca_separacao)

# Os i-frames do jogador impedem dano a cada frame e o empilhamento de vários slimes
func aplicar_dano_contato() -> void:
	var jogador := obter_jogador()
	if not jogador:
		return
	# O corpo do jogador é só o círculo dos pés; o dano é contra a AreaDano, do tamanho do personagem
	for area in $ataque.get_overlapping_areas():
		if area.get_parent() == jogador:
			if not jogador.invulneravel:
				atingiu_jogador.emit()
			jogador.receber_dano(obter_dano(), (jogador.global_position - global_position).normalized() * 150.0)
			return

func receber_dano(quantidade_dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if esta_morto:
		return

	vida -= quantidade_dano

	gerar_rotulo_dano(quantidade_dano)

	if has_node("HPBar"):
		get_node("HPBar").atualizar_barra(vida)

	if vida <= 0:
		morrer()
		return

	if not esta_atacando:
		definir_animacao("run")

	if forca_knockback == Vector2.ZERO:
		var jogador := obter_jogador()
		if jogador:
			forca_knockback = (global_position - jogador.global_position).normalized() * 300.0

	# A velocidade decai no _physics_process, então o slime não desliza em linha reta
	esta_recuando = true
	velocity = forca_knockback

	await get_tree().create_timer(0.2).timeout
	esta_recuando = false

	piscar_dano()

	await get_tree().create_timer(0.5).timeout
	if not esta_atacando:
		definir_animacao("run")

# Dano de encantamento (queimadura, raio): sem knockback nem piscar, senão o slime trava a cada tick
func receber_dano_efeito(quantidade_dano: int, cor: Color) -> void:
	if esta_morto:
		return
	vida -= quantidade_dano
	gerar_rotulo_dano(quantidade_dano, cor)
	if has_node("HPBar"):
		get_node("HPBar").atualizar_barra(vida)
	if vida <= 0:
		morrer()

func aplicar_queimadura(dano_tick: int, intervalo: float, duracao: float, cor: Color) -> void:
	_queimadura_dano = dano_tick
	_queimadura_intervalo = intervalo
	_queimadura_restante = duracao
	_queimadura_cor = cor

func aplicar_lentidao(fracao: float, duracao: float) -> void:
	_lentidao = maxf(_lentidao, fracao)
	_lentidao_restante = duracao

func _atualizar_efeitos(delta: float) -> void:
	if _lentidao_restante > 0.0:
		_lentidao_restante -= delta
		if _lentidao_restante <= 0.0:
			_lentidao = 0.0
	if _queimadura_restante > 0.0:
		_queimadura_restante -= delta
		_queimadura_acumulado += delta
		if _queimadura_acumulado >= _queimadura_intervalo:
			_queimadura_acumulado -= _queimadura_intervalo
			receber_dano_efeito(_queimadura_dano, _queimadura_cor)
	var tom := Color.WHITE
	if _queimadura_restante > 0.0:
		tom = COR_QUEIMANDO
	elif _lentidao_restante > 0.0:
		tom = COR_CONGELADO
	sprite.modulate = Color(tom, sprite.modulate.a)

func piscar_dano() -> void:
	for i in range(5):
		sprite.modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	EfeitosLuz.criar_flash(get_tree().current_scene, global_position, Color(0.6, 1.0, 0.6), 1.4, 0.9, 0.35)
	definir_animacao("dead")
	await get_tree().create_timer(0.2).timeout
	emit_signal("inimigo_morreu")
	queue_free()

func definir_animacao(nome_animacao: String) -> void:
	if not arvore_animacao or not estado_animacao:
		return
	if estado_animacao.get_current_node() == nome_animacao:
		return
	estado_animacao.travel(nome_animacao)

func definir_direcao_animacao(dir: Vector2) -> void:
	if not arvore_animacao:
		return
	if dir.x < 0:
		ultima_direcao_horizontal = -1.0
	elif dir.x > 0:
		ultima_direcao_horizontal = 1.0

	posicao_blend.x = ultima_direcao_horizontal
	posicao_blend.y = 0
	arvore_animacao.set("parameters/run/blend_position", posicao_blend)

func obter_dano() -> int:
	return int(dano)

func obter_jogador() -> Node2D:
	if not is_instance_valid(_jogador_cache):
		_jogador_cache = get_tree().current_scene.get_node_or_null("Jogador")
	return _jogador_cache

# -------------------------------------------------
# FUNÇÃO PARA CRIAR O TEXTO DE DANO ACIMA DO INIMIGO
# -------------------------------------------------
func gerar_rotulo_dano(valor_dano: int, cor: Color = Color.WHITE) -> void:
	var cena_rotulo = preload("res://cenas/dano-flutuante.tscn")
	var instancia_rotulo = cena_rotulo.instantiate()

	instancia_rotulo.global_position = global_position - Vector2(0, 20)

	instancia_rotulo.definir_dano(valor_dano, cor)

	get_tree().current_scene.add_child(instancia_rotulo)
