extends Area2D

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const TEXTURA_FLECHA := preload("res://assets/personagens/Arco/flecha.png")
const EFEITOS_MANA_SEED := preload("res://assets/efeitos/esqueletos/base_mana_seed.png")
const VELOCIDADE_FLECHA := 145.0
const VELOCIDADE_MAGIA := 105.0
const DURACAO := 3.0
var tipo := "flecha"
var dano: int = 0
var alvo: Node2D
var origem := Vector2.ZERO
var destino := Vector2.ZERO
var _direcao := Vector2.RIGHT
var _tempo := 0.0
var _atingiu := false
var _sprite: Sprite2D

func _ready() -> void:
	top_level = true
	global_position = origem
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y + 12)
	collision_layer = 0
	collision_mask = 66 # Área de dano do jogador e obstáculos.
	_direcao = (destino - origem).normalized()
	var forma := CircleShape2D.new()
	forma.radius = 3.0 if tipo == "flecha" else 4.0
	var colisao := CollisionShape2D.new()
	colisao.shape = forma
	add_child(colisao)
	area_entered.connect(_ao_entrar_area)
	body_entered.connect(_ao_entrar_corpo)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tipo == "magia":
		var folha := AtlasTexture.new()
		folha.atlas = EFEITOS_MANA_SEED
		folha.region = Rect2(0, 0, 96, 32)
		_sprite.texture = folha
		_sprite.hframes = 3
		# Mantém o desenho e os pixels do efeito original, com a paleta violeta do cajado.
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment() { vec4 p = texture(TEXTURE, UV); float luz = dot(p.rgb, vec3(0.299, 0.587, 0.114)); COLOR = vec4(mix(vec3(0.18, 0.05, 0.30), vec3(0.96, 0.80, 1.0), luz), p.a); }"
		var material_magia := ShaderMaterial.new()
		material_magia.shader = shader
		_sprite.material = material_magia
	else:
		_sprite.texture = TEXTURA_FLECHA
		# A flecha original do jogador aponta para a esquerda.
		_sprite.rotation = _direcao.angle() + PI
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_tempo += delta
	if _tempo >= DURACAO or not is_instance_valid(alvo):
		queue_free()
		return
	global_position += _direcao * (VELOCIDADE_FLECHA if tipo == "flecha" else VELOCIDADE_MAGIA) * delta
	z_index = Profundidade.z_de(global_position.y + 12)
	if tipo == "magia":
		_sprite.frame = int(_tempo * 12.0) % 3

func _ao_entrar_area(area: Area2D) -> void:
	if is_instance_valid(alvo) and area.get_parent() == alvo:
		_atingir()

func _ao_entrar_corpo(corpo: Node2D) -> void:
	if corpo == alvo:
		_atingir()
	else:
		queue_free()

func _atingir() -> void:
	if _atingiu or not is_instance_valid(alvo):
		return
	_atingiu = true
	alvo.receber_dano(dano, _direcao * 100.0)
	queue_free()
