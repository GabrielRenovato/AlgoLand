extends Node2D
const Profundidade = preload("res://codigo/globais/profundidade.gd")
const FiltroPixel = preload("res://codigo/campanha/filtro_objeto_3d.gd")
## Cada acessório tem âncora, profundidade e render próprios no mapa 2D.
var tipo := "bigorna"
var familia := "forja"
var pixels_por_unidade := 64.0
var visor: SubViewport
var objeto: Node3D
var _sprite: Sprite2D
const TAMANHO_VISAO := 96
const CAMERA := 1.7
const ALVO := 0.60
const BASES := {"bigorna":Vector2(0.70,0.36),"bancada":Vector2(0.86,0.39),"barril":Vector2(0.40,0.40),"estante":Vector2(0.70,0.36),"suporte":Vector2(0.53,0.30),"balde":Vector2(0.27,0.27),"toras":Vector2(1.10,0.95),"pilha_tabuas":Vector2(1.12,0.65),"cavalete":Vector2(1.77,0.56),"estante_carpinteiro":Vector2(0.66,0.38),"placa_lua":Vector2(0.23,0.24),"canteiro_lavanda":Vector2(1.28,0.60),"vaso_ervas":Vector2(0.40,0.40),"barril_ingredientes":Vector2(0.48,0.48),"placa_cruz":Vector2(0.23,0.24),"canteiro_rosas":Vector2(1.28,0.65),"canteiro_margaridas":Vector2(1.28,0.65),"vaso_medicinal":Vector2(0.39,0.39),"banca_frutas":Vector2(1.02,0.60),"banca_verduras":Vector2(1.02,0.60),"caixas_estoque":Vector2(0.67,0.55),"cesto_colheita":Vector2(0.49,0.49),"placa_espiga":Vector2(0.21,0.22),"placa_chave":Vector2(0.24,0.25),"jardineira_chao":Vector2(0.97,0.55),"vaso_pousada":Vector2(0.38,0.38),"jardim_sede":Vector2(1.58,1.04),"luminaria_sede":Vector2(0.29,0.29),"vaso_pedestal":Vector2(0.40,0.40),"canteiro_bento":Vector2(1.22,0.80),"vaso_bento":Vector2(0.49,0.49),"jardineira_cora":Vector2(0.98,0.54),"vaso_cora":Vector2(0.43,0.43)}
const VISOES := {"toras":Vector2(2.1,0.55),"pilha_tabuas":Vector2(1.9,0.45),"cavalete":Vector2(2.2,0.52),"placa_lua":Vector2(2.4,0.94),"placa_cruz":Vector2(2.3,0.90),"placa_espiga":Vector2(2.4,0.95),"placa_chave":Vector2(3.7,1.42),"jardim_sede":Vector2(2.1,0.50),"luminaria_sede":Vector2(2.2,0.91)}

func _ready() -> void:
	name = tipo.to_pascal_case()
	var visao: Vector2 = VISOES.get(tipo,Vector2(CAMERA,ALVO))
	set_notify_transform(true)
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y)
	var base: Vector2 = BASES[tipo]*pixels_por_unidade
	base.y *= sin(atan2(7.0,10.0))
	var sombra := Polygon2D.new()
	if tipo == "placa_lua": sombra.position.x = -0.35*pixels_por_unidade
	if tipo == "placa_cruz": sombra.position.x = 0.33*pixels_por_unidade
	if tipo == "placa_espiga": sombra.position.x = 0.30*pixels_por_unidade
	if tipo == "placa_chave": sombra.position.x = 0.29*pixels_por_unidade
	sombra.name = "SombraDeContato"
	var pontos := PackedVector2Array()
	for i in 16:
		var angulo := TAU*i/16.0
		pontos.append(Vector2(cos(angulo),sin(angulo))*base*0.54)
	sombra.polygon = pontos
	sombra.color = Color(0.12,0.10,0.08,0.2)
	add_child(sombra)
	var corpo := StaticBody2D.new()
	if tipo == "placa_lua": corpo.position.x = -0.35*pixels_por_unidade
	if tipo == "placa_cruz": corpo.position.x = 0.33*pixels_por_unidade
	if tipo == "placa_espiga": corpo.position.x = 0.30*pixels_por_unidade
	if tipo == "placa_chave": corpo.position.x = 0.29*pixels_por_unidade
	corpo.name = "BaseFisica"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	var colisao := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = base*Vector2(0.85,0.7)
	colisao.shape = retangulo
	corpo.add_child(colisao)
	add_child(corpo)
	visor = SubViewport.new()
	visor.name = "Render3DObjeto"
	visor.size = Vector2i(TAMANHO_VISAO,TAMANHO_VISAO)
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(visor)
	objeto = (load("res://cenas/campanha/%s/%s.tscn" % [familia,tipo]) as PackedScene).instantiate()
	visor.add_child(objeto)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = visao.x
	camera.position = Vector3(0,visao.y+7.0,10)
	camera.look_at_from_position(camera.position,Vector3(0,visao.y,0))
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
	var imagem := Sprite2D.new()
	imagem.texture = visor.get_texture()
	imagem.scale = Vector2.ONE*pixels_por_unidade*visao.x/TAMANHO_VISAO
	imagem.position.y = -visao.y*cos(atan2(7.0,10.0))*pixels_por_unidade
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(imagem)
	_sprite = imagem
	FiltroPixel.aplicar(imagem)

func definir_estacao(estacao: int) -> void:
	if objeto:
		objeto.definir_estacao(estacao)
		visor.render_target_update_mode = SubViewport.UPDATE_ONCE

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		z_index = Profundidade.z_de(global_position.y)
		FiltroPixel.atualizar(_sprite)
