extends "res://codigo/cidade/casa_exterior.gd"
## Protótipo 3D real, com a mesma âncora da soleira e colisões da casa original.
const TAMANHO_LOGICO := Vector2i(160,160)
const AMOSTRAS_PIXEL := 2

var viewport_3d: SubViewport
var modelo: Node3D
var camera_3d: Camera3D
var estacao_3d := -1
var _telhas: Array[MeshInstance3D] = []
var _folhas: Array[MeshInstance3D] = []
var _neve: Array[MeshInstance3D] = []
var _materiais: Dictionary = {}

func _montar_sprite(_ancora: Vector2) -> void:
	viewport_3d = SubViewport.new()
	viewport_3d.name = "Maquete3D"
	viewport_3d.size = TAMANHO_LOGICO*AMOSTRAS_PIXEL
	viewport_3d.transparent_bg = true
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport_3d)
	modelo = Node3D.new()
	modelo.name = "CasaModelada"
	viewport_3d.add_child(modelo)
	camera_3d = Camera3D.new()
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.size = 5.5
	viewport_3d.add_child(camera_3d)
	camera_3d.position = Vector3(0,8.2,10)
	camera_3d.look_at(Vector3(0,1.2,0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45,-30,0)
	luz.light_energy = 1.15
	viewport_3d.add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9c9e0")
	env.ambient_light_energy = 0.65
	ambiente.environment = env
	viewport_3d.add_child(ambiente)
	_construir()
	var sprite := Sprite2D.new()
	sprite.name = "Fachada"
	sprite.texture = viewport_3d.get_texture()
	sprite.centered = false
	sprite.scale = Vector2.ONE/float(AMOSTRAS_PIXEL)
	sprite.offset = -camera_3d.unproject_position(Vector3(0,0,1.05))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var acabamento := ShaderMaterial.new()
	acabamento.shader = preload("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
	acabamento.set_shader_parameter("tons",12.0)
	sprite.material = acabamento
	add_child(sprite)
	_area_visual = Rect2(-60,-108,120,115)
	_atualizar_estacao_3d()

func _material(cor: String) -> ShaderMaterial:
	if _materiais.has(cor):return _materiais[cor]
	var m := ShaderMaterial.new()
	m.shader = preload("res://codigo/cenario/casa_pintada_3d.gdshader")
	m.set_shader_parameter("cor",Color(cor))
	_materiais[cor] = m
	return m

func _caixa(nome: String, pos: Vector3, tamanho: Vector3, cor: String, giro := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nome
	m.mesh = _chanfrar(tamanho)
	m.position = pos
	m.rotation.z = giro
	m.material_override = _material(cor)
	modelo.add_child(m)
	return m

func _chanfrar(tamanho: Vector3) -> ArrayMesh:
	var h := tamanho*.5
	var c := minf(.045,minf(h.x,h.z)*.26)
	var anel := [Vector2(-h.x+c,-h.z),Vector2(h.x-c,-h.z),Vector2(h.x,-h.z+c),Vector2(h.x,h.z-c),Vector2(h.x-c,h.z),Vector2(-h.x+c,h.z),Vector2(-h.x,h.z-c),Vector2(-h.x,-h.z+c)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a: Vector2=anel[i]
		var b: Vector2=anel[(i+1)%8]
		var pontos := [Vector3(a.x,-h.y,a.y),Vector3(b.x,-h.y,b.y),Vector3(b.x,h.y,b.y),Vector3(a.x,h.y,a.y)]
		for j in [0,1,2,0,2,3]:st.add_vertex(pontos[j])
		for sinal in [-1,1]:
			for ponto in [Vector3(0,sinal*h.y,0),Vector3(a.x,sinal*h.y,a.y),Vector3(b.x,sinal*h.y,b.y)]:st.add_vertex(ponto)
	st.generate_normals()
	return st.commit()

func _viga(a: Vector3,b: Vector3,largura: float,cor: String) -> void:
	var m := _caixa("Viga",(a+b)*0.5,Vector3(largura,a.distance_to(b),largura),cor)
	m.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _construir() -> void:
	# Casa original: telhado transversal e frontão central sobre a porta.
	_caixa("Paredes",Vector3(0,.91,0),Vector3(3.35,1.52,1.95),"e8d5ad")
	for fila in 2:
		for pedra in 13:
			var x := -1.57+pedra*.26+(fila%2)*.025
			_caixa("PedraFundacao",Vector3(x,.10+fila*.18,1.02),Vector3(.25,.17,.24),["a99d87","c0b299","b5aa94","c7baa1"][pedra%4])
	for x in [-1.60,-.52,.52,1.60]:
		_caixa("PilarMadeira",Vector3(x,.98,1.04),Vector3(.17,1.35,.18),"9d6b3c")
	for y in [.39,1.48]:
		_caixa("TravessaFachada",Vector3(0,y,1.025),Vector3(3.28,.13,.14),"9b693b")
	# Duas águas: cumeeira paralela à fachada, como na arte canônica.
	for lado in [-1,1]:
		var apoio := _caixa("BaseTelhado",Vector3(0,2.12,-.27+lado*.78),Vector3(4.0,.10,1.88),"a85d2e")
		apoio.rotation.x=lado*.584
		if lado<0:
			apoio.position.z=-.62
			apoio.scale.z=.67
			apoio.rotation.x=-.973
		var arrays := apoio.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var global: Vector3=apoio.transform*vertices[i]
			vertices[i].x*=lerpf(.77,1.0,clampf(absf(global.z+.27)/1.5,0,1))
		arrays[Mesh.ARRAY_VERTEX]=vertices
		var base := ArrayMesh.new()
		base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		apoio.mesh=base
		for fila in 4:
			for coluna in 16:
				var distancia := .16+fila*.36
				var z: float=-.27+lado*distancia
				if lado<0:z=-.27-distancia*.45
				var y: float=2.65-distancia*.66
				var largura_fila := lerpf(.77,1.0,fila/3.0)
				if lado<0:largura_fila*=.76
				var x: float=(-1.82+coluna*.243)*largura_fila
				var t := _telha_curva(Vector3(x,y,z),lado)
				t.basis=Basis(Vector3.RIGHT,.584 if lado>0 else -.973)*Basis(Vector3.UP,PI*.5)
				t.scale.z=.80*largura_fila
				_telhas.append(t)
				var n := _telha_curva(Vector3(x,y+.06,z),lado)
				n.basis=t.basis;n.scale=t.scale;n.material_override=_material("edf2ee");_neve.append(n)
	for x in [-1.98,1.98]:
		for lado in [1]:
			_viga(Vector3(x*.77,2.70,-.27),Vector3(x,1.69,-.27+lado*1.53),.16,"865b35")
	for z in [1.27]:
		_caixa("BeiralPrincipal",Vector3(0,1.67,z),Vector3(4.07,.16,.18),"956538")
	var cumeeira := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius=.115;cilindro.bottom_radius=.115;cilindro.height=3.18;cilindro.radial_segments=10
	cumeeira.mesh=cilindro;cumeeira.rotation.z=PI*.5;cumeeira.position=Vector3(0,2.68,-.27)
	cumeeira.material_override=_material("d58438");modelo.add_child(cumeeira);_telhas.append(cumeeira)

	# Pequeno frontão de madeira avançado sobre a porta.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ponto in [Vector3(-.83,1.53,1.29),Vector3(.83,1.53,1.29),Vector3(0,2.37,1.29)]:st.add_vertex(ponto)
	st.generate_normals()
	var frontao := MeshInstance3D.new()
	frontao.name="FrontaoOriginal";frontao.mesh=st.commit();frontao.material_override=_material("ecddb9");modelo.add_child(frontao)
	for lado in [-1,1]:
		for fila in 4:
			for coluna in 4:
				var x: float=lado*(.10+fila*.22)
				var y: float=2.43-absf(x)*1.01
				var z: float=.45+coluna*.31
				var t := _telha_curva(Vector3(x,y,z),lado)
				t.rotation.z=-lado*.79;_telhas.append(t)
				var n := _telha_curva(Vector3(x,y+.065,z),lado)
				n.rotation=t.rotation;n.material_override=_material("edf2ee");_neve.append(n)
		_viga(Vector3(0,2.47,1.54),Vector3(lado*.98,1.48,1.54),.17,"986537")
	_caixa("BaseFrontao",Vector3(0,1.54,1.35),Vector3(1.75,.15,.22),"a87542")
	_caixa("VigaCentralFrontao",Vector3(0,1.94,1.35),Vector3(.15,.70,.12),"996639")
	for x in [-.40,.40]:
		_caixa("VigaFrontao",Vector3(x,1.74,1.34),Vector3(.11,.30,.11),"9b6b3e")
	# Porta retangular de tábuas, sem arco nem alterações cosméticas.
	_caixa("PortaFundo",Vector3(0,.79,1.07),Vector3(.80,1.22,.15),"65472d")
	for tabua in 6:
		_caixa("TabuaPorta",Vector3((tabua-2.5)*.117,.77,1.17),Vector3(.111,1.10,.065),["a9753f","b78247","ae7942"][tabua%3])
	_caixa("VergaPorta",Vector3(0,1.41,1.22),Vector3(.88,.13,.16),"ae7b46")
	_caixa("Soleira",Vector3(0,.18,1.16),Vector3(.82,.12,.28),"c3b59a")
	_caixa("Degrau",Vector3(0,.055,1.32),Vector3(.94,.13,.40),"cbbda3")
	var argola := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius=.052;toro.outer_radius=.075;toro.rings=14;toro.ring_segments=6
	argola.name="BatedorArgola";argola.mesh=toro;argola.rotation.x=PI*.5;argola.position=Vector3(0,.91,1.225)
	argola.material_override=_material("45413b");modelo.add_child(argola)
	_volume("SuporteArgola",Vector3(0,.98,1.24),Vector3(.065,.065,.05),"6f6859")
	_caixa("Fechadura",Vector3(-.22,.70,1.23),Vector3(.035,.11,.035),"4f483b")
	for x in [-1.04,1.04]:
		_caixa("JanelaFundo",Vector3(x,.95,1.04),Vector3(.65,.62,.16),"775033")
		_caixa("Vidro",Vector3(x,.96,1.145),Vector3(.48,.43,.06),"326580")
		for altura in [.63,1.30]:
			_caixa("MolduraJanela",Vector3(x,altura,1.15),Vector3(.80,.15,.20),"b78044")
		for lado in [-1,1]:
			_caixa("LateralJanela",Vector3(x+lado*.285,.96,1.13),Vector3(.09,.53,.16),"986438")
		_caixa("CruzJanela",Vector3(x,.96,1.19),Vector3(.045,.44,.05),"c08a4b")
		_caixa("CruzJanela",Vector3(x,.96,1.19),Vector3(.49,.045,.05),"c08a4b")
		for canto in [-1,1]:
			_caixa("ReflexoVidro",Vector3(x+canto*.12,1.06,1.18),Vector3(.09,.04,.018),"6590a1",.55)
	# Chaminé de pedra na direita do telhado, com boca aberta.
	for fila in 5:
		for lado in [-1,1]:
			_caixa("PedraChamine",Vector3(1.22+lado*.105,2.34+fila*.17,-.18),Vector3(.205,.16,.43),["a99d87","c3b69b","b5aa94"][fila%3])
	for lado in [-1,1]:
		_caixa("BocaChamine",Vector3(1.22+lado*.215,3.14,-.18),Vector3(.12,.16,.55),"d0c1a5")
		_caixa("BocaChamine",Vector3(1.22,3.14,-.18+lado*.215),Vector3(.32,.16,.12),"d0c1a5")

func _volume(nome: String,pos: Vector3,tamanho: Vector3,cor: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radial_segments=7;esfera.rings=3
	esfera.radius=.5;esfera.height=1.0
	m.name=nome;m.mesh=esfera;m.position=pos;m.scale=tamanho
	m.material_override=_material(cor);modelo.add_child(m)
	return m

func _disco(nome: String,pos: Vector3,raio: float,espessura: float,cor: String) -> void:
	var m := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius=raio;cilindro.bottom_radius=raio;cilindro.height=espessura;cilindro.radial_segments=16
	m.name=nome;m.mesh=cilindro;m.position=pos;m.rotation.x=PI*.5
	m.material_override=_material(cor);modelo.add_child(m)

func _telha_curva(pos: Vector3,lado: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segmento in 6:
		var a := PI*segmento/6.0
		var b := PI*(segmento+1)/6.0
		var pontos := [Vector3(-.19,sin(a)*.065,cos(a)*.175),Vector3(.19,sin(a)*.065,cos(a)*.175),Vector3(.19,sin(b)*.065,cos(b)*.175),Vector3(-.19,sin(b)*.065,cos(b)*.175)]
		for i in [0,1,2,0,2,3]:st.add_vertex(pontos[i])
		var labio := [Vector3(-.19,sin(a)*.065+.023,cos(a)*.175),Vector3(-.145,sin(a)*.065+.023,cos(a)*.175),Vector3(-.145,sin(b)*.065+.023,cos(b)*.175),Vector3(-.19,sin(b)*.065+.023,cos(b)*.175)]
		for i in [0,1,2,0,2,3]:st.add_vertex(labio[i])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.name="TelhaCurva";m.mesh=st.commit();m.position=pos;m.rotation.z=-lado*.576
	m.material_override=_material("c77a45");modelo.add_child(m)
	return m

func _atualizar_estacao_3d() -> void:
	var atual := preload("res://codigo/cidade/interiores_detalhados.gd").estacao(self)
	if atual==estacao_3d:return
	estacao_3d=atual
	for i in _telhas.size():
		_telhas[i].material_override=_material([["d58438","e49543","c77730"],["dd8d3b","e99b49","cd7e32"],["a76239","b57040","9e5b36"],["8e6652","a3775c","986c53"]][atual][i%3])
	for i in _folhas.size():
		_folhas[i].visible=atual!=3
		_folhas[i].material_override=_material((["688b4d","598044","a17b40","839283"] if i%2==0 else ["e3a2a9","edca72","d89a54","dbe6e5"])[atual])
	for m in _neve:m.visible=atual==3
	for m in modelo.get_children():
		if m.has_meta("flor_sazonal"):m.visible=atual!=3

func _process(delta: float) -> void:
	super._process(delta)
	_atualizar_estacao_3d()
