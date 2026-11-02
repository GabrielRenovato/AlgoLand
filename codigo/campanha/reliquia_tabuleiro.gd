extends SubViewport

## Miniatura 3D de interface baseada no domínio cartoon da Primeira Raiz.
## A geometria inteira gira, com laterais e verso reais; não é um sprite em um plano.
var peca: Node3D
var tempo := 0.0
var _tronco: StandardMaterial3D
var _pedra: StandardMaterial3D
var _grama: StandardMaterial3D
var _parede: StandardMaterial3D
var _telha: StandardMaterial3D
var _janela: StandardMaterial3D
var _folhas: Array[StandardMaterial3D] = []

func _ready() -> void:
	size = Vector2i(256,256)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_4X
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color.TRANSPARENT
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("ffecc5")
	ambiente.environment.ambient_light_energy = 0.5
	add_child(ambiente)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.7
	camera.position = Vector3(0,3.4,7)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40,-40,0)
	luz.light_color = Color("fff0bd")
	luz.light_energy = 1.3
	add_child(luz)
	var recorte := DirectionalLight3D.new()
	recorte.rotation_degrees = Vector3(-15,145,0)
	recorte.light_color = Color("b1dac6")
	recorte.light_energy = 0.45
	add_child(recorte)
	peca = Node3D.new()
	# Alarga a base e a copa sem alterar a altura; mantém volume ao girar.
	peca.scale = Vector3(1.12,1,1.12)
	add_child(peca)
	_tronco = _material("88542b")
	_pedra = _material("8d8365")
	_grama = _material("689a31")
	_parede = _material("f2d49c")
	_telha = _material("be5828")
	_janela = _material("ffd06a")
	_janela.emission_enabled = true
	_janela.emission = Color("e4a22c")
	_janela.emission_energy_multiplier = 0.35
	for cor in ["357543","508d39","79a43d","9fb445","c1bf50"]:
		_folhas.append(_material(cor))
	_ilha()
	_arvore()
	_casa(Vector3(-1.03,0.12,0.45),-0.25,0.8)
	_casa(Vector3(1.01,0.1,0.56),0.3,0.7)
	_casa(Vector3(0.82,0.2,-0.72),1.3,0.65)
	_porta_da_raiz()
	_process(0)

