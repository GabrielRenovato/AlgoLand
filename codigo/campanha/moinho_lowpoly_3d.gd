extends Node3D
## Modelo 3D reutilizável; sobre_mapa remove o chão e delega a física ao mundo 2D.

@export_range(0.0, 2.0) var fluxo := 1.0
@export var sobre_mapa := false
@export var roda_travada := false
@export_enum("Calendário:-1", "Primavera:0", "Verão:1", "Outono:2", "Inverno:3") var estacao_previa := -1

var _roda: Node3D
var _tempo := 0.0
var _agua: ShaderMaterial
var _materiais: Array[StandardMaterial3D] = []
var _cores: Array[Color] = []
var _estacao_atual := -2
var agua_fisica: Node3D
var _velocidade_roda := 0.0

func _ready() -> void:
	var caminho := "res://assets/cenario/campanha/moinho_lowpoly/moinho_mapa.glb" if sobre_mapa else "res://assets/cenario/campanha/moinho_lowpoly/moinho.glb"
	var modelo := (load(caminho) as PackedScene).instantiate()
	add_child(modelo)
	_roda = modelo.find_child("Roda", true, false) as Node3D
	_preparar_materiais(modelo)
	_agua = ShaderMaterial.new()
	_agua.shader = load("res://assets/cenario/campanha/moinho_lowpoly/agua.gdshader")
	_agua.set_shader_parameter("sobre_mapa", sobre_mapa)
	if not sobre_mapa:
		_superficie(Vector3(-2.7, 0.145, 0.2), Vector2(1.37, 6.6))
	_superficie(Vector3(-2.65, 3.24, -1.85), Vector2(0.62, 2.02))
	agua_fisica = preload("res://codigo/campanha/agua_roda_fisica.gd").new()
	agua_fisica.name = "AguaComGravidade"
	agua_fisica.roda = _roda
	add_child(agua_fisica)
	if sobre_mapa:
		_atualizar_estacao()
		return
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
				material.vertex_color_use_as_albedo = true
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
	if agua_fisica:
		agua_fisica.definir_inverno(estacao == 3)

func _process(delta: float) -> void:
	_tempo += delta
	if _roda:
		_velocidade_roda = move_toward(_velocidade_roda, 0.0 if roda_travada else PI / 6.0 * fluxo, delta * 0.35)
		_roda.rotation.x -= delta * _velocidade_roda
	if agua_fisica:
		agua_fisica.fluxo = fluxo
	if _agua:
		_agua.set_shader_parameter("tempo", _tempo)
		_agua.set_shader_parameter("fluxo", fluxo)
	_atualizar_estacao()
