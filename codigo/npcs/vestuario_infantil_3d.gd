extends RefCounted
## Guarda-roupa exclusivo do manequim infantil. Não altera o catálogo dos adultos.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Recorte=preload("res://codigo/jogador/roupas_base_3d.gd")
const Fantasia=preload("res://codigo/jogador/roupas_fantasia_3d.gd")
const Cabelo=preload("res://codigo/jogador/visuais_femininos_3d.gd")
const Placas=preload("res://codigo/jogador/moldes_carrasco_3d.gd")
const TRAJES={
	"campestre":{"nome":"Roupa de brincar","estilo":0,"camisa":"7e985e","barra":"dac495","calca":"805b3c"},
	"jardineira":{"nome":"Jardineira da vila","estilo":1,"camisa":"e4d6ad","barra":"c9b47b","calca":"4a7b91"},
	"vestido":{"nome":"Vestido de passeio","estilo":2,"camisa":"bf7771","barra":"ead3ad","calca":"bf7771"}}
const CABELOS={"franjinha":"Franjinha curta","chiquinhas":"Maria-chiquinhas","cacheado":"Cachos curtos"}
var heroi:Node
var _malhas:Dictionary={}

func _init(visual: Node) -> void:heroi=visual

func aplicar(traje: String,penteado: String) -> void:
	assert(TRAJES.has(traje) and CABELOS.has(penteado))
	var roupa:Dictionary=TRAJES[traje]
	var corpo:MeshInstance3D=heroi._modelo.find_child("CorpoBase",true,false)
	var rig:=Modelagem.ligacoes(corpo,heroi._esqueleto)
	for i in [0,1,3]:
		var chave:="cabelo_"+penteado if i==3 else traje+str(i)
		if not _malhas.has(chave):
			var malha:ArrayMesh
			if i==0:malha=Placas.marcar(Fantasia.construir(heroi._moldes_roupas[0],12 if traje=="vestido" else (13 if traje=="jardineira" else 6),rig),0)
			elif i==1:malha=_parte_baixo(corpo,rig,traje)
			else:malha=_cabelo(corpo,penteado)
			_malhas[chave]=malha
		var peca:MeshInstance3D=heroi._pecas[i]
		peca.mesh=_malhas[chave]
		var material:=ShaderMaterial.new()
		material.shader=load("res://codigo/npcs/vestuario_infantil.gdshader")
		material.set_shader_parameter("traje",roupa.estilo)
		material.set_shader_parameter("peca",i)
		material.set_shader_parameter("tecido",Color(roupa.camisa if i==0 else roupa.calca))
		material.set_shader_parameter("detalhe",Color(roupa.barra))
		var tinta:Array=heroi._jogador.aparencia_raven.get("cor",[.32,.20,.14,1.])
		material.set_shader_parameter("cor_cabelo",Color(tinta[0],tinta[1],tinta[2]))
		peca.material_override=material
	# O rosto usa só a face pintada; o penteado infantil é uma malha própria.
	heroi.roupas_3d.cabelo="cabelo_cacheado"
	heroi._atualizar_pecas()
	corpo.material_override.set_shader_parameter("altura_barra_calca",.64)
	heroi._atualizar_materiais_pixel()

func _parte_baixo(corpo: MeshInstance3D,rig: Dictionary,traje: String) -> ArrayMesh:
	if traje=="vestido":
		var saia:=Cabelo.saia(heroi._moldes_roupas[1],corpo,heroi._esqueleto,5)
		var a:=saia.surface_get_arrays(0)
		var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		for i in vs.size():
			if vs[i].y<.8:
				var f:=clampf((.8-vs[i].y)/.6,0,1)
				vs[i].y=.8-f*.14
				vs[i].x*=1.0-f*.10
				vs[i].z*=1.0-f*.10
		a[Mesh.ARRAY_VERTEX]=vs
		var malha:=ArrayMesh.new();malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		return Placas.marcar(malha,0)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base:ArrayMesh=heroi._moldes_roupas[1]
	for s in base.get_surface_count():
		var a:=base.surface_get_arrays(s)
		var vertices:Array=[]
		for i in a[Mesh.ARRAY_VERTEX].size():
			var p:Vector3=a[Mesh.ARRAY_VERTEX][i]
			vertices.append({"p":p,"n":a[Mesh.ARRAY_NORMAL][i],"b":a[Mesh.ARRAY_BONES].slice(i*4,i*4+4),"w":a[Mesh.ARRAY_WEIGHTS].slice(i*4,i*4+4),"f":p.y-.64})
		var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var poligono:=Recorte.recortar([vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]])
			for j in range(1,poligono.size()-1):
				for v in [poligono[0],poligono[j],poligono[j+1]]:
					st.set_color(Color.WHITE);st.set_uv(Vector2(v.p.x,v.p.y));st.set_uv2(Vector2(v.p.z,0));Recorte.emitir(st,v,0)
	# Barra dobrada das bermudas, com folga sobre o tecido e pesos das coxas.
	for lado in [-1,1]:
		var anterior:Array=[]
		for y in [.64,.69]:
			var anel:Array=[]
			for q in 24:
				var a:=TAU*q/24.
				var p:=Vector3(lado*.112+cos(a)*.116,y,-.016+sin(a)*.15)
				anel.append(Modelagem.vertice(p,Modelagem.pesos_perna(y,lado),rig))
			if not anterior.is_empty():Modelagem.unir(st,anterior,anel,Vector3(lado*.112,.66,-.016))
			anterior=anel
	st.generate_normals();st.index()
	var bermuda:=Placas.marcar(st.commit(),0)
	if traje!="jardineira":return bermuda
	var peito:=SurfaceTool.new();peito.begin(Mesh.PRIMITIVE_TRIANGLES)
	_peitilho_curvo(peito,[[1.385,.115,.207],[1.28,.14,.212],[1.10,.19,.21],[1.01,.20,.17]],rig)
	_peitilho_curvo(peito,[[1.30,.12,-.195],[1.10,.19,-.20],[1.01,.20,-.17]],rig)
	for lado in [-1,1]:
		var caminho:=[Vector3(lado*.10,1.39,.208),Vector3(lado*.14,1.47,.12),Vector3(lado*.14,1.49,.025),Vector3(lado*.13,1.45,-.12),Vector3(lado*.10,1.30,-.197)]
		for i in caminho.size()-1:
			for q in 6:
				var a:Vector3=caminho[i].lerp(caminho[i+1],q/6.)
				var b:Vector3=caminho[i].lerp(caminho[i+1],(q+1)/6.)
				var l:=Vector3(.022,0,0)
				var normal:Vector3=(b-a).cross(l).normalized()
				Modelagem.quad(peito,Fantasia._v(a-l,rig),Fantasia._v(a+l,rig),Fantasia._v(b+l,rig),Fantasia._v(b-l,rig),normal)
	peito.generate_normals();peito.index()
	return Placas.juntar([bermuda,Placas.marcar(peito.commit(),2)])

