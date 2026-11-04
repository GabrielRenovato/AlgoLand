extends Node2D
## Render da construção escolhida; acessórios mantêm âncoras e profundidade próprias.
const TAMANHO_VISAO := 256
const FiltroPixel = preload("res://codigo/campanha/filtro_objeto_3d.gd")
const ALTURA_ALVO := 1.78
const ELEVACAO_CAMERA := 7.0
const CENAS := {
	"forja":preload("res://cenas/campanha/forja/construcao.tscn"),
	"carpintaria":preload("res://cenas/campanha/carpintaria/construcao.tscn"),
	"mistica":preload("res://cenas/campanha/mistica/construcao.tscn"),
	"enfermaria":preload("res://cenas/campanha/enfermaria/construcao.tscn"),
	"venda":preload("res://cenas/campanha/venda/construcao.tscn"),
	"pousada":preload("res://cenas/campanha/pousada/construcao.tscn"),
	"sede":preload("res://cenas/campanha/sede/construcao.tscn"),
	"casa_bento":preload("res://cenas/campanha/casa_bento/construcao.tscn"),
	"cora":preload("res://cenas/campanha/cora/construcao.tscn"),
	# A moradia oriental usa a mesma fachada original do Bento, em escala menor.
	"casa_jogador":preload("res://cenas/campanha/casa_bento/construcao.tscn"),
}
const MEDIDAS := {"forja":Vector3(4.7,4.8,0.85),"carpintaria":Vector3(5.3,5.6,0.85),"mistica":Vector3(4.8,5.2,0.85),"enfermaria":Vector3(4.8,4.8,0.85),"venda":Vector3(5.7,5.6,0.85),"pousada":Vector3(8.0,7.0,0.85),"sede":Vector3(7.2,6.5,0.85),"casa_bento":Vector3(4.8,5.3,0.85),"cora":Vector3(6.4,6.2,0.85),"casa_jogador":Vector3(4.8,5.3,0.85)}
var id := "forja"
var largura := 256.0
var visor: SubViewport
var sprite: Sprite2D
var modelo: Node3D
var _construcao: Node3D
var _estacao := -1
var _objetos: Array[Node2D] = []
var _largura_modelo := 4.7
## Base da construção no chão (px, local): sombra de contato e colisão usam o mesmo contorno.
var contorno_chao := PackedVector2Array()

func _ready() -> void:
	name = id.to_pascal_case()
	var medidas: Vector3 = MEDIDAS[id]
	_largura_modelo = medidas.x
	visor = SubViewport.new()
	visor.name = "Render3DCasa"
	visor.size = Vector2i(TAMANHO_VISAO,TAMANHO_VISAO)
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.msaa_3d = Viewport.MSAA_DISABLED
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(visor)
	modelo = Node3D.new()
	modelo.name = "ModeloDaConstrucao"
	visor.add_child(modelo)
	_construcao = CENAS[id].instantiate()
	_construcao.scale.y = medidas.z
	modelo.add_child(_construcao)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = medidas.y
	camera.position = Vector3(0,ALTURA_ALVO+ELEVACAO_CAMERA,10)
	camera.look_at_from_position(camera.position,Vector3(0,ALTURA_ALVO,0))
	visor.add_child(camera)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-38,-22,0)
	luz.light_energy = 0.85
	visor.add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8d1c2")
	env.ambient_light_energy = 0.8
	ambiente.environment = env
	visor.add_child(ambiente)
	_sombra_construcao()
	sprite = Sprite2D.new()
	sprite.name = "Construcao3DRenderizada"
	sprite.texture = visor.get_texture()
	sprite.scale = Vector2.ONE*largura/(TAMANHO_VISAO*_largura_modelo/camera.size)
	var inclinacao := atan2(ELEVACAO_CAMERA,10.0)
	sprite.position.y = -ALTURA_ALVO*cos(inclinacao)*TAMANHO_VISAO/camera.size*sprite.scale.y
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	FiltroPixel.aplicar(sprite)
	set_notify_transform(true)
	if _construcao.has_signal("quadro_fogo"):
		_construcao.quadro_fogo.connect(_renderizar_fogo)
		_construcao.set_process(false)
		var visibilidade := VisibleOnScreenNotifier2D.new()
		visibilidade.name = "VisibilidadeDoForno"
		var tamanho := sprite.texture.get_size()*sprite.scale
		visibilidade.rect = Rect2(sprite.position-tamanho*0.5,tamanho)
		visibilidade.screen_entered.connect(func(): _construcao.set_process(true))
		visibilidade.screen_exited.connect(func(): _construcao.set_process(false))
		add_child(visibilidade)
	_adicionar_objetos()
	if get_parent() and get_parent().has_signal("estacao_mudou"):
		get_parent().estacao_mudou.connect(definir_estacao)
	definir_estacao(Calendario.estacao())

