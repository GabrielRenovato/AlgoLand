extends "Inimigo-base.gd"
class_name InimigoGenerico

## Variações de cor/forma da espécie; uma é sorteada no spawn
@export var texturas: Array[Texture2D] = []
@export var colunas: int = 4
@export var linhas: int = 4

## Inimigos de emboscada (flor, mímico): não perseguem, só atacam quem chega perto
@export var parado: bool = false

## Quadros de cada animação (índice = linha * colunas + coluna), pois cada folha tem seu próprio layout.
## Chaves: andar_baixo, andar_cima, andar_lado, ataque_baixo, ataque_cima, ataque_lado, morte.
## Direção que faltar usa a de lado, depois a de baixo, e por fim andar_baixo
@export var anims: Dictionary = {}
## O quadro "lado" da folha olha para a direita (espelha ao ir para a esquerda); false = olha para a esquerda
@export var lado_olha_direita: bool = true
## Espelha pelo lado do jogador também nas direções cima/baixo (folhas com uma única vista)
@export var espelhar_sempre: bool = false

@export var fps_andar: float = 8.0
@export var fps_ataque: float = 10.0
@export var fps_morte: float = 7.0

var _estado := "andar"
var _quadro := 0.0
var _direcao := "baixo"

func _ready() -> void:
	if texturas.size() > 0:
		sprite.texture = texturas[randi() % texturas.size()]
	sprite.hframes = colunas
	sprite.vframes = linhas
	super()
	_aplicar_quadro()

func _physics_process(delta: float) -> void:
	if esta_morto:
		_animar(delta)
		return
	if esta_congelado():
		_atualizar_efeitos(delta)
		velocity = Vector2.ZERO
		return
	if parado:
		_processar_parado(delta)
	else:
		super(delta)
	_animar(delta)
	if not esta_atacando and pode_atacar and not esta_atordoado():
		var alvo := obter_jogador()
		if alvo and global_position.distance_to(alvo.global_position) < alcance_ataque:
			_iniciar_ataque(alvo.global_position - global_position)

func _processar_parado(delta: float) -> void:
	_atualizar_efeitos(delta)
	_atualizar_ordem_desenho()
	var alvo := obter_jogador()
	if alvo:
		definir_direcao_animacao(alvo.global_position - global_position)
	if esta_recuando:
		velocity = velocity.move_toward(Vector2.ZERO, desaceleracao_knockback * delta)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	aplicar_dano_contato()

func _iniciar_ataque(direcao: Vector2) -> void:
	definir_direcao_animacao(direcao)
	esta_atacando = true
	pode_atacar = false
	_estado = "ataque"
	_quadro = 0.0
	await get_tree().create_timer(maxf(_frames("ataque").size() / fps_ataque, 0.2)).timeout
	if esta_morto:
		return
	esta_atacando = false
	_estado = "andar"
	await get_tree().create_timer(tempo_recarga_ataque).timeout
	pode_atacar = true

func _animar(delta: float) -> void:
	if esta_morto:
		_estado = "morte"
	var fps := fps_andar
	if _estado == "ataque":
		fps = fps_ataque
	elif _estado == "morte":
		fps = fps_morte
	_quadro += fps * delta
	_aplicar_quadro()

func _frames(prefixo: String) -> Array:
	var chave := prefixo + "_" + _direcao
	if anims.has(chave):
		return anims[chave]
	for reserva in ["_lado", "_baixo"]:
		if anims.has(prefixo + reserva):
			return anims[prefixo + reserva]
	return anims.get("andar_baixo", [0])

func _aplicar_quadro() -> void:
	var quadros: Array
	match _estado:
		"morte":
			quadros = anims.get("morte", [0])
		"ataque":
			quadros = _frames("ataque")
		_:
			quadros = _frames("andar")
	var n := quadros.size()
	var i := int(_quadro)
	i = i % n if _estado == "andar" else mini(i, n - 1)
	sprite.frame = quadros[i]
	sprite.flip_h = _deve_espelhar()

func _deve_espelhar() -> bool:
	if _estado == "morte":
		return false
	if _direcao != "lado" and not espelhar_sempre:
		return false
	var indo_direita := ultima_direcao_horizontal > 0.0
	return not indo_direita if lado_olha_direita else indo_direita

# Escolhe entre baixo/cima/lado pelo eixo dominante; a folga evita ficar trocando de vista na diagonal
func _escolher_direcao(dir: Vector2) -> void:
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if ax + ay < 0.01:
		return
	if ax > ay * (0.7 if _direcao == "lado" else 1.4):
		_direcao = "lado"
	else:
		_direcao = "baixo" if dir.y > 0.0 else "cima"

# A animação é controlada por _estado/_animar; aqui não há AnimationTree
func definir_animacao(_nome_animacao: String) -> void:
	pass

func definir_direcao_animacao(dir: Vector2) -> void:
	# Durante o ataque o bicho mantém a vista com que começou o golpe
	if esta_atacando:
		return
	if dir.x < 0.0:
		ultima_direcao_horizontal = -1.0
	elif dir.x > 0.0:
		ultima_direcao_horizontal = 1.0
	_escolher_direcao(dir)

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	_limpar_gelo_morte()
	_tocar_som_morte()
	_ao_morrer_chefe()
	_estado = "morte"
	_quadro = 0.0
	EfeitosLuz.criar_flash(get_tree().current_scene, global_position, Color(0.6, 1.0, 0.6), 1.4, 0.9, 0.35)
	await get_tree().create_timer(maxf(anims.get("morte", [0]).size() / fps_morte, 0.2)).timeout
	emit_signal("inimigo_morreu")
	queue_free()
