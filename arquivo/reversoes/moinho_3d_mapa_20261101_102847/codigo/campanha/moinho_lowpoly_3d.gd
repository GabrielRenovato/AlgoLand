extends Node3D
## Asset 3D independente; não altera o mapa 2D da campanha nem o save.

@export_range(0.0, 2.0) var fluxo := 1.0
@export_enum("Calendário:-1", "Primavera:0", "Verão:1", "Outono:2", "Inverno:3") var estacao_previa := -1

var _roda: Node3D
var _tempo := 0.0
var _agua: ShaderMaterial
var _queda: ShaderMaterial
var _materiais: Array[StandardMaterial3D] = []
var _cores: Array[Color] = []
var _gotas: MultiMeshInstance3D
var _estacao_atual := -2

func _ready() -> void:
	var modelo := (load("res://assets/cenario/campanha/moinho_lowpoly/moinho.glb") as PackedScene).instantiate()
	add_child(modelo)
	_roda = modelo.find_child("Roda", true, false) as Node3D
	_preparar_materiais(modelo)
	_agua = ShaderMaterial.new()
	_agua.shader = load("res://assets/cenario/campanha/moinho_lowpoly/agua.gdshader")
	_queda = _agua.duplicate() as ShaderMaterial
	_queda.set_shader_parameter("queda", true)
	_superficie(Vector3(-2.7, 0.145, 0.2), Vector2(1.37, 6.6))
	_superficie(Vector3(-2.65, 3.24, -1.85), Vector2(0.62, 2.02))
	_fita(false)
	_fita(true)
	_preparar_gotas()
	# Colisões limitadas às bases; telhado e água não fecham as passagens.
	_colisao(Vector3(0.5, 1.7, 0.15), Vector3(4.15, 3.4, 3.25))
	for x in [-3.58, -1.83]:
		_colisao(Vector3(x, 0.2, 0.15), Vector3(0.34, 0.5, 6.85))
	_colisao(Vector3(-2.86, 1.55, 0.2), Vector3(0.85, 2.8, 2.8))
	_atualizar_estacao()

func _preparar_materiais(no: Node) -> void:
	if no is MeshInstance3D:
		var instancia := no as MeshInstance3D
		for i in instancia.mesh.get_surface_count():
			var original := instancia.mesh.surface_get_material(i) as StandardMaterial3D
			if original:
				var material := original.duplicate() as StandardMaterial3D
				instancia.set_surface_override_material(i, material)
				_materiais.append(material)
				_cores.append(material.albedo_color)
	for filho in no.get_children():
		_preparar_materiais(filho)

func _superficie(posicao: Vector3, tamanho: Vector2) -> void:
	var instancia := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = tamanho
	plano.subdivide_width = 18
	plano.subdivide_depth = 64
	instancia.mesh = plano
	instancia.material_override = _agua
	instancia.position = posicao
	add_child(instancia)

func _fita(sobre_roda: bool) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in range(65):
		var t := float(j) / 64.0
		var y: float
		var z: float
		if sobre_roda:
			var angulo := -0.51 - t * 2.48
			y = 1.55 + 1.32 * cos(angulo)
			z = 0.2 + 1.32 * sin(angulo)
		else:
			var p := t * 0.43
			y = 3.24 - 3.05 * p * p
			z = -0.8 + p * 0.85
		for i in range(13):
			vertices.append(Vector3(-3.12 + float(i) / 12.0 * 0.56, y, z))
			uvs.append(Vector2(float(i) / 12.0, t))
	for j in range(64):
		for i in range(12):
			var a := j * 13 + i
			indices.append_array(PackedInt32Array([a, a + 13, a + 1, a + 13, a + 14, a + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	# As normais são necessárias ao pipeline espacial, inclusive na lâmina translúcida.
	var normais := PackedVector3Array()
	normais.resize(vertices.size())
	normais.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normais
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instancia := MeshInstance3D.new()
	instancia.mesh = malha
	instancia.material_override = _queda
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)

func _preparar_gotas() -> void:
	_gotas = MultiMeshInstance3D.new()
	var malha := SphereMesh.new()
	malha.radius = 0.018
	malha.height = 0.036
	malha.radial_segments = 6
	malha.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("bedfe0")
	material.roughness = 0.12
	malha.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = malha
	multi.instance_count = 160
	_gotas.multimesh = multi
	_gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gotas)

func _colisao(posicao: Vector3, tamanho: Vector3) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = posicao
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	corpo.add_child(forma)
	add_child(corpo)

func _atualizar_estacao() -> void:
	var estacao := estacao_previa
	var calendario := get_node_or_null("/root/Calendario")
	if estacao < 0:
		estacao = int(calendario.call("estacao")) if calendario else 0
	if estacao == _estacao_atual:
		return
	_estacao_atual = estacao
	var gramas := [Color("71845b"), Color("6e814c"), Color("9a794a"), Color("d7dfdc")]
	var telhas := [Color("b95732"), Color("c16137"), Color("a94f30"), Color("c9c9be")]
	for i in _materiais.size():
		var material := _materiais[i]
		material.albedo_color = _cores[i]
		if material.resource_name in ["Material_72835b", "Material_496747"]:
			material.albedo_color = gramas[estacao]
		elif material.resource_name in ["Material_b95832", "Material_c46438", "Material_cb7141", "Material_ae4d2c", "Material_dd824c"]:
			material.albedo_color = _cores[i].lerp(telhas[estacao], 0.7 if estacao == 3 else 0.25)
	_agua.set_shader_parameter("inverno", estacao == 3)
	_queda.set_shader_parameter("inverno", estacao == 3)

func _process(delta: float) -> void:
	_tempo += delta
	if _roda:
		_roda.rotation.x -= delta * PI / 6.0 * fluxo
	for material in [_agua, _queda]:
		if material:
			material.set_shader_parameter("tempo", _tempo)
			material.set_shader_parameter("fluxo", fluxo)
	if _gotas:
		_gotas.visible = fluxo > 0.01
		for i in _gotas.multimesh.instance_count:
			var t := fmod(_tempo * (0.6 + fluxo * 0.45) + i * 0.6180339, 1.0)
			var a := i * 2.399963
			var r := 0.13 + t * 0.6
			var p := Vector3(-2.8 + cos(a) * r, 0.17 + t * (1.0 - t) * (0.8 + (i % 5) * 0.28), -0.12 + sin(a) * r + t * 0.28)
			_gotas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (1.0 - t)), p))
	_atualizar_estacao()
