extends Node3D
## Fontes: arte/fontes/campanha/mecanismos_3d/*-referencia.png.
## Geometria reutilizável, exportada em GLB com as partes móveis separadas.
var tipo := 0
var _materiais: Dictionary = {}
const CORES := {"madeira":"926039", "madeira_clara":"b78349", "madeira_escura":"69462e", "pedra":"828e83", "pedra_clara":"a4ad99", "ferro":"3d4d50", "metal_claro":"7b9090", "latao":"bd9450"}

func _ready() -> void:
	if tipo == 0:
		_comporta()
	else:
		_registro()
		scale = Vector3.ONE*0.8
	_compactar(self)

func _material(cor: String) -> StandardMaterial3D:
	if not _materiais.has(cor):
		var m := StandardMaterial3D.new()
		m.resource_name = cor
		m.albedo_color = Color(CORES[cor])
		m.roughness = 0.38 if cor in ["ferro","metal_claro","latao"] else 0.86
		m.metallic = 0.35 if cor in ["ferro","metal_claro","latao"] else 0.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiais[cor] = m
	return _materiais[cor]

func _adicionar(nome: String, malha: Mesh, p: Vector3, cor: String, pai: Node3D) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.name = nome
	no.mesh = malha
	no.material_override = _material(cor)
	no.position = p
	pai.add_child(no)
	return no

func _caixa(nome: String, p: Vector3, tamanho: Vector3, cor: String, pai: Node3D, chanfro := 0.025) -> MeshInstance3D:
	if chanfro <= 0.0:
		var simples := BoxMesh.new()
		simples.size = tamanho
		return _adicionar(nome, simples, p, cor, pai)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := minf(chanfro, minf(tamanho.x,minf(tamanho.y,tamanho.z))*0.22)
	var aneis: Array[PackedVector3Array] = []
	for nivel in 4:
		var extremidade := nivel == 0 or nivel == 3
		var x := tamanho.x*0.5-(b if extremidade else 0.0)
		var z := tamanho.z*0.5-(b if extremidade else 0.0)
		var y := [-tamanho.y*0.5,-tamanho.y*0.5+b,tamanho.y*0.5-b,tamanho.y*0.5][nivel] as float
		aneis.append(PackedVector3Array([Vector3(-x+b,y,-z),Vector3(x-b,y,-z),Vector3(x,y,-z+b),Vector3(x,y,z-b),Vector3(x-b,y,z),Vector3(-x+b,y,z),Vector3(-x,y,z-b),Vector3(-x,y,-z+b)]))
	for j in 3:
		for i in 8:
			var k := (i+1)%8
			for v in [aneis[j][i],aneis[j+1][i],aneis[j][k],aneis[j][k],aneis[j+1][i],aneis[j+1][k]]:
				st.add_vertex(v)
	for nivel in [0,3]:
		for i in 8:
			st.add_vertex(Vector3(0,aneis[nivel][0].y,0))
			st.add_vertex(aneis[nivel][i])
			st.add_vertex(aneis[nivel][(i+1)%8])
	st.generate_normals()
	return _adicionar(nome,st.commit(),p,cor,pai)

func _cilindro(nome: String, p: Vector3, raio: float, altura: float, cor: String, pai: Node3D, eixo := Vector3.RIGHT) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = altura
	c.radial_segments = 12
	var no := _adicionar(nome,c,p,cor,pai)
	no.rotation = eixo * PI/2.0
	return no

