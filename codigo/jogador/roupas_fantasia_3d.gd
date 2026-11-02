extends RefCounted
## Peças de vestuário independentes. Lê só o molde de roupa e o mapa de ossos;
## nunca recorta, pinta ou altera a malha do corpo canônico.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")

static func construir(_base: ArrayMesh,forma: int,rig: Dictionary) -> ArrayMesh:
	# Tronco contínuo: costuras sem triângulos herdados de outras partes do atlas.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tronco(st,forma,rig)
	if forma!=12:_mangas_curtas(st,rig)
	if forma==7:
		_painel(st,[[1.45,.17,.192],[1.25,.19,.196],[1.05,.21,.194],[.85,.23,.196]],rig)
		_painel(st,[[1.45,.17,-.192],[1.25,.19,-.196],[1.05,.21,-.194],[.85,.23,-.196]],rig)
	elif forma==8:
		_avental(st,rig)
	if forma==12:_mangas_bufantes(st,rig)
	if forma in [6,7,9,10,11]:_cinto(st,rig)
	st.generate_normals()
	st.index()
	return st.commit()

static func _v(p: Vector3,rig: Dictionary) -> Dictionary:
	var pesos:Dictionary=Modelagem.pesos_tronco(maxf(p.y,1.0))
	if p.y<.98:
		var lado:=".L" if p.x>=0 else ".R"
		var perna:=.18*(1.0-smoothstep(.78,.98,p.y))
		pesos={"DEF-hips":1.0-perna,"DEF-thigh"+lado:perna}
	return Modelagem.vertice(p,pesos,rig)

static func _painel(st: SurfaceTool,secoes: Array,rig: Dictionary) -> void:
	for i in secoes.size()-1:
		var a:Array=secoes[i]
		var b:Array=secoes[i+1]
		var frente:=1.0 if float(a[2])>0 else -1.0
		var vs:=[Vector3(-a[1],a[0],a[2]),Vector3(a[1],a[0],a[2]),Vector3(b[1],b[0],b[2]),Vector3(-b[1],b[0],b[2])]
		Modelagem.quad(st,_v(vs[0],rig),_v(vs[1],rig),_v(vs[2],rig),_v(vs[3],rig),Vector3(0,0,frente))
		# Avesso próprio: tecido continua visível ao virar, sem dupla face no material.
		for k in 4:vs[k].z-=frente*.006
		Modelagem.quad(st,_v(vs[3],rig),_v(vs[2],rig),_v(vs[1],rig),_v(vs[0],rig),Vector3(0,0,-frente))

static func _fita(st: SurfaceTool,a: Vector3,b: Vector3,raio: float,rig: Dictionary) -> void:
	var lateral:=Vector3(-(b-a).y,(b-a).x,0).normalized()*raio
	for i in 8:
		var p:=a.lerp(b,i/8.0)
		var q:=a.lerp(b,(i+1)/8.0)
		Modelagem.quad(st,_v(p-lateral,rig),_v(p+lateral,rig),_v(q+lateral,rig),_v(q-lateral,rig),Vector3.BACK)

static func _cinto(st: SurfaceTool,rig: Dictionary) -> void:
	for i in 32:
		var a:=TAU*i/32
		var b:=TAU*(i+1)/32
		var vs:=[Vector3(cos(a)*.231,1.085,sin(a)*.202-.012),Vector3(cos(b)*.231,1.085,sin(b)*.202-.012),Vector3(cos(b)*.231,1.045,sin(b)*.202-.012),Vector3(cos(a)*.231,1.045,sin(a)*.202-.012)]
		Modelagem.quad(st,_v(vs[0],rig),_v(vs[1],rig),_v(vs[2],rig),_v(vs[3],rig),Vector3(cos(a),0,sin(a)))

static func _mangas_bufantes(st: SurfaceTool,rig: Dictionary) -> void:
	for lado in [-1,1]:
		var aneis:Array=[]
		var sufixo:=".L" if lado>0 else ".R"
		for m in [[.245,.105,.105],[.32,.145,.135],[.41,.15,.14],[.50,.145,.13],[.59,.125,.11],[.69,.075,.07],[.72,.065,.06],[.74,.085,.075]]:
			var anel:Array=[]
			for i in 20:
				var a:=TAU*i/20
				var p:=Vector3(lado*float(m[0]),1.435+cos(a)*float(m[1]),-.012+sin(a)*float(m[2]))
				var antebraco:=smoothstep(.42,.56,float(m[0]))
				anel.append(Modelagem.vertice(p,{"DEF-upper_arm"+sufixo:1.0-antebraco,"DEF-forearm"+sufixo:antebraco},rig))
			aneis.append(anel)
		for i in aneis.size()-1:Modelagem.unir(st,aneis[i],aneis[i+1],Vector3(lado*.5,1.435,-.012),0)

