extends RefCounted
## Referência: arte/fontes/campanha/natureza_bacia_3d/arvores-referencia.png.
## Ramos curvos e leques de folhas independentes, compartilhados pelos renders.
const PALETAS := [
	["52733d","3c6033","3e5b2c","788f48","765237"],
	["4b7336","355c30","36542b","718d43","705037"],
	["ad692e","864729","4d5f32","c79247","72513d"],
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

func _ramo_curvo(pai: Node3D, pontos: PackedVector3Array, raios: PackedFloat32Array) -> void:
	if _casca == null:
		_casca = ShaderMaterial.new()
		_casca.shader = preload("res://codigo/campanha/casca_bacia.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aneis: Array[PackedVector3Array] = []
	var distancias: Array[float] = [0.0]
	const LADOS := 10
	for j in pontos.size():
		var anterior := pontos[maxi(0,j-1)]
		var proximo := pontos[mini(pontos.size()-1,j+1)]
		var eixo := (proximo-anterior).normalized()
		var auxiliar := Vector3.RIGHT if absf(eixo.dot(Vector3.UP)) > .92 else Vector3.UP
		var lateral := eixo.cross(auxiliar).normalized()
		var frente := eixo.cross(lateral).normalized()
		var anel := PackedVector3Array()
		for i in LADOS:
			var angulo := TAU*i/LADOS
			var relevo := 1.0+.065*sin(float(i)*3.7+float(j)*.5)
			anel.append(pontos[j]+(lateral*cos(angulo)+frente*sin(angulo))*raios[j]*relevo)
		aneis.append(anel)
		if j > 0: distancias.append(distancias[-1]+pontos[j].distance_to(pontos[j-1]))
	for j in pontos.size()-1:
		for i in LADOS:
			var k := (i+1)%LADOS
			var u := float(i)/LADOS
			var v := float(i+1)/LADOS
			var vertices := [aneis[j][i],aneis[j+1][i],aneis[j][k],aneis[j][k],aneis[j+1][i],aneis[j+1][k]]
			var uvs := [Vector2(u,distancias[j]),Vector2(u,distancias[j+1]),Vector2(v,distancias[j]),Vector2(v,distancias[j]),Vector2(u,distancias[j+1]),Vector2(v,distancias[j+1])]
			for n in 6:
				st.set_uv(uvs[n])
				st.add_vertex(vertices[n])
	st.generate_normals()
	_malha(pai,st.commit(),Vector3.ZERO,Vector3.ONE,_casca)

func ramo(pai: Node3D, a: Vector3, b: Vector3, raio: float) -> void:
	var curva := Vector3(-(b.z-a.z),0,b.x-a.x)*.09
	_ramo_curvo(pai,PackedVector3Array([a,a.lerp(b,.38)+curva,a.lerp(b,.72)+curva*.6,b]),PackedFloat32Array([raio,raio*.83,raio*.60,raio*.26]))

func criar(especie: String, variante: int) -> Node3D:
	tipo = especie
	rng.seed = 4017+variante*787+especie.hash()
	var raiz := Node3D.new()
	raiz.name = "Natureza_"+especie
	if especie == "arbustos":
		for i in 5:
			var a := i*TAU/5
			var centro := Vector3(cos(a)*.23,.30+rng.randf()*.17,sin(a)*.23)
			ramo(raiz,Vector3.ZERO,centro,.025)
			_copa(raiz,centro,Vector3(.34,.27,.32),140,i%3)
	elif especie == "pinheiro":
		_ramo_curvo(raiz,PackedVector3Array([Vector3.ZERO,Vector3(.035,.9,0),Vector3(-.04,2.1,.035),Vector3(.045,3.2,0),Vector3(.015,3.85,0)]),PackedFloat32Array([.17,.105,.072,.038,.005]))
		# Espiral irregular: os ramos não formam discos horizontais repetidos.
		for j in 10:
			var y := .57+j*.31
			var raio := (1.0-pow(float(j)/11.0,.85))*1.18+.09
			var quantidade := 7 if j < 6 else 5
			for i in quantidade:
				var a := TAU*i/quantidade+j*2.399+rng.randf_range(-.13,.13)
				var alcance := raio*rng.randf_range(.78,1.14)
				var inicio := Vector3(0,y+rng.randf_range(-.07,.08),0)
				var ponta := Vector3(cos(a)*alcance,y-.14-alcance*.12,sin(a)*alcance)
				ramo(raiz,inicio,ponta,.035*(1.0-float(j)*.065))
				_fronde(raiz,inicio,ponta,i%2)
				if i%2 == 0:
					var neve := _malha(raiz,volume(300+j*13+i,3,7),inicio.lerp(ponta,.68)+Vector3.UP*.09,Vector3(alcance*.30,.045,.12),material("neve","e0e9e5"))
					neve.rotation.y = -a
					neves.append(neve)
		_fronde(raiz,Vector3(0,3.25,0),Vector3(.015,3.91,0),0)
	else:
		var jovem := especie == "jovem"
		var fator := .78 if jovem else 1.0
		var giro := variante*.81
		var inclinar := -.08+variante*.07
		_ramo_curvo(raiz,PackedVector3Array([Vector3.ZERO,Vector3(-.075,.38,.015)*fator,Vector3(.08+inclinar,.94,-.015)*fator,Vector3(-.035,1.48,.035)*fator,Vector3(.12,2.09,.01)*fator,Vector3(.04,2.81,0)*fator]),PackedFloat32Array([.23*fator,.17*fator,.132*fator,.107*fator,.066*fator,.014*fator]))
		for i in 8:
			var a := i*2.399+giro
			var altura := 1.07+float(i%4)*.27
			var alcance := rng.randf_range(.76,1.10)
			var base := Vector3(.015,altura,.015)*fator
			var cotovelo := Vector3(cos(a)*alcance*.52,altura+.22,sin(a)*alcance*.42)*fator
			var ponta := Vector3(cos(a)*alcance,2.18+float(i%4)*.18,sin(a)*alcance*.78)*fator
			_ramo_curvo(raiz,PackedVector3Array([base,base.lerp(cotovelo,.60),cotovelo,ponta]),PackedFloat32Array([.087*fator,.072*fator,.047*fator,.019*fator]))
			# Leques de folhas seguem bifurcações, com espaços entre os galhos.
			for j in 3:
				var direcao := a+float(j-1)*.83
				var fim := ponta+Vector3(cos(direcao)*.36,.13+float(j%2)*.22,sin(direcao)*.30)*fator
				ramo(raiz,ponta-Vector3.UP*.08*fator,fim,.024*fator)
				for k in 2:
					var broto := fim+Vector3(cos(direcao+float(k)*1.9)*.15,.13,sin(direcao+float(k)*1.9)*.15)*fator
					ramo(raiz,fim,broto,.010*fator)
				_copa(raiz,fim,Vector3(.40,.33,.37)*fator,105,i%3)
		_copa(raiz,Vector3(.04,3.02,0)*fator,Vector3(.51,.40,.47)*fator,210,0)
		for i in 6:
			var a := i*TAU/6+giro
			var fora := Vector3(cos(a)*rng.randf_range(.32,.46),.012,sin(a)*.32)
			_ramo_curvo(raiz,PackedVector3Array([Vector3(-.02,.32,0),fora*.55+Vector3.UP*.07,fora]),PackedFloat32Array([.11,.068,.009]))
			var neve := _malha(raiz,volume(400+i,3,7),fora*.70+Vector3.UP*.035,Vector3(.20,.035,.15),material("neve","e0e9e5"))
			neves.append(neve)
	definir_estacao(0)
	return raiz

func _folha(st: SurfaceTool, centro: Vector3, eixo: Vector3, lado: Vector3, tamanho: float) -> void:
	# Folha alongada, pontuda, com nervura elevada; sem esfera na copa.
	var pontos := [centro-eixo*tamanho*.65,centro-eixo*tamanho*.20+lado*tamanho*.36,centro+eixo*tamanho*.45+lado*tamanho*.32,centro+eixo*tamanho,centro+eixo*tamanho*.45-lado*tamanho*.32,centro-eixo*tamanho*.20-lado*tamanho*.36]
	var nervura := centro+Vector3.UP*tamanho*.18
	for i in 6:
		for v in [pontos[i],nervura,pontos[(i+1)%6]]: st.add_vertex(v)

func _copa(pai: Node3D, centro: Vector3, raio: Vector3, quantidade: int, tom: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in quantidade:
		var a := rng.randf()*TAU
		var h := rng.randf_range(-1.,1.)
		var r := sqrt(1.-h*h)*pow(rng.randf(),.23)
		var ondulacao := 1.0+.17*sin(a*3.0+centro.x*7.0)+.09*cos(a*5.0+h*2.0)
		var p := centro+Vector3(cos(a)*r*ondulacao,h,sin(a)*r*ondulacao)*raio
		var angulo := rng.randf()*TAU
		var eixo := Vector3(cos(angulo),rng.randf_range(-.35,.45),sin(angulo)).normalized()
		var lado := Vector3(-sin(angulo),rng.randf_range(-.30,.30),cos(angulo)).normalized()
		var exposicao := clampf((p.y-1.75)/1.65,0.0,1.0) if tipo != "arbustos" else clampf(p.y/.8,0.0,1.0)
		var cor := (.59+exposicao*.42+h*.12+r*.08-p.x*.045)*rng.randf_range(.92,1.06)
		st.set_color(Color(cor,cor,cor*.96))
		_folha(st,p,eixo,lado,rng.randf_range(.16,.245))
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
	for i in 15:
		var t := float(i)/15.0
		var centro := a.lerp(b,t)-Vector3.UP*sin(t*PI)*.07
		var largura := (pow(1.0-t,.72)*.29+.025)*rng.randf_range(.88,1.12)
		for direcao in [-1.,1.]:
			for nivel in 3:
				var angulo := -.68+float(nivel)*.36
				var ponta: Vector3 = centro+lado*largura*direcao*cos(angulo)+Vector3.UP*largura*sin(angulo)+eixo*.12
				var agulha := (ponta-centro).normalized()
				st.set_color(Color(1.,1.,.88)*rng.randf_range(.89,1.06))
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
			materiais[chave].albedo_color = Color(p[0]).darkened(.055*float(i%3))
		elif str(chave).begins_with("pinheiro_"):
			materiais[chave].albedo_color = Color(p[2]).lightened(.08 if str(chave).ends_with("0") else 0.0)
		elif chave == "tronco": materiais[chave].albedo_color = Color(p[4])
	for no in folhagens: no.visible = indice != 3
	for no in neves: no.visible = indice == 3