func definir_estacao(indice: int) -> void:
	var nova := posmod(indice,4)
	if nova == _estacao: return
	_estacao = nova
	_construcao.definir_estacao(nova)
	for objeto in _objetos: objeto.definir_estacao(nova)
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE

func _adicionar_objetos() -> void:
	var escala_unidade := largura/_largura_modelo
	var inclinacao := atan2(ELEVACAO_CAMERA,10.0)
	var acessorios := [
		["bigorna",Vector2(-0.48,1.54)],
		["bancada",Vector2(0.91,1.10)],
		["barril",Vector2(1.63,1.05)],
		["estante",Vector2(-1.91,0.66)],
		["suporte",Vector2(1.91,0.29)],
		["balde",Vector2(-1.11,1.25)],
	]
	if id == "carpintaria":
		acessorios = [
			["toras",Vector2(-2.22,1.11)],
			["pilha_tabuas",Vector2(-1.78,0.38)],
			["cavalete",Vector2(0,1.55)],
			["estante_carpinteiro",Vector2(1.73,0.41)],
			["barril",Vector2(1.14,1.20)],
			["balde",Vector2(1.65,1.38)],
		]
	if id == "mistica":
		acessorios = [
			["placa_lua",Vector2(-1.96,0.64)],
			["canteiro_lavanda",Vector2(-1.14,1.50)],
			["canteiro_lavanda",Vector2(1.30,1.46)],
			["barril_ingredientes",Vector2(-0.85,1.10)],
			["barril_ingredientes",Vector2(-1.37,1.00)],
			["vaso_ervas",Vector2(0.76,1.55)],
		]
	if id == "enfermaria":
		acessorios = [
			["placa_cruz",Vector2(2.02,0.68)],
			["canteiro_rosas",Vector2(-1.73,1.46)],
			["canteiro_margaridas",Vector2(1.20,1.42)],
			["barril",Vector2(-1.36,0.98)],
			["barril",Vector2(0.77,1.02)],
			["vaso_medicinal",Vector2(0.40,1.64)],
		]
	if id == "venda":
		acessorios = [
			["banca_frutas",Vector2(-0.67,1.67)],
			["banca_verduras",Vector2(0.48,1.67)],
			["placa_espiga",Vector2(-2.44,0.54)],
			["barril",Vector2(-2.00,1.24)],
			["barril",Vector2(-1.49,1.38)],
			["caixas_estoque",Vector2(2.07,-0.02)],
			["cesto_colheita",Vector2(2.10,1.10)],
		]
	if id == "pousada":
		acessorios = [["placa_chave",Vector2(3.18,0.49)],["jardineira_chao",Vector2(-1.17,1.64)],["vaso_pousada",Vector2(1.10,1.73)],["barril",Vector2(2.97,1.32)],["barril",Vector2(3.57,0.97)]]
	if id == "sede":
		acessorios = [["jardim_sede",Vector2(-2.00,1.32)],["jardim_sede",Vector2(2.00,1.32)],["luminaria_sede",Vector2(-2.82,1.50)],["luminaria_sede",Vector2(2.82,1.50)],["vaso_pedestal",Vector2(-1.22,2.04)],["vaso_pedestal",Vector2(1.22,2.04)]]
	if id in ["casa_bento","casa_jogador"]:
		acessorios = [["canteiro_bento",Vector2(-0.88,1.61)],["canteiro_bento",Vector2(1.65,1.04)],["barril",Vector2(-2.02,0.54)],["barril",Vector2(-2.12,1.28)],["vaso_bento",Vector2(1.61,1.69)]]
	if id == "cora":
		acessorios = [["jardineira_cora",Vector2(1.85,1.47)],["jardineira_cora",Vector2(-2.00,1.53)],["vaso_cora",Vector2(-0.26,1.56)],["vaso_cora",Vector2(1.40,1.72)],["barril",Vector2(-2.58,1.10)],["barril",Vector2(2.65,0.98)],["vaso_cora",Vector2(2.69,1.67)]]
	for dados in acessorios:
		var objeto := preload("res://codigo/campanha/objeto_oficina_mapa.gd").new()
		objeto.tipo = dados[0]
		objeto.familia = "forja" if dados[0] in ["barril","balde"] else ("casa_bento" if id == "casa_jogador" else id)
		objeto.pixels_por_unidade = escala_unidade
		var deslocamento: Vector2 = dados[1]
		objeto.position = Vector2(deslocamento.x,deslocamento.y*sin(inclinacao))*escala_unidade
		add_child(objeto)
		_objetos.append(objeto)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		FiltroPixel.atualizar(sprite)

