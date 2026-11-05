extends Node2D
## Modelo vivo em resolução baixa, composto no mundo 2D com transparência.
const TAMANHO := Vector2i(128, 120)
const AMPLIACAO := 2.0
const PORTA := Vector3(1.18, 0.0, 1.9)
var instante_forcado := -1.0
var modelo: Node3D
var camera: Camera3D
var imagem: Sprite2D
var ligado := false
var _ancora := Vector2.ZERO
var _espuma: Node2D
var _vazao_recebida := 0.0

var visor: SubViewport

func _ready() -> void:
	visor = SubViewport.new()
	visor.name = "RenderMoinho3D"
	visor.size = TAMANHO
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	visor.msaa_3d = Viewport.MSAA_DISABLED
	visor.positional_shadow_atlas_size = 1024
	add_child(visor)
	modelo = preload("res://cenas/campanha/moinho_lowpoly_3d.tscn").instantiate()
	modelo.sobre_mapa = true
	modelo.fluxo = 0.0
	visor.add_child(modelo)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(-6, 7, 9)
	visor.add_child(camera)
	camera.look_at(Vector3(0.0, 1.8, 0.0))
	camera.current = true
	var ambiente := WorldEnvironment.new()
	var configuracao := Environment.new()
	configuracao.background_mode = Environment.BG_CLEAR_COLOR
	configuracao.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	configuracao.ambient_light_color = Color("91b6d0")
	configuracao.ambient_light_energy = 0.32
	configuracao.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = configuracao
	visor.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-52, -35, 0)
	luz.light_color = Color("ffe2ac")
	luz.light_energy = 0.95
	luz.shadow_enabled = true
	luz.shadow_bias = 0.035
	luz.shadow_normal_bias = 0.15
	visor.add_child(luz)
	var preenchimento := DirectionalLight3D.new()
	preenchimento.rotation_degrees = Vector3(-28, 145, 0)
	preenchimento.light_color = Color("91bddc")
	preenchimento.light_energy = 0.18
	visor.add_child(preenchimento)
	_ancora = camera.unproject_position(PORTA)
	imagem = Sprite2D.new()
	imagem.name = "MoinhoPixelArt"
	imagem.centered = false
	imagem.texture = visor.get_texture()
	imagem.position = (-_ancora * AMPLIACAO).round()
	imagem.scale = Vector2.ONE * AMPLIACAO
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.z_as_relative = false
	imagem.z_index = preload("res://codigo/globais/profundidade.gd").z_de(position.y)
	add_child(imagem)
	_sombra_no_chao()
	_espuma = preload("res://codigo/campanha/espuma_moinho.gd").new()
	_espuma.name = "EspumaNoCanal"
	_espuma.terreno = get_parent()
	add_child(_espuma)
	modelo.agua_fisica.impacto.connect(_impacto_da_agua)
	definir_ligado(false)

func _impacto_da_agua(ponto: Vector3, intensidade: float) -> void:
	_espuma.adicionar(projetar(ponto), intensidade)

func _sombra_no_chao() -> void:
	var base := poligono_base()
	for i in 2:
		var pontos := PackedVector2Array()
		var deslocamento := Vector2(22, 9) * (1.0 if i == 0 else 0.6)
		for ponto in base:
			pontos.append(ponto - position)
			pontos.append(ponto - position + deslocamento)
		var sombra := Polygon2D.new()
		sombra.name = "SombraSuave" if i == 0 else "SombraContato"
		sombra.polygon = Geometry2D.convex_hull(pontos)
		sombra.color = Color(0.12, 0.18, 0.23, 0.10 if i == 0 else 0.13)
		sombra.z_as_relative = false
		sombra.z_index = preload("res://codigo/globais/profundidade.gd").Z_CHAO + 2
		add_child(sombra)

func projetar(ponto: Vector3) -> Vector2:
	return position + (camera.unproject_position(ponto) - _ancora) * AMPLIACAO

func poligono_base() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for p in [Vector3(-1.65, 0, -1.48), Vector3(2.65, 0, -1.48), Vector3(2.65, 0, 1.78), Vector3(-1.65, 0, 1.78)]:
		pontos.append(projetar(p))
	return pontos

func poligono_roda() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for p in [Vector3(-3.3, 0, -1.1), Vector3(-2.45, 0, -1.1), Vector3(-2.45, 0, 1.5), Vector3(-3.3, 0, 1.5)]:
		pontos.append(projetar(p))
	return pontos

func definir_ligado(valor: bool) -> void:
	ligado = valor
	modelo.roda_travada = not ligado
	modelo.fluxo = _vazao_recebida
	set_process(ligado or _vazao_recebida > 0.01)

func definir_vazao(valor: float) -> void:
	_vazao_recebida = clampf(valor,0.0,1.0)
	modelo.fluxo = _vazao_recebida
	set_process(ligado or _vazao_recebida > 0.01)

func definir_estacao(indice: int) -> void:
	modelo.estacao_previa = indice
	modelo._atualizar_estacao()

func _process(_delta: float) -> void:
	# A roda gira devagar: metade dos quadros basta e não se nota no pixel art.
	if instante_forcado < 0.0 and is_instance_valid(visor):
		visor.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if Engine.get_process_frames() % 2 == 0 else SubViewport.UPDATE_DISABLED
	if instante_forcado >= 0.0:
		modelo._tempo = instante_forcado
		modelo._roda.rotation.x = -instante_forcado * 0.32
