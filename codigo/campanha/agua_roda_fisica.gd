extends Node3D
## Simulação localizada: gravidade, encontro com o aro/pás e impacto no canal.
## Não é um solver volumétrico; mantém custo e trajetória estáveis no cooperativo.
signal impacto(posicao: Vector3, intensidade: float)
const CENTRO := Vector3(-2.86, 1.55, 0.2)
const RAIO := 1.31
const ALTURA_CANAL := 0.13
const GRAVIDADE := Vector3(0, -9.8, 0)
const TOTAL_GOTAS := 384
const TOTAL_PAS := 12
var fluxo := 0.0
var roda: Node3D
var _posicoes := PackedVector3Array()
var _velocidades := PackedVector3Array()
var _vidas := PackedFloat32Array()
var _colidiu := PackedByteArray()
var _agua_pas := PackedFloat32Array()
var _gotas: MultiMeshInstance3D
var _lamina: MeshInstance3D
var _peliculas: MultiMeshInstance3D
var _material: ShaderMaterial
var _cursor := 0
var _emissao := 0.0
var _rng := RandomNumberGenerator.new()
var _tempo := 0.0

func _ready() -> void:
	_rng.seed = 40319
	_posicoes.resize(TOTAL_GOTAS)
	_velocidades.resize(TOTAL_GOTAS)
	_vidas.resize(TOTAL_GOTAS)
	_colidiu.resize(TOTAL_GOTAS)
	_agua_pas.resize(TOTAL_PAS)
	_gotas = MultiMeshInstance3D.new()
	_gotas.name = "GotasComGravidade"
	var gota := SphereMesh.new()
	gota.radius = 0.028
	gota.height = 0.056
	gota.radial_segments = 6
	gota.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b9e5e8")
	material.roughness = 0.09
	material.emission_enabled = true
	material.emission = Color("183b43")
	material.emission_energy_multiplier = 0.35
	gota.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = gota
	multi.instance_count = TOTAL_GOTAS
	_gotas.multimesh = multi
	_gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gotas)
	for i in TOTAL_GOTAS:
		_ocultar(i)
	_lamina = MeshInstance3D.new()
	_lamina.name = "CorrenteBalistica"
	_lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamina)
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/cenario/campanha/moinho_lowpoly/agua.gdshader")
	_material.set_shader_parameter("queda", true)
	_material.set_shader_parameter("sobre_mapa", true)
	_lamina.material_override = _material
	_peliculas = MultiMeshInstance3D.new()
	_peliculas.name = "AguaRetidaNasPas"
	var filme := BoxMesh.new()
	filme.size = Vector3(0.54, 0.025, 0.16)
	var filme_material := StandardMaterial3D.new()
	filme_material.albedo_color = Color(0.30, 0.62, 0.66, 0.65)
	filme_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	filme_material.roughness = 0.08
	filme.material = filme_material
	var instancias := MultiMesh.new()
	instancias.transform_format = MultiMesh.TRANSFORM_3D
	instancias.mesh = filme
	instancias.instance_count = TOTAL_PAS
	_peliculas.multimesh = instancias
	_peliculas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_peliculas)
	for i in TOTAL_PAS:
		_peliculas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))

func definir_inverno(valor: bool) -> void:
	_material.set_shader_parameter("inverno", valor)

func _ocultar(i: int) -> void:
	_gotas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))

func _emitir(p: Vector3, v: Vector3, bate_na_roda := true, vida := 2.0) -> void:
	var i := _cursor
	_cursor = (_cursor + 1) % TOTAL_GOTAS
	_posicoes[i] = p
	_velocidades[i] = v
	_vidas[i] = vida
	_colidiu[i] = 0 if bate_na_roda else 1

func _respingar(p: Vector3, forca: float) -> void:
	impacto.emit(p, forca)
	for j in range(3 + int(forca * 3.0)):
		var a := _rng.randf_range(0, TAU)
		var velocidade := _rng.randf_range(0.25, 1.1) * (0.5 + forca)
		_emitir(p + Vector3(0, 0.035, 0), Vector3(cos(a) * velocidade, _rng.randf_range(0.5, 1.6), sin(a) * velocidade), false, 0.65)
		_colidiu[posmod(_cursor - 1, TOTAL_GOTAS)] = 2