func _material(cor: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(cor)
	material.roughness = 0.85
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return material

func _malha(malha: Mesh, posicao: Vector3, escala: Vector3, material: Material, pai: Node3D = null) -> MeshInstance3D:
	var objeto := MeshInstance3D.new()
	objeto.mesh = malha
	objeto.material_override = material
	objeto.position = posicao
	objeto.scale = escala
	(pai if pai != null else peca).add_child(objeto)
	return objeto

func _bola(posicao: Vector3, escala: Vector3, material: Material) -> void:
	var esfera := SphereMesh.new()
	esfera.radial_segments = 12
	esfera.rings = 6
	_malha(esfera,posicao,escala,material)

func _ramo(inicio: Vector3, fim: Vector3, raio: float, ponta: float) -> void:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = ponta
	cilindro.bottom_radius = raio
	cilindro.height = inicio.distance_to(fim)
	cilindro.radial_segments = 9
	var ramo := _malha(cilindro,(inicio+fim)/2,Vector3.ONE,_tronco)
	ramo.quaternion = Quaternion(Vector3.UP,(fim-inicio).normalized())

func _ilha() -> void:
	var rocha := CylinderMesh.new()
	rocha.top_radius = 1.63
	rocha.bottom_radius = 1.3
	rocha.height = 0.45
	rocha.radial_segments = 18
	_malha(rocha,Vector3(0,-0.23,0),Vector3(1,1,0.88),_pedra)
	var topo := CylinderMesh.new()
	topo.top_radius = 1.62
	topo.bottom_radius = 1.64
	topo.height = 0.11
	topo.radial_segments = 18
	_malha(topo,Vector3.ZERO,Vector3(1,1,0.88),_grama)
	for i in 18:
		var angulo := i*TAU/18
		var posicao := Vector3(cos(angulo)*1.48,-0.16,sin(angulo)*1.3)
		_bola(posicao,Vector3(0.47,0.43+(i%3)*0.07,0.42),_pedra)
		if i%2 == 0:
			_bola(posicao+Vector3(0,0.23,0),Vector3(0.45,0.12,0.38),_grama)
	for i in 5:
		var pedra := BoxMesh.new()
		pedra.size = Vector3(0.42,0.055,0.16)
		var degrau := _malha(pedra,Vector3(sin(i*0.8)*0.09,0.075,0.7+i*0.15),Vector3.ONE,_parede)
		degrau.rotation.y = sin(i*1.2)*0.15

func _arvore() -> void:
	_ramo(Vector3(0,0,0),Vector3(-0.2,1.05,-0.12),0.52,0.38)
	_ramo(Vector3(-0.2,1.05,-0.12),Vector3(0.1,2.1,-0.12),0.38,0.22)
	_ramo(Vector3(0.1,2.1,-0.12),Vector3(0,2.9,-0.16),0.22,0.09)
	for i in 7:
		var angulo := i*TAU/7+0.2
		var inicio := Vector3(cos(angulo)*0.18,0.5,sin(angulo)*0.16)
		var meio := Vector3(cos(angulo)*0.83,0.16,sin(angulo)*0.77)
		_ramo(inicio,meio,0.21,0.14)
		_ramo(meio,Vector3(cos(angulo+0.15)*1.43,0.05,sin(angulo+0.15)*1.19),0.14,0.035)
	for i in 8:
		var angulo := i*TAU/8
		var altura := 1.2+(i%3)*0.42
		var fim := Vector3(cos(angulo)*1.1,altura+0.55,sin(angulo)*0.78)
		_ramo(Vector3(-0.08,altura,-0.1),fim,0.17,0.065)
		_bola(fim+Vector3(0,0.2,0),Vector3(1.2,0.68,1.0),_folhas[i%4])
		for j in 3:
			_bola(fim+Vector3(cos(j*2.1)*0.35,0.38,sin(j*2.1)*0.3),Vector3(0.6,0.42,0.57),_folhas[(i+j+1)%5])
	_bola(Vector3(-0.08,2.85,-0.16),Vector3(1.42,0.85,1.17),_folhas[2])
	_bola(Vector3(-0.27,3.14,-0.17),Vector3(0.9,0.48,0.84),_folhas[3])

func _casa(posicao: Vector3, giro: float, tamanho: float) -> void:
	var casa := Node3D.new()
	peca.add_child(casa)
	casa.position = posicao
	casa.rotation.y = giro
	casa.scale = Vector3.ONE*tamanho
	var corpo := BoxMesh.new()
	corpo.size = Vector3(0.66,0.67,0.62)
	_malha(corpo,Vector3(0,0.33,0),Vector3.ONE,_parede,casa)
	# Telhado de duas águas, com espessura e faces em todas as direções.
	for lado in [-1,1]:
		var telhado := BoxMesh.new()
		telhado.size = Vector3(0.49,0.09,0.81)
		var agua := _malha(telhado,Vector3(lado*0.18,0.83,0),Vector3.ONE,_telha,casa)
		agua.rotation.z = -lado*0.7
	var chamine := BoxMesh.new()
	chamine.size = Vector3(0.14,0.48,0.16)
	_malha(chamine,Vector3(0.19,0.97,-0.19),Vector3.ONE,_parede,casa)
	var porta := BoxMesh.new()
	porta.size = Vector3(0.17,0.34,0.03)
	_malha(porta,Vector3(0,0.18,0.325),Vector3.ONE,_tronco,casa)
	for lado in [-1,1]:
		var janela := BoxMesh.new()
		janela.size = Vector3(0.115,0.19,0.035)
		_malha(janela,Vector3(lado*0.23,0.4,0.326),Vector3.ONE,_janela,casa)
		var lateral := BoxMesh.new()
		lateral.size = Vector3(0.035,0.19,0.17)
		_malha(lateral,Vector3(lado*0.34,0.4,0),Vector3.ONE,_janela,casa)

func _porta_da_raiz() -> void:
	var porta := BoxMesh.new()
	porta.size = Vector3(0.48,0.65,0.15)
	_malha(porta,Vector3(0,0.36,0.58),Vector3.ONE,_material("493722"))
	for i in 9:
		var angulo := i*PI/8
		_bola(Vector3(cos(angulo)*0.37,0.34+sin(angulo)*0.51,0.65),Vector3(0.23,0.25,0.22),_pedra)

func _process(delta: float) -> void:
	tempo += delta
	peca.rotation.y = tempo*0.35
	peca.position.y = -1.24+sin(tempo*1.8)*0.12
