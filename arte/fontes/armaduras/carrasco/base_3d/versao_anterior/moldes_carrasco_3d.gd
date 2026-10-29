extends RefCounted
## Placas e elmo próprios do Carrasco sobre o rig canônico, em repouso.
const Tecido=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Base=preload("res://codigo/jogador/moldes_mordomo_3d.gd")

static func marcar(malha: ArrayMesh,regiao: float,local:=Transform3D.IDENTITY) -> ArrayMesh:
 var nova:=ArrayMesh.new()
 for s in malha.get_surface_count():
  var a:=malha.surface_get_arrays(s)
  var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
  for ponto in a[Mesh.ARRAY_VERTEX]:
   var p: Vector3=local*ponto
   uv.append(Vector2(p.x,p.y));uv2.append(Vector2(p.z,regiao))
  a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_TEX_UV2]=uv2
  nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 return nova

static func juntar(malhas: Array) -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.create_from(malhas[0],0)
 for i in range(1,malhas.size()):st.append_from(malhas[i],0,Transform3D.IDENTITY)
 return Base.finalizar(st)

static func elmo(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var t:=Base.espaco(corpo).affine_inverse()*Base.espaco(rig)*rig.get_bone_global_rest(rig.find_bone("DEF-head"))
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 Base.cilindro(st,ligacoes,t,[[-.035,.001,.001],[-.025,.065,.09],[.0,.107,.14],[.07,.127,.164],[.14,.132,.17],[.21,.125,.157],[.265,.10,.125],[.30,.06,.08],[.32,.001,.001]],"DEF-head")
 var casco:=marcar(Base.finalizar(st),0,t.affine_inverse())
 var pluma:=SurfaceTool.new();pluma.begin(Mesh.PRIMITIVE_TRIANGLES)
 var anterior: Array=[]
 for medida in [[.30,.015,.016,.025],[.38,-.015,.028,.060],[.44,-.07,.035,.065],[.41,-.14,.030,.065],[.30,-.21,.027,.055],[.14,-.25,.016,.045],[.09,-.27,.001,.001]]:
  var anel: Array=[]
  for q in 20:
   var a:=TAU*q/20.0
   var p:=t*Vector3(cos(a)*medida[2],medida[0]+sin(a)*medida[3],medida[1])
   anel.append(Tecido.vertice(p,{"DEF-head":1.0},ligacoes))
  if not anterior.is_empty():
   for q in 20:
    var n: int=(q+1)%20
    Tecido.quad(pluma,anterior[q],anel[q],anel[n],anterior[n],t.basis*Vector3(cos(TAU*(q+.5)/20.),sin(TAU*(q+.5)/20.),0))
  anterior=anel
 return juntar([casco,marcar(Base.finalizar(pluma),1,t.affine_inverse())])

static func bracelete(st: SurfaceTool,rig: Dictionary,lado: int,secoes: Array):
 var anterior: Array=[]
 var sufixo: String=".L" if lado>0 else ".R"
 for secao in secoes:
  var x: float=secao[0]
  var cotovelo:=smoothstep(.419,.513,x)
  var anel: Array=[]
  for q in 24:
   var a:=TAU*q/24.0
   var p:=Vector3(lado*x,1.4408+cos(a)*secao[1],-.0654+sin(a)*secao[2])
   anel.append(Tecido.vertice(p,{"DEF-upper_arm"+sufixo:1.-cotovelo,"DEF-forearm"+sufixo:cotovelo},rig))
  if not anterior.is_empty():
   for q in 24:
    var n: int=(q+1)%24
    Tecido.quad(st,anterior[q],anel[q],anel[n],anterior[n],Vector3(0,cos(TAU*(q+.5)/24.),sin(TAU*(q+.5)/24.)))
  anterior=anel

static func peitoral(corpo: MeshInstance3D,rig: Skeleton3D,camisa: ArrayMesh,calca: ArrayMesh) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var tronco:=Base.ajustar(camisa,ligacoes,"casaca")
 var a:=tronco.surface_get_arrays(0)
 var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
 for i in vs.size():
  var p:=vs[i]
  if absf(p.x)<.265 and p.y<1.5:
   p.x*=1.07;p.z*=1.10
  vs[i]=p
 a[Mesh.ARRAY_VERTEX]=vs
 var placa:=ArrayMesh.new();placa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var ombros:=SurfaceTool.new();ombros.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:bracelete(ombros,ligacoes,lado,[[.25,.12,.12],[.27,.17,.16],[.34,.178,.16],[.415,.145,.14],[.43,.12,.13]])
 var saias:=SurfaceTool.new();saias.begin(Mesh.PRIMITIVE_TRIANGLES)
 for painel in 4:
  var anterior: Array=[]
  for linha in [[1.06,.25,.182],[.96,.267,.193],[.83,.285,.202]]:
   var anel: Array=[]
   for q in 9:
    var angulo: float=painel*PI*.5+.10+q*(PI*.5-.20)/8.0
    var p:=Vector3(cos(angulo)*linha[1],linha[0]+(.025*cos(angulo*4.) if linha[0]<.9 else 0.),sin(angulo)*linha[2]-.012)
    anel.append(Tecido.vertice(p,{"DEF-hips":1.0},ligacoes))
   if not anterior.is_empty():
    for q in 8:Tecido.quad(saias,anterior[q],anel[q],anel[q+1],anterior[q+1],Vector3(anel[q].p.x,0,anel[q].p.z))
   anterior=anel
 return juntar([marcar(placa,0),marcar(Base.ajustar(calca,ligacoes,"calca"),0),marcar(Base.finalizar(ombros),2),marcar(Base.finalizar(saias),3)])

static func luvas(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var punhos:=SurfaceTool.new();punhos.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:bracelete(punhos,Tecido.ligacoes(corpo,rig),lado,[[.64,.069,.065],[.67,.081,.077],[.72,.075,.070],[.751,.056,.052]])
 return juntar([marcar(Base.luvas(corpo),0),marcar(Base.finalizar(punhos),2)])

static func botas(base: ArrayMesh) -> ArrayMesh:
 var a:=base.surface_get_arrays(0)
 var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
 for i in vs.size():
  var p:=vs[i]
  if p.y>.14:
   var t:=smoothstep(.14,.35,p.y)
   p.x=signf(p.x)*.089+(p.x-signf(p.x)*.089)*lerpf(1.,1.42,t)
   p.z*=lerpf(1.,1.18,t)
   p.y=.14+(p.y-.14)*1.65
  vs[i]=p
 a[Mesh.ARRAY_VERTEX]=vs
 var malha:=ArrayMesh.new();malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 return marcar(malha,0)