func _physics_process(delta: float) -> void:
	_tempo += delta
	var entrada := maxf(fluxo, 0.0)
	_emissao += delta * entrada * 105.0
	while _emissao >= 1.0:
		_emissao -= 1.0
		_emitir(Vector3(_rng.randf_range(-3.10, -2.57), 3.24, -0.80), Vector3(_rng.randf_range(-0.04, 0.04), -0.08, 1.50))
	var angulo_roda := roda.rotation.x if is_instance_valid(roda) else 0.0
	for i in TOTAL_GOTAS:
		if _vidas[i] <= 0.0:
			continue
		_vidas[i] -= delta
		var antes := _posicoes[i]
		var velocidade := _velocidades[i] + GRAVIDADE * delta
		var depois := antes + velocidade * delta
		var distancia := Vector2(depois.y - CENTRO.y, depois.z - CENTRO.z).length()
		var distancia_antes := Vector2(antes.y - CENTRO.y, antes.z - CENTRO.z).length()
		if _colidiu[i] == 0 and distancia <= RAIO and distancia_antes > RAIO and depois.x > -3.25 and depois.x < -2.45:
			var theta := atan2(depois.z - CENTRO.z, depois.y - CENTRO.y)
			var indice := posmod(int(round((theta - angulo_roda) / TAU * TOTAL_PAS)), TOTAL_PAS)
			_agua_pas[indice] = minf(_agua_pas[indice] + 0.014, 0.20)
			# Contato tangente à roda; o restante acompanha a pá e escorre depois.
			var radial := Vector3(0, cos(theta), sin(theta))
			depois = Vector3(depois.x, CENTRO.y, CENTRO.z) + radial * (RAIO + 0.035)
			velocidade = Vector3(_rng.randf_range(-0.35, 0.35), sin(theta) * 0.65, -cos(theta) * 0.65)
			_colidiu[i] = 1
		elif depois.y <= ALTURA_CANAL:
			if _colidiu[i] < 2:
				_respingar(Vector3(depois.x, ALTURA_CANAL, depois.z), clampf(-velocidade.y * 0.10, 0.15, 0.8))
			_vidas[i] = 0.0
		if _vidas[i] <= 0.0:
			_ocultar(i)
			continue
		_posicoes[i] = depois
		_velocidades[i] = velocidade
		var tamanho := clampf(_vidas[i] * 2.0, 0.25, 1.0)
		var base := Basis.IDENTITY.scaled(Vector3(tamanho * 0.7, tamanho * 1.5, tamanho * 0.7))
		_gotas.multimesh.set_instance_transform(i, Transform3D(base, depois))
	for i in TOTAL_PAS:
		if _agua_pas[i] < 0.001:
			_peliculas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		var theta := wrapf(angulo_roda + i * TAU / TOTAL_PAS, -PI, PI)
		# As pás seguram água na parte alta e descarregam na descida.
		var taxa := 0.20 if theta > -1.2 and theta < -0.15 else 2.5
		var descarte := minf(_agua_pas[i], taxa * delta * _agua_pas[i])
		_agua_pas[i] -= descarte
		var filme_posicao := CENTRO + Vector3(0, cos(theta) * 1.375, sin(theta) * 1.375)
		var filme_base := Basis(Vector3.RIGHT, theta).scaled(Vector3(1, 1, minf(_agua_pas[i] * 18.0, 1.0)))
		_peliculas.multimesh.set_instance_transform(i, Transform3D(filme_base, filme_posicao))
		if _rng.randf() < descarte * 330.0:
			var p := CENTRO + Vector3(_rng.randf_range(-0.24, 0.24), cos(theta) * 1.35, sin(theta) * 1.35)
			_emitir(p, Vector3(_rng.randf_range(-0.12, 0.12), sin(theta) * 0.55, -cos(theta) * 0.55), false)
	_atualizar_lamina()

func _atualizar_lamina() -> void:
	_lamina.visible = fluxo > 0.01
	if not _lamina.visible:
		return
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas: Array[Vector3] = []
	for i in range(33):
		var t := i / 32.0 * 0.46
		var p := Vector3(-2.84, 3.24 - 0.08 * t - 4.9 * t * t, -0.80 + 1.50 * t)
		if Vector2(p.y - CENTRO.y, p.z - CENTRO.z).length() < RAIO:
			break
		linhas.append(p)
	for j in range(linhas.size() - 1):
		for i in range(8):
			for indice in [Vector2i(i, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]:
				var u: float = float(indice.x) / 8.0
				var v := float(indice.y) / maxf(linhas.size() - 1, 1)
				var p := linhas[indice.y]
				p.x += (u - 0.5) * (0.53 - v * 0.07) + sin(v * 17.0 - _tempo * 8.0 + u * 11.0) * 0.009
				ferramenta.set_uv(Vector2(u, v))
				ferramenta.add_vertex(p)
	ferramenta.generate_normals()
	_lamina.mesh = ferramenta.commit()
	_material.set_shader_parameter("tempo", _tempo)
	_material.set_shader_parameter("fluxo", fluxo)
