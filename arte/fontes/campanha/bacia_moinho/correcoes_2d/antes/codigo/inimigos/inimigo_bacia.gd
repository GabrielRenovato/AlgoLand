extends "res://codigo/inimigos/inimigo_generico.gd"
class_name InimigoBacia

## Golpes próprios das três espécies da Bacia do Moinho.
## A folha usa linha 4 para antecipação, impacto e recuperação; o estado impede loop.
@export_enum("arraia", "besouro", "valvula") var especie := "arraia"

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

func _ready() -> void:
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
	_aviso_golpe.add_point(Vector2.ZERO)
	_aviso_golpe.add_point(Vector2.RIGHT * (150.0 if especie == "valvula" else 78.0))
	add_child(_aviso_golpe)

func _physics_process(delta: float) -> void:
	if esta_morto:
		_animar(delta)
		return
	if esta_congelado():
		if _area_golpe != null: _area_golpe.monitoring = false
		velocity = Vector2.ZERO
		_atualizar_efeitos(delta)
		return
	if _golpe_ativo:
		_atualizar_golpe(delta)
		return
	_tempo_recarga = maxf(_tempo_recarga - delta, 0.0)
	if _tempo_recarga == 0.0: pode_atacar = true
	super(delta)

func _iniciar_ataque(direcao: Vector2) -> void:
	if _golpe_ativo or _tempo_recarga > 0.0 or esta_morto: return
	_direcao_golpe = direcao.normalized()
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
	sprite.flip_h = false
	sprite.rotation = _direcao_golpe.angle()
	_atualizar_ordem_desenho()
	match especie:
		"arraia": _golpe_arraia()
		"besouro": _golpe_besouro()
		"valvula": _golpe_valvula()
	if _tempo_golpe >= duracao:
		_finalizar_golpe()

func _quadro_da_fase() -> float:
	var marcos: Array[float]
	if especie == "arraia":
		marcos = [0.30, 0.38, 0.53, TEMPO_ARRAIA]
	elif especie == "besouro":
		marcos = [0.42, 0.55, 0.79, TEMPO_BESOURO]
	else:
		marcos = [0.24, 0.48, 0.62, TEMPO_VALVULA]
	for i in 4:
		if _tempo_golpe < marcos[i]:
			var inicio := 0.0 if i == 0 else marcos[i - 1]
			return float(i) + clampf((_tempo_golpe - inicio) / maxf(marcos[i] - inicio, 0.001), 0.0, 0.99)
	return 3.0

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
		jato.dano = obter_dano()
		jato.direcao = _direcao_golpe
		jato.global_position = global_position + _direcao_golpe * 28.0
		get_tree().current_scene.add_child(jato)

func _aplicar_golpe_em_areas() -> void:
	if _area_golpe == null: return
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
	if _golpe_ativo and especie != "valvula": _aplicar_golpe_em_areas()

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