static func _tronco(st: SurfaceTool,forma: int,rig: Dictionary) -> void:
	var longo:=forma in [6,7,10]
	var aneis:Array=[]
	for m in [[.98 if longo else 1.035,.244,.183],[1.10,.232,.184],[1.24,.246,.188],[1.37,.267,.180],[1.445,.270,.150],[1.485,.105,.090]]:
		var anel:Array=[]
		for i in 48:
			var a:=TAU*i/48
			anel.append(_v(Vector3(cos(a)*float(m[1]),float(m[0]),sin(a)*float(m[2])),rig))
		aneis.append(anel)
	for i in aneis.size()-1:Modelagem.unir(st,aneis[i],aneis[i+1],Vector3(0,1.25,0))

static func _mangas_curtas(st: SurfaceTool,rig: Dictionary) -> void:
	for lado in [-1,1]:
		var aneis:Array=[]
		var sufixo:=".L" if lado>0 else ".R"
		for m in [[.245,.105,.105],[.32,.118,.118],[.43,.110,.110]]:
			var anel:Array=[]
			for i in 24:
				var a:=TAU*i/24
				var p:=Vector3(lado*float(m[0]),1.435+cos(a)*float(m[1]),-.012+sin(a)*float(m[2]))
				anel.append(Modelagem.vertice(p,{"DEF-upper_arm"+sufixo:1.0},rig))
			aneis.append(anel)
		for i in aneis.size()-1:Modelagem.unir(st,aneis[i],aneis[i+1],Vector3(lado*.3,1.435,-.012),0)

## Avental curvo, sem a placa plana atravessando a camisa. Alças e avesso próprios.
static func _avental(st: SurfaceTool,rig: Dictionary) -> void:
	var secoes:=[[1.39,.115,.202],[1.32,.13,.206],[1.22,.17,.215],[1.10,.21,.218],[1.02,.245,.218],[.93,.26,.222],[.84,.27,.225],[.76,.265,.228]]
	for j in secoes.size()-1:
		for i in 20:
			var vs:Array=[]
			for canto in [[j,i],[j+1,i],[j+1,i+1],[j,i+1]]:
				var m:Array=secoes[canto[0]]
				var u:float=-1.0+2.0*canto[1]/20.0
				var y:float=m[0]+(.025*pow(absf(u),4) if canto[0]==secoes.size()-1 else 0.0)
				var p:=Vector3(u*float(m[1]),y,float(m[2])-.095*pow(float(m[1])/.265,2)*u*u+.003*sin(u*PI*3)*smoothstep(1.10,.76,y))
				vs.append(p)
			_quad_avental(st,vs,rig)
	for lado in [-1,1]:
		var caminho:=[Vector3(lado*.10,1.385,.20),Vector3(lado*.14,1.45,.135),Vector3(lado*.14,1.476,.035),Vector3(lado*.14,1.45,-.11),Vector3(lado*.13,1.375,-.16),Vector3(0,1.24,-.197),Vector3(-lado*.17,1.085,-.14)]
		for n in caminho.size()-1:
			for i in 8:
				var a:Vector3=caminho[n].lerp(caminho[n+1],i/8.0)
				var b:Vector3=caminho[n].lerp(caminho[n+1],(i+1)/8.0)
				var l:=Vector3(.016,0,0)
				_quad_avental(st,[a-l,b-l,b+l,a+l],rig)

static func _quad_avental(st: SurfaceTool,vs: Array,rig: Dictionary) -> void:
	# UV2.y marca uma ilha de atlas exclusiva do couro, sem repintar a camisa.
	var normal:Vector3=(vs[1]-vs[0]).cross(vs[2]-vs[0]).normalized()
	st.set_smooth_group(-1)
	for face in 2:
		var ordens:Array=[[2,1,0],[3,2,0]] if face==0 else [[0,1,2],[0,2,3]]
		for ordem in ordens:
			for k in ordem:
				var p:Vector3=vs[k]-normal*.006*face
				var v:=_v(p,rig)
				if p.y<1.10:
					var perna:=.96*smoothstep(1.10,.76,p.y)
					var esquerda:=smoothstep(-.045,.045,p.x)
					v=Modelagem.vertice(p,{"DEF-hips":1.0-perna,"DEF-thigh.L":perna*esquerda,"DEF-thigh.R":perna*(1.0-esquerda)},rig)
				st.set_normal(normal if face==0 else -normal)
				st.set_bones(v.b)
				st.set_weights(v.w)
				st.set_color(Color.WHITE)
				st.set_uv(Vector2(p.x,p.y))
				st.set_uv2(Vector2(p.z,8.0))
				st.add_vertex(p)
	st.set_smooth_group(0)
