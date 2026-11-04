extends RefCounted
## Referência: arte/fontes/campanha/natureza_bacia_3d/referencia.png.
## Malhas independentes compartilhadas pelos renders, com normais planas reais.
const PALETAS := [
	["52733d","3c6033","3e5b2c","788f48","765237"],
	["4b7336","355c30","36542b","718d43","705037"],
	["ce8b39","9b552d","4d5f32","ddad51","72513d"],
	["cad7d3","879b93","47675b","e2e9e1","6c6054"],
]
var materiais: Dictionary = {}
var folhagens: Array[Node3D] = []
var neves: Array[Node3D] = []
var tipo := "carvalho"
var _casca: ShaderMaterial
var rng := RandomNumberGenerator.new()

func material(nome: String, cor: String) -> StandardMaterial3D:
	if not materiais.has(nome):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cor)
		m.roughness = .92
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		materiais[nome] = m
	return materiais[nome]

func _malha(no: Node3D, malha: Mesh, p: Vector3, escala: Vector3, m: Material) -> MeshInstance3D:
	var objeto := MeshInstance3D.new()
	objeto.mesh = malha
	objeto.position = p
	objeto.scale = escala
	objeto.material_override = m
	no.add_child(objeto)
	return objeto

func volume(semente: int, aneis := 4, lados := 9) -> ArrayMesh:
	var aleatorio := RandomNumberGenerator.new()
	aleatorio.seed = semente
	var pontos: Array[PackedVector3Array] = []
	for j in range(aneis+1):
		var phi := PI*j/aneis
		var anel := PackedVector3Array()
		for i in lados:
			var a := TAU*i/lados
			var ruido := aleatorio.randf_range(.88,1.12)
			anel.append(Vector3(sin(phi)*cos(a)*ruido, cos(phi)*aleatorio.randf_range(.96,1.04), sin(phi)*sin(a)*ruido))
		pontos.append(anel)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for j in aneis:
		for i in lados:
			var k := (i+1)%lados
			for v in [pontos[j][i],pontos[j+1][i],pontos[j][k],pontos[j][k],pontos[j+1][i],pontos[j+1][k]]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func ramo(pai: Node3D, a: Vector3, b: Vector3, raio: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = raio*.55
	c.bottom_radius = raio
	c.height = a.distance_to(b)
	c.radial_segments = 7
	if _casca == null:
		_casca = ShaderMaterial.new()
		_casca.shader = preload("res://codigo/campanha/casca_bacia.gdshader")
	var no := _malha(pai,c,(a+b)*.5,Vector3.ONE,_casca)
	no.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func criar(especie: String, variante: int) -> Node3D:
	tipo = especie
	rng.seed = 4017+variante*787+especie.hash()
	var raiz := Node3D.new()
	raiz.name = "Natureza_"+especie
	if especie == "arbustos":
		for i in 4:
			var a := i*TAU/4
			var centro := Vector3(cos(a)*.26,.32+float(i%2)*.12,sin(a)*.23)
			ramo(raiz,Vector3.ZERO,centro,.025)
			_copa(raiz,centro,Vector3(.39,.32,.36),210,i%3)
	elif especie == "pinheiro":
		ramo(raiz,Vector3.ZERO,Vector3(0,3.70,0),.12)
		for j in 9:
			var y := .65+j*.39
			var raio := 1.18-j*.125
			for i in 12:
				var a := TAU*i/12.0+float(j%2)*.3
				var ponta := Vector3(cos(a)*raio,y-.14,sin(a)*raio)
				ramo(raiz,Vector3(0,y+.17,0),ponta,.022)
				_fronde(raiz,Vector3(0,y+.13,0),ponta,j%2)
				if i%3 == 0:
					var neve := _malha(raiz,volume(300+j+i,3,7),ponta*.65+Vector3(0,y*.35+.12,0),Vector3(.24,.055,.16),material("neve","e0e9e5"))
					neves.append(neve)
		_fronde(raiz,Vector3(0,3.4,0),Vector3(.02,3.92,0),0)
	else:
		var jovem := especie == "jovem"
		var fator := .78 if jovem else 1.0
		ramo(raiz,Vector3.ZERO,Vector3(.04,2.65*fator,0),.15*fator)
		for i in 7:
			var a := TAU*i/7.0+.4
			var ponta := Vector3(cos(a)*.89,2.15+float(i%3)*.27,sin(a)*.70)*fator
			ramo(raiz,Vector3(0,1.25*fator,0),ponta,.075*fator)
			for j in 3:
				var fim := ponta+Vector3(cos(a+float(j-1)*.7)*.37,.33+float(j)*.1,sin(a+float(j-1)*.7)*.30)*fator
				ramo(raiz,ponta,fim,.028*fator)
			_copa(raiz,ponta+Vector3(0,.18*fator,0),Vector3(.68,.60,.64)*fator,520,i%3)
		_copa(raiz,Vector3(0,2.98*fator,0),Vector3(.78,.62,.70)*fator,620,0)
		for i in 5:
			var a := i*TAU/5
			ramo(raiz,Vector3(cos(a)*.36,0,sin(a)*.26),Vector3(0,.30,0),.08)
			var neve := _malha(raiz,volume(400+i,3,7),Vector3(cos(a)*.24,.025,sin(a)*.23),Vector3(.22,.04,.21),material("neve","e0e9e5"))
			neves.append(neve)
	definir_estacao(0)
	return raiz

func _folha(st: SurfaceTool, centro: Vector3, eixo: Vector3, lado: Vector3, tamanho: float) -> void:
	# Folha alongada, pontuda, com nervura elevada; sem esfera na copa.
	var pontos := [centro-eixo*tamanho*.65,centro+lado*tamanho*.40,centro+eixo*tamanho,centro-lado*tamanho*.40]
	var nervura := centro+Vector3.UP*tamanho*.18
	for i in 4:
		for v in [pontos[i],nervura,pontos[(i+1)%4]]: st.add_vertex(v)

func _copa(pai: Node3D, centro: Vector3, raio: Vector3, quantidade: int, tom: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in quantidade:
		var a := rng.randf()*TAU
		var h := rng.randf_range(-1.,1.)
		var r := sqrt(1.-h*h)*pow(rng.randf(),.23)
		var p := centro+Vector3(cos(a)*r,h,sin(a)*r)*raio
		var angulo := rng.randf()*TAU
		var eixo := Vector3(cos(angulo),rng.randf_range(-.35,.45),sin(angulo)).normalized()
		var lado := Vector3(-sin(angulo),rng.randf_range(-.30,.30),cos(angulo)).normalized()
		var cor := rng.randf_range(.89,1.08)
		st.set_color(Color(cor,cor,cor*.96))
		_folha(st,p,eixo,lado,rng.randf_range(.145,.235))
	st.generate_normals()
	var m := material("folha_"+str(tom),"61803c")
	m.vertex_color_use_as_albedo = true
	m.metallic_specular = .08
	var no := _malha(pai,st.commit(),Vector3.ZERO,Vector3.ONE,m)
	folhagens.append(no)

func _fronde(pai: Node3D, a: Vector3, b: Vector3, tom: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var eixo := (b-a).normalized()
	var lado := Vector3(-eixo.z,0,eixo.x).normalized()
	if lado.length_squared() < .1: lado = Vector3.RIGHT
	# Agulhas nascem no ramo e se sobrepõem até a ponta, em três planos.
	for i in 19:
		var t := float(i)/19.0
		var centro := a.lerp(b,t)
		var largura := pow(1.0-t,.72)*.37+.04
		for direcao in [-1.,1.]:
			for nivel in 3:
				var angulo := -.35+float(nivel)*.42
				var ponta: Vector3 = centro+lado*largura*direcao*cos(angulo)+Vector3.UP*largura*sin(angulo)+eixo*.12
				var agulha := (ponta-centro).normalized()
				st.set_color(Color(1.,1.,.88)*rng.randf_range(.86,1.12))
				_folha(st,(centro+ponta)*.5,agulha,eixo,.16+largura*.58)
	st.generate_normals()
	var m := material("pinheiro_"+str(tom),"436c47")
	m.vertex_color_use_as_albedo = true
	m.metallic_specular = .08
	_malha(pai,st.commit(),Vector3.ZERO,Vector3.ONE,m)

func definir_estacao(indice: int) -> void:
	var p: Array = PALETAS[indice]
	if _casca: _casca.set_shader_parameter("cor",Color(p[4]))
	for chave in materiais:
		if str(chave).begins_with("folha_"):
			var i := int(str(chave).get_slice("_",1))
			materiais[chave].albedo_color = Color(p[[0,1,3][i%3]])
		elif str(chave).begins_with("pinheiro_"):
			materiais[chave].albedo_color = Color(p[2]).lightened(.08 if str(chave).ends_with("0") else 0.0)
		elif chave == "tronco": materiais[chave].albedo_color = Color(p[4])
	for no in folhagens: no.visible = indice != 3
	for no in neves: no.visible = indice == 3
