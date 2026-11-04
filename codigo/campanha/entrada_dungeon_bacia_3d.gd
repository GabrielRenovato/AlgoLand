extends Node2D
## Portal modular de pedra: fachada elevada e piso independente para a travessia.
const PROF := preload("res://codigo/globais/profundidade.gd")
var estacao := 0
var _visor: SubViewport
var _frente_visor: SubViewport
var _raiz: Node3D
var _neve: Node3D
var _musgo: StandardMaterial3D
var _pedras: Array[StandardMaterial3D] = []
var _escura: StandardMaterial3D
var _ferro: StandardMaterial3D
var _interior: StandardMaterial3D

func _ready() -> void:
	_visor = SubViewport.new()
	_visor.size = Vector2i(256, 224)
	_visor.transparent_bg = true
	_visor.own_world_3d = true
	_visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_visor)
	_raiz = Node3D.new()
	_visor.add_child(_raiz)
	_materiais()
	_modelar()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(0, 12, 14)
	_visor.add_child(camera)
	camera.look_at(Vector3(0, 2.5, 0))
	camera.cull_mask = 7
	camera.current = true
	var ambiente := WorldEnvironment.new()
	var luz_ambiente := Environment.new()
	luz_ambiente.background_mode = Environment.BG_CLEAR_COLOR
	luz_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	luz_ambiente.ambient_light_color = Color("b7bdac")
	luz_ambiente.ambient_light_energy = 0.65
	ambiente.environment = luz_ambiente
	_visor.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52, -30, 0)
	sol.light_color = Color("ffe7c5")
	sol.light_energy = 0.65
	sol.light_cull_mask = 7
	sol.layers = 7
	_visor.add_child(sol)
	var ancora := camera.unproject_position(Vector3.ZERO).round()
	# A imagem completa serve de fundo: o piso e o túnel ficam sob os atores.
	_imagem(_visor, ancora, PROF.Z_CHAO + 3, "FundoDaEntrada")
	_frente_visor = SubViewport.new()
	_frente_visor.size = _visor.size
	_frente_visor.transparent_bg = true
	_frente_visor.world_3d = _visor.find_world_3d()
	_frente_visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_frente_visor)
	var camera_frente := Camera3D.new()
	camera_frente.projection = camera.projection
	camera_frente.size = camera.size
	_frente_visor.add_child(camera_frente)
	camera_frente.global_transform = camera.global_transform
	camera_frente.cull_mask = 4
	camera_frente.current = true
	# Só a estrutura sólida participa da oclusão. O vão permanece transparente.
	_imagem(_frente_visor, ancora, PROF.z_de(global_position.y + 24), "PilaresEArco")
	definir_estacao(estacao)