func _peitilho_curvo(st: SurfaceTool,secoes: Array,rig: Dictionary) -> void:
	for n in secoes.size()-1:
		for q in 16:
			var pontos:Array=[]
			for canto in [[n,q],[n+1,q],[n+1,q+1],[n,q+1]]:
				var m:Array=secoes[canto[0]]
				var u:float=-1.0+2.0*canto[1]/16.
				var x:float=u*m[1]
				var z:float=m[2]-signf(m[2])*.115*pow(x/.23,2)
				pontos.append(Fantasia._v(Vector3(x,m[0],z),rig))
			var normal:Vector3=Vector3(pontos[0].p.x,0,signf(secoes[n][2])*.2).normalized()
			Modelagem.quad(st,pontos[0],pontos[1],pontos[2],pontos[3],normal)

func _cabelo(corpo: MeshInstance3D,penteado: String) -> ArrayMesh:
	var s:Skeleton3D=heroi._esqueleto
	var t:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
	var bind:int=Modelagem.ligacoes(corpo,s)["DEF-head"]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aneis:Array=[]
	for m in [[.305,.001,.001,0.],[.29,.055,.065,0.],[.26,.10,.115,0.],[.205,.126,.139,0.],[.155,.13,.139,.75],[.07,.124,.125,1.32]]:
		var anel:Array=[]
		for q in 33:
			var a:=lerpf(PI*.5-m[3],-PI*1.5+m[3],q/32.)
			anel.append(Vector3(cos(a)*m[1],m[0],sin(a)*m[2]))
		if not aneis.is_empty():
			for q in 32:Cabelo._quad_cabelo(st,[aneis[-1][q],anel[q],anel[q+1],aneis[-1][q+1]],t,bind)
		aneis.append(anel)
	# Franja curta; pontas ficam acima dos olhos nas quatro direções.
	for i in 4:
		var x:float=(i-1.5)*.043
		if penteado=="cacheado":Cabelo._cacho(st,Vector3(x,.20+.008*sin(i),.123),Vector3(.032,.032,.028),t,bind)
		else:Cabelo._mecha(st,[[Vector3(x-.018,.245,.10),.032,.022],[Vector3(x,.20,.135),.032,.024],[Vector3(x+.01,.17+.01*sin(i),.14),.006,.008]],t,bind)
	if penteado=="chiquinhas":
		for lado in [-1,1]:Cabelo._mecha(st,[[Vector3(lado*.118,.18,-.065),.032,.030],[Vector3(lado*.17,.15,-.07),.045,.045],[Vector3(lado*.19,.07,-.06),.043,.043],[Vector3(lado*.168,-.005,-.045),.025,.030],[Vector3(lado*.15,-.035,-.035),.003,.004]],t,bind)
	elif penteado=="cacheado":
		for faixa in 3:
			for q in 12:
				var a:=TAU*(q+.35*faixa)/12.
				if faixa>0 and sin(a)>.35:continue
				var r:float=[.075,.124,.115][faixa]
				var y:float=[.27,.19,.09][faixa]
				Cabelo._cacho(st,Vector3(cos(a)*r,y+.009*sin(q*2.1),sin(a)*r),Vector3(.041,.036,.040),t,bind)
	st.generate_normals();st.index()
	var cabelo:=Placas.marcar(st.commit(),3,t.affine_inverse())
	if penteado!="chiquinhas":return cabelo
	var lacos:=SurfaceTool.new();lacos.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [-1,1]:Cabelo._cacho(lacos,Vector3(lado*.139,.17,-.065),Vector3(.023,.018,.037),t,bind)
	lacos.generate_normals();lacos.index()
	return Placas.juntar([cabelo,Placas.marcar(lacos.commit(),4,t.affine_inverse())])
