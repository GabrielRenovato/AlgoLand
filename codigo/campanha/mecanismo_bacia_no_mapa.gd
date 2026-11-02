extends Node2D
## Renderiza os GLBs derivados das referências; pivôs e chão permanecem independentes.
var tipo := 0
var estacao := 0
var estado := 0
var _abertura := 0.0
var _alvo_abertura := 0.0
var _camera: Camera3D
var _base_modelo := Basis.IDENTITY
var _ancora := Vector2.ZERO
var _folha: Node3D
var _alavanca: Node3D
var _pinhao: Node3D
var _materiais: Array[StandardMaterial3D] = []
var _cores: Array[Color] = []
var _reacao := 0.0
var _tempo := 0.0

func _ready() -> void:
	var visor := SubViewport.new()
	visor.size = Vector2i(96,128) if tipo == 0 else Vector2i(32,48)
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(visor)
	var nome := "comporta" if tipo == 0 else "registro"
	var modelo := (load("res://assets/cenario/campanha/mecanismos_3d/%s.glb" % nome) as PackedScene).instantiate()
	visor.add_child(modelo)
	if tipo == 0:
		# Canal leste-oeste: folha transversal, com um apoio em cada margem.
		modelo.rotation.y = PI / 2.0
		modelo.scale.x = 1.2
	_base_modelo = modelo.basis
	_folha = modelo.find_child("Folha",true,false) as Node3D
	_alavanca = modelo.find_child("Alavanca",true,false) as Node3D
	_pinhao = modelo.find_child("Pinhao",true,false) as Node3D
	_copiar_materiais(modelo)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 8.0 if tipo == 0 else 2.9
	# O cenário usa frente elevada, sem yaw: vigas e bases seguem os eixos do mapa.
	_camera.position = Vector3(0,7,9)
	visor.add_child(_camera)
	_camera.look_at(Vector3(0,1.0 if tipo == 0 else 0.5,0))
	_camera.current = true
	var ambiente := WorldEnvironment.new()
	var configuracao := Environment.new()
	configuracao.background_mode = Environment.BG_CLEAR_COLOR
	configuracao.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	configuracao.ambient_light_color = Color("9abbd0")
	configuracao.ambient_light_energy = .35
	ambiente.environment = configuracao
	visor.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52,-35,0)
	sol.light_color = Color("ffe2b8")
	sol.light_energy = .95
	sol.shadow_enabled = true
	sol.shadow_normal_bias = .12
	visor.add_child(sol)
	_ancora = _camera.unproject_position(Vector3.ZERO)
	var imagem := Sprite2D.new()
	imagem.centered = false
	imagem.texture = visor.get_texture()
	imagem.position = (-_ancora*2.0).round()
	imagem.scale = Vector2.ONE*2.0
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(imagem)
	z_as_relative = false
	var base_frontal := projetar(Vector3(-2,0,0)).y if tipo == 0 else position.y
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(base_frontal)
	definir_estacao(estacao)

func projetar(ponto: Vector3) -> Vector2:
	return position+(_camera.unproject_position(_base_modelo*ponto)-_ancora)*2.0

func ponto_acionamento() -> Vector2:
	return projetar(Vector3(-2,0,.5))+Vector2(0,12)

func bases_fisicas() -> Array[PackedVector2Array]:
	var bases: Array[PackedVector2Array] = []
	for x in [-2.0,2.0]:
		var pontos := PackedVector2Array()
		for d in [Vector3(-.44,0,-.4),Vector3(.44,0,-.4),Vector3(.44,0,.4),Vector3(-.44,0,.4)]:
			pontos.append(projetar(Vector3(x,0,0)+d))
		bases.append(pontos)
	return bases

func _copiar_materiais(no: Node) -> void:
	if no is MeshInstance3D:
		for i in no.mesh.get_surface_count():
			var original := no.mesh.surface_get_material(i) as StandardMaterial3D
			if original:
				var material := original.duplicate() as StandardMaterial3D
				no.set_surface_override_material(i,material)
				_materiais.append(material)
				_cores.append(material.albedo_color)
	for filho in no.get_children():
		_copiar_materiais(filho)

func definir_estado(valor: int) -> void:
	estado = valor

func definir_aberta(valor: bool) -> void:
	_alvo_abertura = 0.90 if valor else 0.0

func reagir_tentativa(sucesso: bool) -> void:
	_reacao = 0.0 if sucesso else 0.18

func definir_estacao(indice: int) -> void:
	estacao = indice
	for i in _materiais.size():
		var material := _materiais[i]
		material.albedo_color = _cores[i]
		if indice == 1:
			material.albedo_color = _cores[i]*Color(1.05,1,.94)
		elif indice == 2:
			material.albedo_color = _cores[i]*Color(1,.94,.85)
		elif indice == 3:
			material.albedo_color = _cores[i]*Color(.87,.94,1)
			if "pedra_clara" in material.resource_name:
				material.albedo_color = _cores[i].lerp(Color("cbdedc"),.6)

func _process(delta: float) -> void:
	_tempo += delta
	_reacao = move_toward(_reacao,0.0,delta*.22)
	_abertura = move_toward(_abertura,_alvo_abertura,delta*.55)
	if _folha:
		_folha.position.y = -0.36+_abertura
	if _pinhao:
		_pinhao.rotation.z = -_abertura/.135
	if _alavanca:
		var angulo := -0.65+estado*.65 if tipo == 1 else -_abertura*.8
		if tipo == 0: angulo += sin(_tempo*38.0)*_reacao
		_alavanca.rotation.z = lerp_angle(_alavanca.rotation.z,angulo,1.0-exp(-delta*8.0))