func _comporta() -> void:
	name = "Comporta3D"
	for lado in [-1.0,1.0]:
		var x: float = lado*2.0
		for fileira in 2:
			for bloco in 2:
				_caixa("Alvenaria",Vector3(x+(bloco-.5)*.42,.15+fileira*.29,0),Vector3(.41,.28,.8-fileira*.1),"pedra" if bloco%2 == 0 else "pedra_clara",self,.045)
		_caixa("Montante",Vector3(x,1.48,0),Vector3(.24,2.05,.28),"madeira",self,.035)
		_caixa("Trilho",Vector3(x-lado*.15,1.35,.02),Vector3(.075,1.85,.13),"ferro",self,.01)
		for y in [.72,2.28]:
			_caixa("Abracadeira",Vector3(x,y,.18),Vector3(.31,.12,.07),"ferro",self,.012)
			_cilindro("Parafuso",Vector3(x,y,.23),.036,.04,"metal_claro",self)
	_caixa("Travessa",Vector3(0,2.30,0),Vector3(4.55,.28,.30),"madeira_clara",self,.04)
	_caixa("MancalCentral",Vector3(0,2.28,.23),Vector3(.43,.43,.22),"ferro",self,.04)
	var pinhao := Node3D.new()
	pinhao.name = "Pinhao"
	pinhao.position = Vector3(0,2.28,.38)
	add_child(pinhao)
	_cilindro("CuboPinhao",Vector3.ZERO,.135,.065,"latao",pinhao)
	for i in 10:
		var a := i*TAU/10.0
		var d := _caixa("Dente",Vector3(sin(a)*.15,cos(a)*.15,0),Vector3(.06,.08,.075),"latao",pinhao,.008)
		d.rotation.z = -a
	var folha := Node3D.new()
	folha.name = "Folha"
	add_child(folha)
	for i in 7:
		_caixa("Tabua",Vector3(-1.65+i*.55,1.02,0),Vector3(.54,1.18,.17),["madeira","madeira_clara","madeira_escura"][i%3],folha,.018)
	for y in [.68,1.34]:
		_caixa("Cinta",Vector3(0,y,.13),Vector3(3.82,.11,.065),"ferro",folha,.012)
		for i in 7:
			_cilindro("Rebite",Vector3(-1.6+i*.53,y,.18),.028,.035,"metal_claro",folha)
	_caixa("Cremalheira",Vector3(0,2.05,-.10),Vector3(.13,1.4,.14),"ferro",folha,.008)
	for i in 18:
		_caixa("DenteCremalheira",Vector3(0,1.39+i*.075,-.005),Vector3(.16,.035,.08),"metal_claro",folha,0.0)
	_caixa("EixoProtegido",Vector3(-1,2.12,-.22),Vector3(2,.09,.09),"ferro",self,.01)
	_caixa("Transmissao",Vector3(-2,1.45,-.22),Vector3(.12,1.4,.12),"ferro",self,.01)
	_alavanca(Vector3(-2,1.02,.29),self)

func _alavanca(p: Vector3, pai: Node3D) -> void:
	_caixa("SuporteFixo",p,Vector3(.30,.33,.12),"ferro",pai,.025)
	_cilindro("Bucha",p+Vector3(0,0,.10),.11,.12,"latao",pai)
	var movel := Node3D.new()
	movel.name = "Alavanca"
	movel.position = p+Vector3(0,0,.20)
	pai.add_child(movel)
	_caixa("Braco",Vector3(0,.15,0),Vector3(.07,.32,.07),"ferro",movel,.01)
	_cilindro("Punho",Vector3(0,.40,0),.065,.28,"madeira_clara",movel,Vector3.ZERO)
	for y in [.27,.53]:
		_cilindro("Aro",Vector3(0,y,0),.071,.035,"latao",movel,Vector3.ZERO)

func _registro() -> void:
	name = "Registro3D"
	for linha in 2:
		for i in 2:
			_caixa("Pedra",Vector3((i-.5)*.25,.11+linha*.20,0),Vector3(.24,.19,.47-linha*.07),"pedra_clara" if i == linha else "pedra",self,.026)
	_caixa("Pilar",Vector3(0,.57,0),Vector3(.19,.46,.18),"madeira",self,.025)
	_caixa("BaseDeFerro",Vector3(0,.43,.12),Vector3(.31,.12,.06),"ferro",self,.008)
	_alavanca(Vector3(0,.68,.13),self)
	_cilindro("SaidaDoEixo",Vector3(0,.43,-.17),.065,.18,"ferro",self)
	_caixa("Conexao",Vector3(0,.32,-.25),Vector3(.12,.22,.12),"ferro",self,.015)

func _compactar(no: Node3D) -> void:
	# Mesclas por material reduzem chamadas de desenho sem fundir os pivôs móveis.
	var grupos: Dictionary = {}
	for filho in no.get_children():
		if filho is MeshInstance3D:
			var material := filho.material_override as StandardMaterial3D
			var chave := material.resource_name
			if not grupos.has(chave):
				var ferramenta := SurfaceTool.new()
				ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
				ferramenta.set_material(material)
				grupos[chave] = ferramenta
			grupos[chave].append_from(filho.mesh,0,filho.transform)
			no.remove_child(filho)
			filho.free()
		elif filho is Node3D:
			_compactar(filho)
	for chave in grupos:
		var instancia := MeshInstance3D.new()
		instancia.name = "Malha_"+chave
		instancia.mesh = grupos[chave].commit()
		no.add_child(instancia)
