extends "res://codigo/inimigos/inimigo_generico.gd"
class_name InimigoBacia

## Golpes próprios das três espécies da Bacia do Moinho.
## Folhas direcionais separam antecipação, impacto e recuperação; o estado impede loop.
@export_enum("arraia", "besouro", "valvula") var especie := "arraia"
## Folhas complementares 2D; atlas originais preservados como reserva.
@export var folha_ataque: Texture2D
@export var pivo_ataque := Vector2(256, 448)
@export var proporcao_ataque := 1.0
@export var folhas_ataque_direcionais: Dictionary = {}
@export var registro_ataque_direcional: Dictionary = {}
@export var folha_andar_cima: Texture2D
@export var pivo_andar_cima := Vector2(256, 448)
@export var proporcao_andar_cima := 0.83
@export var pivos_andar: Dictionary = {}

const ProjetilJato := preload("res://cenas/inimigos/projetil_jato_agua.tscn")
const TEMPO_ARRAIA := 0.76
const TEMPO_BESOURO := 1.08
const TEMPO_VALVULA := 0.86

var _golpe_ativo := false
var _tempo_golpe := 0.0
var _direcao_golpe := Vector2.RIGHT
var _tempo_recarga := 0.0
var _acertados: Array[Node] = []
var _jato_disparado := false
var _aviso_golpe: Line2D
var _area_golpe: Area2D
var _escala_arte := Vector2.ONE
var _posicao_arte := Vector2.ZERO
var _tempo_morte := 0.0
var _quadro_morte := -1
var _espelho_morte := false
var _folha_andar: Texture2D
var _offset_arte := Vector2.ZERO
var _escala_morte := Vector2.ONE

func _ready() -> void:
	_escala_arte = sprite.scale
	_posicao_arte = sprite.position
	_folha_andar = sprite.texture
	_offset_arte = sprite.offset
	super()
	_area_golpe = get_node_or_null("ataque") as Area2D
	if _area_golpe != null:
		_area_golpe.monitoring = false
		_area_golpe.monitorable = false
	_aviso_golpe = Line2D.new()
	_aviso_golpe.name = "AvisoDoGolpe"
	_aviso_golpe.width = 3.0
	_aviso_golpe.default_color = Color("ffb96c")
	_aviso_golpe.z_index = -1
	_aviso_golpe.visible = false
	# A mira parte do centro do corpo; não dos pés que ancoram o sprite.
	var forma := get_node_or_null("colision_body") as CollisionShape2D
	if forma != null and forma.shape != null:
		_aviso_golpe.position = forma.position + forma.shape.get_rect().get_center()
	_aviso_golpe.add_point(Vector2.ZERO)
	var alcance_aviso := 198.0 if especie == "valvula" else (205.0 * .23 + 14.0 if especie == "arraia" else 245.0 * .37 + 18.0)
	_aviso_golpe.add_point(Vector2.RIGHT * alcance_aviso / maxf(absf(global_scale.x), .001))
	add_child(_aviso_golpe)

func _physics_process(delta: float) -> void:
	if esta_morto:
		_animar_morte(delta)
		return
	if esta_congelado():
		if _golpe_ativo: _finalizar_golpe()
		if _area_golpe != null: _area_golpe.monitoring = false
		velocity = Vector2.ZERO
		_atualizar_efeitos(delta)
		return
	if _golpe_ativo:
		# Queimadura e duração dos estados continuam correndo durante a animação.
		_atualizar_efeitos(delta)
		if esta_morto: return
		if esta_atordoado() or esta_recuando:
			var recuo := velocity
			_finalizar_golpe()
			_atordoado = maxf(0.0, _atordoado - delta)
			velocity = recuo.move_toward(Vector2.ZERO, desaceleracao_knockback * delta)
			move_and_slide()
			_aplicar_quadro()
			_atualizar_ordem_desenho()
			return
		_atualizar_golpe(delta)
		return
	_tempo_recarga = maxf(_tempo_recarga - delta, 0.0)
	if _tempo_recarga == 0.0: pode_atacar = true
	super(delta)

func _iniciar_ataque(direcao: Vector2) -> void:
	if _golpe_ativo or _tempo_recarga > 0.0 or esta_morto or esta_atordoado() or esta_recuando: return
	_direcao_golpe = direcao.normalized()
	if especie == "valvula":
		var alvo := obter_jogador()
		if is_instance_valid(alvo):
			_direcao_golpe = (_centro_do_alvo(alvo) - to_global(_aviso_golpe.position)).normalized()
	if _direcao_golpe == Vector2.ZERO: _direcao_golpe = Vector2.RIGHT
	definir_direcao_animacao(_direcao_golpe)
	esta_atacando = true
	pode_atacar = false
	_golpe_ativo = true
	_tempo_golpe = 0.0
	_jato_disparado = false
	_acertados.clear()
	velocity = Vector2.ZERO
	_estado = "ataque"
	_quadro = 0.0
	_aviso_golpe.rotation = _direcao_golpe.angle()
	_aviso_golpe.visible = true

