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

## Placa convexa com crista central real, sem decalque flutuante.
static func placa(pontos: Array,centro: Vector3,rig: Dictionary,pesos: Dictionary,t:=Transform3D.IDENTITY) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var c:=Tecido.vertice(t*centro,pesos,rig)
 for i in pontos.size():
  var a:=Tecido.vertice(t*pontos[i],pesos,rig)
  var b:=Tecido.vertice(t*pontos[(i+1)%pontos.size()],pesos,rig)
  Tecido.face(st,c,a,b,t.basis*Vector3.BACK)
 return Base.finalizar(st)

static func elmo(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var t:=Base.espaco(corpo).affine_inverse()*Base.espaco(rig)*rig.get_bone_global_rest(rig.find_bone("DEF-head"))
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 Base.cilindro(st,ligacoes,t,[[-.04,.001,.001],[-.025,.065,.095],[.0,.103,.14],[.08,.118,.156],[.16,.122,.163],[.24,.112,.15],[.29,.085,.12],[.33,.035,.065],[.35,.001,.001]],"DEF-head")
 var casco:=marcar(Base.finalizar(st),0,t.affine_inverse())
 var pluma:=SurfaceTool.new();pluma.begin(Mesh.PRIMITIVE_TRIANGLES)
 var anterior: Array=[]
 for medida in [[.33,.012,.012,.017],[.39,-.025,.021,.045],[.405,-.075,.024,.05],[.365,-.14,.021,.05],[.26,-.205,.018,.05],[.13,-.25,.010,.035],[.08,-.27,.001,.001]]:
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
 var viseira:=placa([Vector3(-.09,.19,.145),Vector3(-.065,.232,.15),Vector3(0,.248,.16),Vector3(.065,.232,.15),Vector3(.09,.19,.145),Vector3(.087,.035,.145),Vector3(0,-.025,.17),Vector3(-.087,.035,.145)],Vector3(0,.12,.195),ligacoes,{"DEF-head":1.0},t)
 return juntar([casco,marcar(Base.finalizar(pluma),1,t.affine_inverse()),marcar(viseira,4,t.affine_inverse())])

static func bracelete(st: SurfaceTool,rig: Dictionary,lado: int,secoes: Array,lados:=24):
 var anterior: Array=[]
 var sufixo: String=".L" if lado>0 else ".R"
 for secao in secoes:
  var x: float=secao[0]
  var cotovelo:=smoothstep(.419,.513,x)
  var anel: Array=[]
  for q in lados:
   var a:=TAU*q/float(lados)
   var p:=Vector3(lado*x,1.4408+cos(a)*secao[1],-.0654+sin(a)*secao[2])
   anel.append(Tecido.vertice(p,{"DEF-upper_arm"+sufixo:1.-cotovelo,"DEF-forearm"+sufixo:cotovelo},rig))
  if not anterior.is_empty():
   for q in lados:
    var n: int=(q+1)%lados
    Tecido.quad(st,anterior[q],anel[q],anel[n],anterior[n],Vector3(0,cos(TAU*(q+.5)/float(lados)),sin(TAU*(q+.5)/float(lados))))
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
 var tronco_malha:=ArrayMesh.new();tronco_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var ombros:=SurfaceTool.new();ombros.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:bracelete(ombros,ligacoes,lado,[[.215,.11,.12],[.265,.177,.166],[.365,.166,.175],[.455,.12,.178],[.485,.105,.175]],8)
 var saias:=SurfaceTool.new();saias.begin(Mesh.PRIMITIVE_TRIANGLES)
 for painel in 4:
  var anterior: Array=[]
  for linha in [[1.06,.25,.182],[.96,.267,.193],[.83,.285,.202]]:
   var anel: Array=[]
   for q in 5:
    var angulo: float=painel*PI*.5+.10+q*(PI*.5-.20)/4.0
    var p:=Vector3(cos(angulo)*linha[1],linha[0]+(.025*cos(angulo*4.) if linha[0]<.9 else 0.),sin(angulo)*linha[2]-.012)
    anel.append(Tecido.vertice(p,{"DEF-hips":1.0},ligacoes))
   if not anterior.is_empty():
    for q in 4:Tecido.quad(saias,anterior[q],anel[q],anel[q+1],anterior[q+1],Vector3(anel[q].p.x,0,anel[q].p.z))
   anterior=anel
 var peito:=placa([Vector3(-.20,1.44,.135),Vector3(-.18,1.30,.177),Vector3(0,1.215,.218),Vector3(.18,1.30,.177),Vector3(.20,1.44,.135),Vector3(0,1.49,.157)],Vector3(0,1.36,.215),ligacoes,{"DEF-spine.002":.60,"DEF-spine.003":.40})
 var abdominal:=placa([Vector3(0,1.20,.208),Vector3(.078,1.125,.21),Vector3(.080,1.055,.215),Vector3(0,.98,.24),Vector3(-.080,1.055,.215),Vector3(-.078,1.125,.21)],Vector3(0,1.09,.26),ligacoes,{"DEF-hips":.75,"DEF-spine.001":.25})
 var inferior:=placa([Vector3(-.105,1.0,.205),Vector3(.105,1.0,.205),Vector3(.125,.84,.224),Vector3(0,.715,.25),Vector3(-.125,.84,.224)],Vector3(0,.87,.256),ligacoes,{"DEF-hips":1.0})
 return juntar([marcar(tronco_malha,0),marcar(Base.ajustar(calca,ligacoes,"calca"),0),marcar(Base.finalizar(ombros),2),marcar(Base.finalizar(saias),3),marcar(peito,4),marcar(abdominal,5),marcar(inferior,6)])

static func luvas(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var punhos:=SurfaceTool.new();punhos.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:bracelete(punhos,Tecido.ligacoes(corpo,rig),lado,[[.63,.083,.079],[.655,.084,.08],[.71,.065,.064],[.751,.054,.053]],8)
 return juntar([marcar(Base.luvas(corpo),0),marcar(Base.finalizar(punhos),2)])

static func botas(base: ArrayMesh,corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var a:=base.surface_get_arrays(0)
 var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
 for i in vs.size():
  var p:=vs[i]
  if p.y>.14:
   var t:=smoothstep(.14,.35,p.y)
   p.x=signf(p.x)*.089+(p.x-signf(p.x)*.089)*lerpf(1.,1.42,t)
   p.z*=lerpf(1.,1.18,t)
   p.y=.14+(p.y-.14)*2.0
  vs[i]=p
 a[Mesh.ARRAY_VERTEX]=vs
 var malha:=ArrayMesh.new();malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var joelhos: Array=[marcar(malha,0)]
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 for lado in [-1,1]:
  var x: float=lado*.112
  var osso: String="DEF-shin.L" if lado>0 else "DEF-shin.R"
  var joelho:=placa([Vector3(x-.065,.56,.12),Vector3(x,.605,.125),Vector3(x+.065,.56,.12),Vector3(x+.070,.495,.13),Vector3(x,.44,.16),Vector3(x-.070,.495,.13)],Vector3(x,.525,.19),ligacoes,{osso:1.0})
  joelhos.append(marcar(joelho,3))
 return juntar(joelhos)