func _renderizar_fogo() -> void:
	# Só a construção visível é atualizada a 8 FPS; os acessórios ficam em UPDATE_ONCE.
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE

func _sombra_construcao() -> void:
	var contorno := PackedVector2Array([Vector2(-1.66,-0.77),Vector2(1.66,-0.77),Vector2(1.72,0.68),Vector2(0.48,1.14),Vector2(-1.30,1.14),Vector2(-1.70,0.65)])
	if id == "carpintaria": contorno = PackedVector2Array([Vector2(-1.30,-0.91),Vector2(1.30,-0.91),Vector2(1.36,0.91),Vector2(-1.36,0.91)])
	if id == "mistica": contorno = PackedVector2Array([Vector2(-1.73,-0.97),Vector2(1.73,-0.97),Vector2(1.73,0.99),Vector2(0.65,0.99),Vector2(0.65,1.64),Vector2(-0.65,1.64),Vector2(-0.65,0.99),Vector2(-1.73,0.99)])
	if id == "enfermaria": contorno = PackedVector2Array([Vector2(-1.80,-0.98),Vector2(1.80,-0.98),Vector2(1.80,0.63),Vector2(0.73,0.63),Vector2(0.73,1.13),Vector2(0.14,1.13),Vector2(0.14,1.79),Vector2(-1.10,1.79),Vector2(-1.10,1.13),Vector2(-1.80,1.13)])
	if id == "venda": contorno = PackedVector2Array([Vector2(-2.10,-0.98),Vector2(2.10,-0.98),Vector2(2.10,0.68),Vector2(2.04,1.47),Vector2(1.12,1.47),Vector2(1.12,1.11),Vector2(-1.44,1.11),Vector2(-1.44,0.68),Vector2(-2.10,0.68)])
	if id == "pousada": contorno = PackedVector2Array([Vector2(-3.58,-1.10),Vector2(2.83,-1.10),Vector2(2.83,1.14),Vector2(0.85,1.14),Vector2(0.85,1.90),Vector2(-0.85,1.90),Vector2(-0.85,1.14),Vector2(-3.58,1.14)])
	if id == "sede": contorno = PackedVector2Array([Vector2(-2.83,-1.0),Vector2(2.83,-1.0),Vector2(2.83,0.83),Vector2(1.35,0.83),Vector2(1.35,1.24),Vector2(1.12,2.33),Vector2(-1.12,2.33),Vector2(-1.35,1.24),Vector2(-1.35,0.83),Vector2(-2.83,0.83)])
	if id in ["casa_bento","casa_jogador"]: contorno = PackedVector2Array([Vector2(-1.89,-1.15),Vector2(1.60,-1.15),Vector2(1.60,1.16),Vector2(1.23,1.16),Vector2(1.23,1.91),Vector2(0.09,1.91),Vector2(0.09,1.16),Vector2(-1.60,1.16),Vector2(-1.60,0.10),Vector2(-1.89,0.10)])
	if id == "cora": contorno = PackedVector2Array([Vector2(-2.43,-1.16),Vector2(2.43,-1.16),Vector2(2.43,1.16),Vector2(1.27,1.16),Vector2(1.27,1.80),Vector2(-0.03,1.80),Vector2(-0.03,1.42),Vector2(-2.43,1.42)])
	var escala_unidade := largura/_largura_modelo
	for i in contorno.size(): contorno[i] = Vector2(contorno[i].x+0.055,contorno[i].y*sin(atan2(ELEVACAO_CAMERA,10.0))+0.075)*escala_unidade
	contorno_chao = contorno
	var sombra := Polygon2D.new()
	sombra.name = "SombraDeContatoDaConstrucao"
	sombra.polygon = contorno
	sombra.color = Color(0.12,0.10,0.08,0.14)
	add_child(sombra)