func _atualizar_golpe(delta: float) -> void:
	_tempo_golpe += delta
	var duracao := TEMPO_ARRAIA if especie == "arraia" else (TEMPO_BESOURO if especie == "besouro" else TEMPO_VALVULA)
	_quadro = _quadro_da_fase()
	_aplicar_quadro()
	# Cada vista tem desenhos próprios; só a lateral esquerda usa espelhamento.
	sprite.flip_h = _direcao == "lado" and ultima_direcao_horizontal < 0.0
	sprite.rotation = 0.0
	_atualizar_ordem_desenho()
	match especie:
		"arraia": _golpe_arraia()
		"besouro": _golpe_besouro()
		"valvula": _golpe_valvula()
	if _tempo_golpe >= duracao:
		_finalizar_golpe()

func _quadro_da_fase() -> float:
	var marcos: Array[float]
	if folha_ataque != null and especie == "arraia":
		marcos = [0.10, 0.20, 0.30, 0.38, 0.46, 0.53, 0.65, TEMPO_ARRAIA]
	elif folha_ataque != null and especie == "besouro":
		marcos = [0.14, 0.28, 0.42, 0.53, 0.65, 0.79, 0.94, TEMPO_BESOURO]
	elif folha_ataque != null:
		marcos = [0.12, 0.24, 0.36, 0.48, 0.55, 0.62, 0.74, TEMPO_VALVULA]
	elif especie == "arraia":
		marcos = [0.30, 0.38, 0.53, TEMPO_ARRAIA]
	elif especie == "besouro":
		marcos = [0.42, 0.55, 0.79, TEMPO_BESOURO]
	else:
		marcos = [0.24, 0.48, 0.62, TEMPO_VALVULA]
	for i in marcos.size():
		if _tempo_golpe < marcos[i]:
			var inicio := 0.0 if i == 0 else marcos[i - 1]
			return float(i) + clampf((_tempo_golpe - inicio) / maxf(marcos[i] - inicio, 0.001), 0.0, 0.99)
	return float(marcos.size() - 1)

func _golpe_arraia() -> void:
	# 0–0,30s prepara; 0,30–0,52s dá o bote; o resto é recuperação.
	if _tempo_golpe < 0.30:
		velocity = Vector2.ZERO
		_aviso_golpe.visible = true
		move_and_slide()
		return
	_aviso_golpe.visible = false
	if _tempo_golpe < 0.53:
		velocity = _direcao_golpe * 205.0
		if _area_golpe != null: _area_golpe.monitoring = true
		move_and_slide()
		_aplicar_golpe_em_areas()
		return
	velocity = velocity.move_toward(Vector2.ZERO, 950.0 * get_physics_process_delta_time())
	if _area_golpe != null: _area_golpe.monitoring = false
	move_and_slide()

func _golpe_besouro() -> void:
	# Aviso mais longo; o besouro vira uma bola pesada e percorre uma distância maior.
	if _tempo_golpe < 0.42:
		velocity = Vector2.ZERO
		_aviso_golpe.visible = true
		move_and_slide()
		return
	_aviso_golpe.visible = false
	if _tempo_golpe < 0.79:
		velocity = _direcao_golpe * 245.0
		if _area_golpe != null: _area_golpe.monitoring = true
		move_and_slide()
		_aplicar_golpe_em_areas()
		return
	velocity = velocity.move_toward(Vector2.ZERO, 1050.0 * get_physics_process_delta_time())
	if _area_golpe != null: _area_golpe.monitoring = false
	move_and_slide()

func _golpe_valvula() -> void:
	# O traço de mira e o brilho do núcleo avisam antes do jato atravessar a linha.
	velocity = Vector2.ZERO
	move_and_slide()
	if _tempo_golpe < 0.48:
		_aviso_golpe.visible = true
		return
	if _tempo_golpe >= 0.48 and not _jato_disparado:
		_jato_disparado = true
		_aviso_golpe.visible = false
		var jato := ProjetilJato.instantiate() as ProjetilJatoAgua
		jato.dano = roundi(obter_dano())
		jato.direcao = _direcao_golpe
		get_tree().current_scene.add_child(jato)
		jato.global_position = to_global(_aviso_golpe.position) + _direcao_golpe * 28.0

