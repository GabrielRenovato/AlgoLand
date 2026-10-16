extends Node2D
class_name IndicadorAtaque

const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")
const Profundidade := preload("res://codigo/globais/profundidade.gd")

var raio: float = 64.0
var progresso: float = 0.0
var ativo: bool = true
var em_impacto: bool = false
var alfa_flash: float = 0.0
var escala_impacto: float = 1.0
var _luz: PointLight2D = null

const COR_FUNDO := Color(0.95, 0.15, 0.1, 0.18)
const COR_CARGA := Color(1.0, 0.35, 0.1, 0.35)
const COR_ANEL_CARGA := Color(1.0, 0.75, 0.25, 0.95)
const COR_BORDA := Color(1.0, 0.22, 0.12, 0.9)
const COR_MARCADOR := Color(1.0, 0.6, 0.2, 0.9)
const COR_FLASH := Color(1.0, 0.9, 0.6, 0.75)

func _ready() -> void:
	z_index = Profundidade.Z_CHAO + 10
	z_as_relative = false
	top_level = true
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func configurar(pos: Vector2, raio_ataque: float) -> void:
	global_position = pos
	raio = raio_ataque
	progresso = 0.0
	ativo = true
	em_impacto = false
	modulate.a = 1.0

	_luz = PointLight2D.new()
	_luz.texture = TEXTURA_LUZ
	_luz.color = Color(1.0, 0.35, 0.1)
	_luz.energy = 0.35
	_luz.texture_scale = (raio * 2.2) / 128.0
	_luz.shadow_enabled = false
	add_child(_luz)

	queue_redraw()

func atualizar_progresso(novo_progresso: float) -> void:
	if not ativo or em_impacto:
		return
	progresso = clampf(novo_progresso, 0.0, 1.0)
	if _luz:
		_luz.energy = 0.35 + 0.3 * progresso
	queue_redraw()

func detonar_impacto() -> void:
	if not ativo:
		return
	ativo = false
	em_impacto = true
	progresso = 1.0
	alfa_flash = 1.0
	escala_impacto = 1.0
	queue_redraw()

	if _luz:
		_luz.energy = 1.2
		var tween_luz := _luz.create_tween()
		tween_luz.tween_property(_luz, "energy", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var tween := create_tween()
	tween.tween_property(self, "alfa_flash", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "escala_impacto", 1.15, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func cancelar() -> void:
	if not ativo and not em_impacto:
		return
	ativo = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if em_impacto:
		queue_redraw()

func _draw() -> void:
	if em_impacto:
		var raio_onda := raio * escala_impacto
		draw_circle(Vector2.ZERO, raio, Color(COR_FLASH.r, COR_FLASH.g, COR_FLASH.b, COR_FLASH.a * alfa_flash))
		draw_arc(Vector2.ZERO, raio_onda, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, alfa_flash), 3.0, true)
		return

	# 1. Área de perigo translúcida de fundo
	draw_circle(Vector2.ZERO, raio, COR_FUNDO)

	# 2. Círculo de preenchimento que cresce proporcionalmente
	var raio_atual := raio * progresso
	if raio_atual > 1.0:
		draw_circle(Vector2.ZERO, raio_atual, COR_CARGA)
		draw_arc(Vector2.ZERO, raio_atual, 0.0, TAU, 48, COR_ANEL_CARGA, 2.0, true)

	# 3. Borda externa contínua (limite de alcance)
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 64, COR_BORDA, 2.0, true)

	# 4. Marcadores de perigo estilo MMORPG (8 traços no perímetro)
	for i in 8:
		var ang := i * (TAU / 8.0)
		var dir := Vector2.from_angle(ang)
		var p1 := dir * (raio - 5.0)
		var p2 := dir * (raio + 5.0)
		draw_line(p1, p2, COR_MARCADOR, 2.0)
