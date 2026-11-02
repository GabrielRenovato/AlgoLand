extends Node2D
## Projeta a ponte 3D no mapa 2D com a mesma resolução baixa do moinho.
var tamanho_mapa := Vector2i(64, 160)
var vertical := true
var estacao := 0
var visor: SubViewport
var visor_corrimaos: SubViewport
var modelo: Node3D
var camera: Camera3D
var imagem: Sprite2D
var imagem_corrimaos: Sprite2D
var rotacao_imagem := 0.0

const FATOR_RESOLUCAO := 2
const ESCALA_SPRITE := 0.5
const MARGEM_RENDERIZACAO := 48
const PROFUNDIDADE := preload("res://codigo/globais/profundidade.gd")

func _ready() -> void:
	name = "Ponte3D"
	vertical = tamanho_mapa.y >= tamanho_mapa.x
	rotacao_imagem = 0.0
	visor = SubViewport.new()
	visor.name = "RenderPonte3D"
	# A margem transparente inclui corrimãos e apoios fora da projeção do piso.
	visor.size = tamanho_mapa * FATOR_RESOLUCAO + Vector2i.ONE * MARGEM_RENDERIZACAO
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	visor.msaa_3d = Viewport.MSAA_DISABLED
	add_child(visor)
	modelo = preload("res://codigo/campanha/modelo_ponte_bacia_3d.gd").new()
	modelo.estacao = estacao
	visor.add_child(modelo)
	if not vertical:
		modelo.rotation.y = PI / 2.0
	camera = Camera3D.new()
	camera.name = "CameraPonte"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (float(tamanho_mapa.y) + float(MARGEM_RENDERIZACAO) / FATOR_RESOLUCAO) / 16.0
	camera.cull_mask = 1
	# Uma inclinação longitudinal bem pequena mostra volume sem entortar a ponte de lado.
	camera.position = Vector3(0, 10, 7) if vertical else Vector3(7, 10, 0)
	visor.add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0), Vector3(0, 0, -1))
	camera.current = true
	_adicionar_luz()
	var ancora := camera.unproject_position(Vector3.ZERO)
	imagem = _criar_imagem("PontePisoPixelArt", visor.get_texture(), ancora)
	# O tabuleiro fica sob o jogador em qualquer ponto da travessia; as colisões
	# e a profundidade normal do personagem mantêm a leitura de quem está em cima.
	# A camada +2 é usada pela textura de grama; ficar em +3 deixa o piso livre.
	imagem.z_index = PROFUNDIDADE.Z_CHAO + 3
	_criar_camada_corrimaos(ancora)
	_atualizar_profundidade_corrimaos()
	definir_estacao(estacao)
	set_process(true)

func _criar_imagem(nome_imagem: String, textura: Texture2D, ancora: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = nome_imagem
	sprite.centered = true
	sprite.texture = textura
	sprite.offset = (Vector2(visor.size) * 0.5 - ancora).round()
	sprite.rotation = rotacao_imagem
	sprite.scale = Vector2.ONE * ESCALA_SPRITE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	add_child(sprite)
	return sprite

func _criar_camada_corrimaos(ancora: Vector2) -> void:
	visor_corrimaos = SubViewport.new()
	visor_corrimaos.name = "RenderCorrimaosPonte"
	visor_corrimaos.size = visor.size
	visor_corrimaos.transparent_bg = true
	visor_corrimaos.world_3d = visor.find_world_3d()
	visor_corrimaos.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visor_corrimaos.msaa_3d = Viewport.MSAA_DISABLED
	add_child(visor_corrimaos)
	var camera_corrimaos := Camera3D.new()
	camera_corrimaos.name = "CameraCorrimaos"
	camera_corrimaos.projection = camera.projection
	camera_corrimaos.size = camera.size
	camera_corrimaos.cull_mask = 2
	camera_corrimaos.global_transform = camera.global_transform
	visor_corrimaos.add_child(camera_corrimaos)
	camera_corrimaos.current = true
	imagem_corrimaos = _criar_imagem("CorrimaosPixelArt", visor_corrimaos.get_texture(), ancora)

func _atualizar_profundidade_corrimaos() -> void:
	if not is_instance_valid(imagem_corrimaos):
		return
	var jogador: Node2D = Cooperativo.jogador_no_ambiente(self)
	var area_ponte := Rect2(global_position - Vector2(tamanho_mapa) * 0.5, Vector2(tamanho_mapa)).grow(12.0)
	if jogador != null and area_ponte.has_point(jogador.global_position):
		imagem_corrimaos.z_index = jogador.z_index + 1
	else:
		imagem_corrimaos.z_index = PROFUNDIDADE.z_de(global_position.y) + 1

func _process(_delta: float) -> void:
	_atualizar_profundidade_corrimaos()

func _adicionar_luz() -> void:
	var ambiente := WorldEnvironment.new()
	var configuracao := Environment.new()
	configuracao.background_mode = Environment.BG_CLEAR_COLOR
	configuracao.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	configuracao.ambient_light_color = Color("91b6d0")
	configuracao.ambient_light_energy = 0.38
	ambiente.environment = configuracao
	visor.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-52, -35, 0)
	luz.light_color = Color("ffe2ac")
	luz.light_energy = 0.95
	luz.light_cull_mask = 3
	luz.shadow_enabled = true
	luz.shadow_bias = 0.035
	luz.shadow_normal_bias = 0.12
	visor.add_child(luz)
	var preenchimento := DirectionalLight3D.new()
	preenchimento.rotation_degrees = Vector3(-28, 145, 0)
	preenchimento.light_color = Color("91bddc")
	preenchimento.light_energy = 0.16
	preenchimento.light_cull_mask = 3
	visor.add_child(preenchimento)

func definir_estacao(indice: int) -> void:
	estacao = clampi(indice, 0, 3)
	if is_instance_valid(modelo):
		modelo.definir_estacao(estacao)
	if is_instance_valid(visor):
		visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	if is_instance_valid(visor_corrimaos):
		visor_corrimaos.render_target_update_mode = SubViewport.UPDATE_ALWAYS