func _aplicar_golpe_em_areas() -> void:
	if _area_golpe == null or not _em_impacto(): return
	for area in _area_golpe.get_overlapping_areas():
		var alvo := area.get_parent()
		if alvo == null or _acertados.has(alvo): continue
		if not alvo.is_in_group("jogadores") and alvo != obter_jogador(): continue
		if bool(alvo.get("invulneravel")): continue
		_acertados.append(alvo)
		alvo.receber_dano(obter_dano(), _direcao_golpe * 175.0)
		atingiu_jogador.emit()

## A área de ataque fica desligada fora dos quadros de impacto.
func aplicar_dano_contato() -> void:
	if _em_impacto(): _aplicar_golpe_em_areas()

func _em_impacto() -> bool:
	if not _golpe_ativo or esta_morto or esta_atordoado() or especie == "valvula": return false
	var inicio := 0.30 if especie == "arraia" else 0.42
	var fim := 0.53 if especie == "arraia" else 0.79
	return _tempo_golpe >= inicio and _tempo_golpe < fim

func _animar(delta: float) -> void:
	if especie == "besouro" and not esta_atacando and velocity.length_squared() < 1.0:
		_quadro = 0.0
		_aplicar_quadro()
		return
	if _direcao == "cima" and folha_andar_cima != null and not esta_atacando:
		# Oito desenhos mantêm a duração da passada original de quatro quadros.
		_quadro += fps_andar * 2.0 * delta
		_aplicar_quadro()
		return
	super(delta)

func _aplicar_quadro() -> void:
	if _estado == "ataque" and not esta_morto and folha_ataque != null:
		var folha: Texture2D = folhas_ataque_direcionais.get(_direcao, folha_ataque)
		var registro: Dictionary = registro_ataque_direcional.get(_direcao, {})
		var pivo: Vector2 = registro.get("pivo", pivo_ataque)
		var proporcao: float = registro.get("proporcao", proporcao_ataque)
		sprite.texture = folha
		sprite.hframes = 4
		sprite.vframes = 2
		sprite.offset = Vector2(folha.get_size() / Vector2(4, 2)) * .5 - pivo
		sprite.scale = _escala_arte * proporcao
		sprite.frame = clampi(int(_quadro), 0, 7)
		sprite.flip_h = _direcao == "lado" and ultima_direcao_horizontal < 0.0
		return
	if _direcao == "cima" and folha_andar_cima != null:
		sprite.texture = folha_andar_cima
		sprite.hframes = 4
		sprite.vframes = 2
		sprite.offset = Vector2(256, 256) - pivo_andar_cima
		sprite.scale = _escala_arte * proporcao_andar_cima
		sprite.frame = 0 if esta_morto else int(_quadro) % 8
		sprite.flip_h = false
		return
	sprite.texture = _folha_andar
	sprite.hframes = colunas
	sprite.vframes = linhas
	sprite.offset = _offset_arte
	if pivos_andar.has(_direcao):
		sprite.offset = Vector2(_folha_andar.get_size() / Vector2(colunas, linhas)) * .5 - Vector2(pivos_andar[_direcao])
	sprite.scale = _escala_arte
	if esta_morto and _quadro_morte >= 0:
		sprite.frame = _quadro_morte
		sprite.flip_h = _espelho_morte
		return
	super()

func morrer() -> void:
	if esta_morto: return
	# Conserva o desenho original do corpo, sem reproduzir o ataque ao contrário.
	_quadro_morte = int(_frames("andar")[0])
	_espelho_morte = _deve_espelhar()
	_finalizar_golpe()
	_escala_morte = sprite.scale
	if _direcao != "cima" or folha_andar_cima == null:
		sprite.frame = _quadro_morte
	set_deferred("collision_layer", 0)
	super()

func _animar_morte(delta: float) -> void:
	_tempo_morte += delta
	_aplicar_quadro()
	var duracao := maxf(float(anims.get("morte", [0]).size()) / fps_morte, 0.2)
	var t := clampf(_tempo_morte / duracao, 0.0, 1.0)
	sprite.scale = _escala_morte * Vector2(1.0, 1.0 - 0.12 * smoothstep(0.0, 0.65, t))
	sprite.position = _posicao_arte + Vector2(0.0, 2.0 * smoothstep(0.0, 0.65, t))
	sprite.modulate.a = 1.0 - smoothstep(0.3, 1.0, t)
	_atualizar_ordem_desenho()

func _finalizar_golpe() -> void:
	_golpe_ativo = false
	esta_atacando = false
	pode_atacar = false
	_tempo_recarga = tempo_recarga_ataque
	_aviso_golpe.visible = false
	if _area_golpe != null: _area_golpe.monitoring = false
	velocity = Vector2.ZERO
	sprite.rotation = 0.0
	_estado = "andar"
	_quadro = 0.0
	_aplicar_quadro()