func _imagem(visor: SubViewport, ancora: Vector2, ordem: int, nome: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = nome
	sprite.centered = false
	sprite.texture = visor.get_texture()
	sprite.position = -ancora
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = ordem
	add_child(sprite)

func _cor(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 1.0
	return material

func _materiais() -> void:
	# Reaproveita a pintura aprovada da pedra do moinho, em densidade de pixel igual.
	var atlas := load("res://assets/cenario/campanha/moinho_lowpoly/pinturas_pixel_art/telhado_pedra_atlas.png") as Texture2D
	var original := atlas.get_image()
	var meio := original.get_width() / 2
	var pedra := original.get_region(Rect2i(meio + int(meio * 0.34), int(original.get_height() * 0.085), int(meio * 0.20), int(original.get_height() * 0.12)))
	pedra.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var textura := ImageTexture.create_from_image(pedra)
	for cor in [Color("fff5df"), Color("e5e5d9"), Color("f0e4cc"), Color("b1b9b5")]:
		var material := _cor(cor)
		material.albedo_texture = textura
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.55
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pedras.append(material)
	_interior = _pedras[3].duplicate() as StandardMaterial3D
	_interior.albedo_color = Color("79817d")
	_escura = _cor(Color("10191c"))
	_escura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ferro = _cor(Color("51473c"))
	_musgo = _cor(Color("5e6d38"))

func _caixa(nome: String, p: Vector3, tamanho: Vector3, material: Material, camada := 4, pai: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = tamanho
	var parte := MeshInstance3D.new()
	parte.name = nome
	parte.mesh = mesh
	parte.material_override = material
	parte.position = p
	parte.layers = camada
	parte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_raiz if pai == null else pai).add_child(parte)
	return parte

func _arco(raio_interno: float, raio_externo: float, z: float, profundidade: float, material: Material, altura_centro := 3.1, camada := 4) -> void:
	# Aduelas verdadeiras, com juntas abertas e faces frontais, superiores e laterais.
	for i in 11:
		var a := float(i) * PI / 11.0 + 0.012
		var b := float(i + 1) * PI / 11.0 - 0.012
		var vertices: Array[Vector3] = []
		for face_z in [z - profundidade * 0.5, z + profundidade * 0.5]:
			for par in [Vector2(raio_interno, a), Vector2(raio_externo, a), Vector2(raio_externo, b), Vector2(raio_interno, b)]:
				vertices.append(Vector3(cos(par.y) * par.x, altura_centro + sin(par.y) * par.x, face_z))
		var superficie := SurfaceTool.new()
		superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
		for quad in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			for indice in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				superficie.add_vertex(vertices[indice])
		superficie.generate_normals()
		var parte := MeshInstance3D.new()
		parte.name = "Aduela_%02d" % i
		parte.layers = camada
		parte.mesh = superficie.commit()
		parte.material_override = material if material != null else _pedras[i % 4]
		_raiz.add_child(parte)

func _fundo_arredondado() -> void:
	# Silhueta do fim do túnel; não existe painel retangular atrás da fachada.
	var contorno := PackedVector2Array([Vector2(-1.16, -0.7), Vector2(1.16, -0.7)])
	for i in 17:
		var angulo := PI * float(i) / 16.0
		contorno.append(Vector2(cos(angulo) * 1.16, 1.6 + sin(angulo) * 1.16))
	var indices := Geometry2D.triangulate_polygon(contorno)
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indice in indices:
		var p := contorno[indice]
		superficie.add_vertex(Vector3(p.x, p.y, -3.75))
	superficie.generate_normals()
	var fim := MeshInstance3D.new()
	fim.name = "FimArredondadoDoTunel"
	fim.mesh = superficie.commit()
	var tinta := _escura.duplicate() as StandardMaterial3D
	tinta.cull_mode = BaseMaterial3D.CULL_DISABLED
	fim.material_override = tinta
	_raiz.add_child(fim)

func _modelar() -> void:
	# Piso e paredes internas compartilham o mesmo teste de profundidade 3D.
	# Renderizá-los em imagens sobrepostas fazia o fundo cobrir toda a escadaria.
	_fundo_arredondado()
	_caixa("FundoContinuoDaEscadaria", Vector3(0, -0.65, -1.9), Vector3(3.95, 0.20, 3.8), _interior, 1)
	for anel in 4:
		var recuo := float(anel) / 3.0
		var z := -0.65 - float(anel) * 0.85
		var raio := lerpf(1.95, 1.20, recuo)
		var centro := lerpf(3.1, 1.65, recuo)
		var tinta := _interior.duplicate() as StandardMaterial3D
		tinta.albedo_color = Color("c1c3b6").lerp(Color("697b7c"), recuo)
		_arco(raio, raio + 0.35, z, 0.80, tinta, centro, 1)
		for lado in [-1.0, 1.0]:
			for fiada in 5:
				var altura := (centro + 0.50) / 5.0
				_caixa("ParedeInterior", Vector3(lado * (raio + 0.17), -0.50 + altura * (float(fiada) + 0.5), z), Vector3(0.34, altura - 0.035, 0.80), tinta, 1)
	_arco(2.0, 2.9, 0.0, 1.1, null)
	for lado in [-1.0, 1.0]:
		for fiada in 4:
			_caixa("PilarDoArco", Vector3(lado * 2.46, 0.39 + fiada * 0.78, 0), Vector3(0.89, 0.74, 1.15), _pedras[fiada % 4])
		_caixa("FundacaoDoPilar", Vector3(lado * 2.46, 0.13, 0.18), Vector3(1.40, 0.26, 1.65), _pedras[3])
		_caixa("Sapata", Vector3(lado * 2.46, 0.41, 0.12), Vector3(1.24, 0.30, 1.50), _pedras[0])
		_caixa("BordaDaSapata", Vector3(lado * 2.46, 0.59, 0.12), Vector3(1.34, 0.12, 1.60), _pedras[2])
		for coluna in 2:
			for fiada in (4 - coluna):
				_caixa("AlaArruinada", Vector3(lado * (3.75 + coluna * 1.35), 0.42 + fiada * 0.86, -0.8), Vector3(1.28, 0.81, 1.65), _pedras[(fiada + coluna) % 4])
		for trecho in 3:
			for fiada in 2:
				_caixa("MuretaLateral", Vector3(lado * 4.65, 0.40 + fiada * 0.82, 0.4 + trecho * 0.75), Vector3(1.4, 0.76, 0.70), _pedras[(trecho + fiada) % 4])
		# Dobradiças antigas com rebites, sem folha de porta bloqueando o acesso.
		_caixa("Dobradiça", Vector3(lado * 2.45, 2.40, 0.61), Vector3(0.75, 0.16, 0.09), _ferro)
		for dx in [-0.24, 0.24]:
			_caixa("Rebite", Vector3(lado * 2.45 + dx, 2.40, 0.69), Vector3(0.09, 0.09, 0.07), _pedras[2])
		for i in 7:
			var x: float = lado * (3.1 + float(i % 3) * 0.85)
			var z := -0.3 + float(i % 4) * 0.65
			var pedra := _caixa("Entulho", Vector3(x, 0.15, z), Vector3(0.44, 0.30, 0.34), _pedras[i % 4])
			pedra.rotation.y = float(i) * 0.7
		for i in 8:
			_caixa("MusgoNasJuntas", Vector3(lado * (2.10 + float(i % 3) * 0.17), 0.45 + float(i) * 0.34, 0.59), Vector3(0.19, 0.12, 0.035), _musgo)
	# Patamar elevado à frente; a descida começa depois de cruzar o arco.
	for i in 3:
		_caixa("DegrauExterno_%d" % i, Vector3(0, 0.09 + i * 0.15, 2.10 - float(i) * 0.72), Vector3(3.85, 0.18, 0.73), _pedras[i % 3], 2)
	_caixa("Soleira", Vector3(0, 0.40, -0.04), Vector3(3.85, 0.20, 0.70), _pedras[0], 1)
	for i in 4:
		_caixa("DegrauInterno_%d" % i, Vector3(0, 0.24 - i * 0.20, -0.76 - float(i) * 0.65), Vector3(3.85, 0.18, 0.66), _interior, 1)
	_caixa("PlacaAntiga", Vector3(0, 6.0, 0.25), Vector3(1.55, 1.15, 1.2), _pedras[0])
	for i in 3:
		_caixa("InscricaoCanal", Vector3(0, 5.73 + i * 0.20, 0.88), Vector3(0.85 - i * 0.18, 0.08, 0.035), _ferro)
	_neve = Node3D.new()
	_neve.name = "NeveNasSuperficiesExpostas"
	_raiz.add_child(_neve)
	var gelo := _cor(Color("d7e0dc"))
	gelo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for lado in [-1.0, 1.0]:
		for i in 7:
			_caixa("NeveMureta", Vector3(lado * (4.42 + float(i % 2) * 0.24), 1.64, 0.25 + i * 0.28), Vector3(0.60 + float(i % 3) * 0.14, 0.045, 0.34), gelo, 4, _neve)
	for i in 4:
		_caixa("NevePlaca", Vector3(-0.52 + i * 0.34, 6.62, 0.20 + float(i % 2) * 0.15), Vector3(0.38, 0.04, 0.62), gelo, 4, _neve)

func definir_estacao(indice: int) -> void:
	estacao = clampi(indice, 0, 3)
	if not is_instance_valid(_neve): return
	_neve.visible = estacao == 3
	_musgo.albedo_color = [Color("5e6d38"), Color("68733b"), Color("70613e"), Color("697365")][estacao]
	_visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frente_visor.render_target_update_mode = SubViewport.UPDATE_ONCE
