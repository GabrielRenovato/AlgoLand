extends RefCounted
## Aço de ronda: crista de morrião, gola alta e placas articuladas da referência.
const Tecido=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Base=preload("res://codigo/jogador/moldes_mordomo_3d.gd")
const Placas=preload("res://codigo/jogador/moldes_carrasco_3d.gd")

static func elmo(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
	var ligacoes:=Tecido.ligacoes(corpo,rig)
	var t:=Base.espaco(corpo).affine_inverse()*Base.espaco(rig)*rig.get_bone_global_rest(rig.find_bone("DEF-head"))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Base.cilindro(st,ligacoes,t,[[-.045,.001,.001],[-.025,.075,.11],[.035,.112,.157],[.13,.123,.173],[.23,.125,.17],[.30,.105,.147],[.345,.065,.10],[.36,.001,.001]],"DEF-head")
	var casco:=Placas.marcar(Base.finalizar(st),0,t.affine_inverse())
	# Crista de chapa, fechada nas duas faces: não é pluma nem textura colada.
	var crista:=SurfaceTool.new();crista.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces:Array=[]
	var contorno:=[Vector3(0,.26,.155),Vector3(0,.405,.10),Vector3(0,.485,-.02),Vector3(0,.45,-.105),Vector3(0,.30,-.15)]
	for lado in [-1,1]:
		var pontos:Array=[]
		for p in contorno:pontos.append(p+Vector3(lado*.012,0,0))
		var face:=Placas.placa(pontos,Vector3(lado*.016,.36,-.015),ligacoes,{"DEF-head":1.0},t)
		faces.append(face)
	for i in contorno.size():
		var a:Vector3=contorno[i];var b:Vector3=contorno[(i+1)%contorno.size()]
		Tecido.quad(crista,Tecido.vertice(t*(a+Vector3(-.012,0,0)),{"DEF-head":1.0},ligacoes),Tecido.vertice(t*(a+Vector3(.012,0,0)),{"DEF-head":1.0},ligacoes),Tecido.vertice(t*(b+Vector3(.012,0,0)),{"DEF-head":1.0},ligacoes),Tecido.vertice(t*(b+Vector3(-.012,0,0)),{"DEF-head":1.0},ligacoes),t.basis*Vector3.UP)
	faces.append(Base.finalizar(crista))
	# A abertura fica na própria calota; não deixa uma viseira suspensa diante do nariz.
	return Placas.juntar([casco,Placas.marcar(Placas.juntar(faces),1,t.affine_inverse())])

static func peitoral(corpo: MeshInstance3D,rig: Skeleton3D,camisa: ArrayMesh,calca: ArrayMesh) -> ArrayMesh:
	var ligacoes:=Tecido.ligacoes(corpo,rig)
	var partes:Array=[Placas.marcar(Base.ajustar(camisa,ligacoes,"casaca"),0),Placas.marcar(Base.ajustar(calca,ligacoes,"calca"),0)]
	var gola:=SurfaceTool.new();gola.begin(Mesh.PRIMITIVE_TRIANGLES)
	Base.cilindro(gola,ligacoes,Transform3D.IDENTITY,[[1.43,.20,.145],[1.49,.155,.135],[1.57,.105,.105],[1.59,.102,.102]],"DEF-spine.003")
	partes.append(Placas.marcar(Base.finalizar(gola),5))
	var ombros:=SurfaceTool.new();ombros.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [-1,1]:
		Placas.bracelete(ombros,ligacoes,lado,[[.225,.10,.12],[.265,.16,.16],[.325,.178,.18],[.39,.16,.18],[.435,.105,.16]],12)
		Placas.bracelete(ombros,ligacoes,lado,[[.37,.143,.169],[.41,.14,.174],[.455,.115,.161],[.475,.095,.145]],12)
	partes.append(Placas.marcar(Base.finalizar(ombros),2))
	var peito:=Placas.placa([Vector3(-.19,1.46,.135),Vector3(0,1.49,.16),Vector3(.19,1.46,.135),Vector3(.20,1.28,.175),Vector3(.13,1.08,.187),Vector3(0,1.015,.225),Vector3(-.13,1.08,.187),Vector3(-.20,1.28,.175)],Vector3(0,1.27,.245),ligacoes,{"DEF-spine.002":.65,"DEF-spine.003":.35})
	partes.append(Placas.marcar(peito,4))
	var saias:=SurfaceTool.new();saias.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Três lâminas sobrepostas em cada quadrante, curtas para liberar a passada.
	for painel in 4:
		for camada in 3:
			var y:=1.055-camada*.074
			var anterior:Array=[]
			for linha in 2:
				var anel:Array=[]
				for q in 7:
					var a:=painel*PI*.5+.10+q*(PI*.5-.20)/6.0
					var p:=Vector3(cos(a)*(.243+camada*.01+linha*.015),y-linha*.09,sin(a)*(.182+camada*.012+linha*.012)-.012)
					anel.append(Tecido.vertice(p,{"DEF-hips":1.0},ligacoes))
				if not anterior.is_empty():
					for q in 6:Tecido.quad(saias,anterior[q],anel[q],anel[q+1],anterior[q+1],Vector3(anel[q].p.x,0,anel[q].p.z))
				anterior=anel
	partes.append(Placas.marcar(Base.finalizar(saias),3))
	return Placas.juntar(partes)

static func luvas(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [-1,1]:Placas.bracelete(st,Tecido.ligacoes(corpo,rig),lado,[[.58,.072,.074],[.635,.095,.09],[.69,.073,.074],[.75,.056,.055]],12)
	return Placas.juntar([Placas.marcar(Base.luvas(corpo),0),Placas.marcar(Base.finalizar(st),2)])

static func botas(base: ArrayMesh,corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
	# Mesmos encaixes físicos do rig; desenho e acabamento próprios no material.
	return Placas.botas(base,corpo,rig)
