extends Node2D

## Vida da fazenda (cenas/terreno_fazenda.tscn, gerada por ferramentas/fazenda/gerar_fazenda.py): vaga-lumes piscando
## pelo mapa à noite e borboletas sobre os canteiros de flores e a horta de dia. No inverno não há nenhum dos dois.
## Os vaga-lumes não escurecem com a noite (material sem luz), para brilhar como luz própria.

## Área onde os vaga-lumes voam e retângulos dos canteiros onde ficam as borboletas (o gerador escreve)
@export var area := Rect2(0, 0, 960, 672)
@export var canteiros: Array[Rect2] = []

var _vaga_lumes: CPUParticles2D
var _borboletas: Array[CPUParticles2D] = []
var _tempo := 0.0

func _ready() -> void:
	z_index = 990
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vaga_lumes = _particulas(area, 46, 7.0, [Color(0.85, 1.0, 0.45), Color(1.0, 0.95, 0.5)], 6.0)
	var sem_luz := CanvasItemMaterial.new()
	sem_luz.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_vaga_lumes.material = sem_luz
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.35, 0.55, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)])
	_vaga_lumes.color_ramp = rampa
	for canteiro in canteiros:
		var borboletas := _particulas(canteiro, 4, 5.0, [Color(1, 1, 1), Color(1, 0.85, 0.35), Color(1, 0.6, 0.75), Color(0.6, 0.8, 1)], 14.0)
		borboletas.scale_amount_min = 2.0
		borboletas.scale_amount_max = 2.0
		var batida := Gradient.new()
		batida.offsets = PackedFloat32Array([0.0, 0.1, 0.9, 1.0])
		batida.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		borboletas.color_ramp = batida
		_borboletas.append(borboletas)
	_atualizar()

## Partículas soltas que vagam devagar dentro do retângulo, cada uma de uma das cores
func _particulas(regiao: Rect2, quantidade: int, vida: float, cores: Array, velocidade: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = regiao.get_center()
	p.amount = quantidade
	p.lifetime = vida
	p.preprocess = vida
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = regiao.size / 2.0
	p.direction = Vector2(1, 0)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = velocidade * 0.4
	p.initial_velocity_max = velocidade
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	var tons := Gradient.new()
	tons.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in cores.size():
		offsets.append(float(i) / cores.size())
	tons.offsets = offsets
	tons.colors = PackedColorArray(cores)
	p.color_initial_ramp = tons
	add_child(p)
	return p

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= 1.0:
		_tempo = 0.0
		_atualizar()

## Vaga-lumes das 19h às 5h, borboletas das 7h às 18h; nada no inverno
func _atualizar() -> void:
	var luz := get_tree().get_first_node_in_group("iluminacao")
	var hora: float = luz.hora if luz != null and "hora" in luz else 12.0
	var inverno := Calendario.estacao() == 3
	_vaga_lumes.emitting = not inverno and (hora >= 19.0 or hora < 5.0)
	for borboletas in _borboletas:
		borboletas.emitting = not inverno and hora >= 7.0 and hora < 18.0
