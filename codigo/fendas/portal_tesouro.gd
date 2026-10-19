extends Node2D

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const FOLHA := "res://assets/cenario/fendas/tesouro/portal_sazonal_animado.png"
const Estacoes := preload("res://codigo/cenario/estacoes.gd")
const CORES := [Color("a3df6b"), Color("ffd875"), Color("e78b3e"), Color("d3f4ff")]
var destino: Callable
var permitido: Callable
var sprite: Sprite2D
var estacoes: Node
var _tempo := 0.0
var _estacao := 0
var _particulas: CPUParticles2D

class Interacao extends "res://codigo/logica/interagivel.gd":
	func pode_interagir() -> bool:
		var portal = get_parent()
		return not Transicao.ocupada and portal.permitido.is_valid() and portal.permitido.call()
	func abrir_tela() -> void:
		if pode_interagir(): get_parent().destino.call()
	func abrir_tela_p2() -> void:
		abrir_tela()

func _ready() -> void:
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y)
	sprite = Sprite2D.new()
	sprite.texture = load(FOLHA)
	sprite.hframes = 4
	sprite.vframes = 9
	sprite.offset = Vector2(0, -32)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var luz := CanvasItemMaterial.new()
	luz.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = luz
	add_child(sprite)
	_particulas = CPUParticles2D.new()
	_particulas.amount = 8
	_particulas.lifetime = 1.8
	_particulas.preprocess = 1.8
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var pontos := PackedVector2Array()
	for i in 16: pontos.append(Vector2(cos(i * TAU / 16) * 24, -32 + sin(i * TAU / 16) * 28))
	_particulas.emission_points = pontos
	_particulas.direction = Vector2.UP
	_particulas.initial_velocity_min = 3
	_particulas.initial_velocity_max = 7
	_particulas.gravity = Vector2.ZERO
	_particulas.material = luz
	add_child(_particulas)
	if estacoes != null:
		estacoes.estacao_mudou.connect(definir_estacao)
		definir_estacao(estacoes.estacao_atual)
	else:
		definir_estacao(Calendario.estacao())
	var zona := Interacao.new()
	zona.nome_tela = "tesouro"
	zona.so_entre_ondas = false
	zona.deslocamento_aviso = Vector2(0, -77)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 34
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)

func definir_estacao(indice: int) -> void:
	_estacao = clampi(indice, 0, 3)
	if sprite != null: sprite.frame_coords.x = _estacao
	if _particulas != null and estacoes != null:
		_particulas.color = CORES[_estacao]
		var forma: Array[String] = Estacoes.FORMA_FOLHA if _estacao == 2 else (Estacoes.FORMA_PETALA if _estacao == 0 else Estacoes.FORMA_BRILHO)
		_particulas.texture = estacoes._textura_da_forma(forma)

func _process(delta: float) -> void:
	_tempo += delta
	sprite.frame_coords = Vector2i(_estacao, int(_tempo * 9.0) % 9)
	sprite.self_modulate = Color(1, 1, 1, 0.90 + 0.10 * sin(_tempo * 3.0))
