extends RefCounted
## Aço antigo, chifres e tecido rubro da referência do usuário, no rig canônico.
const Tecido=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Base=preload("res://codigo/jogador/moldes_mordomo_3d.gd")
const Placas=preload("res://codigo/jogador/moldes_carrasco_3d.gd")

static func chifre(st: SurfaceTool,rig: Dictionary,t: Transform3D,secoes: Array,pesos: Dictionary):
 var anterior: Array=[]
 for i in secoes.size():
  var centro: Vector3=secoes[i][0]
  var eixo: Vector3=(secoes[mini(i+1,secoes.size()-1)][0]-secoes[maxi(0,i-1)][0]).normalized()
  var u:=eixo.cross(Vector3.FORWARD).normalized()
  var v:=eixo.cross(u).normalized()
  var anel: Array=[]
  for q in 8:
   var n:=u*cos(TAU*q/8.)+v*sin(TAU*q/8.)
   anel.append(Tecido.vertice(t*(centro+n*secoes[i][1]),pesos,rig))
  if not anterior.is_empty():
   for q in 8:
    var n:=u*cos(TAU*(q+.5)/8.)+v*sin(TAU*(q+.5)/8.)
    Tecido.quad(st,anterior[q],anel[q],anel[(q+1)%8],anterior[(q+1)%8],t.basis*n)
  anterior=anel

static func elmo(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var t:=Base.espaco(corpo).affine_inverse()*Base.espaco(rig)*rig.get_bone_global_rest(rig.find_bone("DEF-head"))
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 Base.cilindro(st,ligacoes,t,[[-.045,.001,.001],[-.03,.072,.10],[.025,.108,.145],[.13,.119,.16],[.225,.115,.15],[.285,.09,.125],[.32,.035,.07],[.335,.001,.001]],"DEF-head")
 var casco:=Placas.marcar(Base.finalizar(st),0,t.affine_inverse())
 var pontas:=SurfaceTool.new();pontas.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:
  chifre(pontas,ligacoes,t,[[Vector3(lado*.105,.235,-.015),.047],[Vector3(lado*.20,.29,-.04),.039],[Vector3(lado*.285,.305,-.08),.023],[Vector3(lado*.365,.30,-.12),.001]],{"DEF-head":1.})
 chifre(pontas,ligacoes,t,[[Vector3(-.045,.285,-.055),.033],[Vector3(-.095,.385,-.085),.027],[Vector3(-.155,.485,-.12),.017],[Vector3(-.21,.575,-.15),.001]],{"DEF-head":1.})
 chifre(pontas,ligacoes,t,[[Vector3(.045,.285,-.075),.032],[Vector3(.095,.38,-.11),.025],[Vector3(.145,.455,-.15),.014],[Vector3(.185,.515,-.19),.001]],{"DEF-head":1.})
 var viseira:=Placas.placa([Vector3(-.095,.23,.14),Vector3(0,.255,.16),Vector3(.095,.23,.14),Vector3(.085,.06,.145),Vector3(0,-.035,.19),Vector3(-.085,.06,.145)],Vector3(0,.12,.205),ligacoes,{"DEF-head":1.},t)
 return Placas.juntar([casco,Placas.marcar(Base.finalizar(pontas),1,t.affine_inverse()),Placas.marcar(viseira,4,t.affine_inverse())])

static func peitoral(corpo: MeshInstance3D,rig: Skeleton3D,camisa: ArrayMesh,calca: ArrayMesh) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var malhas: Array=[Placas.marcar(Base.ajustar(camisa,ligacoes,"casaca"),0),Placas.marcar(Base.ajustar(calca,ligacoes,"calca"),0)]
 # Três lâminas sobrepostas por ombro; volume real e bordas separadas.
 for camada in 3:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var x:=.225+camada*.067
  for lado in [-1,1]:
   Placas.bracelete(st,ligacoes,lado,[[x,.135-camada*.008,.147],[x+.03,.197-camada*.014,.205],[x+.105,.170-camada*.013,.215],[x+.135,.117-camada*.008,.21]],8)
  malhas.append(Placas.marcar(Base.finalizar(st),2.+camada*.1))
 var espinhos:=SurfaceTool.new();espinhos.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lado in [-1,1]:
  chifre(espinhos,ligacoes,Transform3D.IDENTITY,[[Vector3(lado*.32,1.60,-.09),.045],[Vector3(lado*.40,1.68,-.13),.028],[Vector3(lado*.50,1.72,-.17),.001]],{"DEF-upper_arm.L" if lado>0 else "DEF-upper_arm.R":1.})
 malhas.append(Placas.marcar(Base.finalizar(espinhos),7))
 # Quatro panos fendidos seguem quadril e coxa correspondente sem fechar a passada.
 var saias:=SurfaceTool.new();saias.begin(Mesh.PRIMITIVE_TRIANGLES)
 for painel in 4:
  var anterior: Array=[]
  for linha in [[1.045,.255,.191],[.91,.275,.205],[.69,.29,.217]]:
   var anel: Array=[]
   for q in 9:
    var a:=painel*PI*.5+.095+q*(PI*.5-.19)/8.
    var p:=Vector3(cos(a)*linha[1],linha[0]+(.025*cos(a*4.) if linha[0]<.8 else 0.),sin(a)*linha[2]-.008)
    var peso:=lerpf(.42,1.,smoothstep(.69,1.025,p.y))
    anel.append(Tecido.vertice(p,{"DEF-hips":peso,"DEF-thigh.L" if p.x>0 else "DEF-thigh.R":1.-peso},ligacoes))
   if not anterior.is_empty():
    for q in 8:Tecido.quad(saias,anterior[q],anel[q],anel[q+1],anterior[q+1],Vector3(anel[q].p.x,0,anel[q].p.z))
   anterior=anel
 malhas.append(Placas.marcar(Base.finalizar(saias),3))
 var peito:=Placas.placa([Vector3(-.195,1.455,.145),Vector3(0,1.49,.175),Vector3(.195,1.455,.145),Vector3(.192,1.25,.195),Vector3(0,1.14,.23),Vector3(-.192,1.25,.195)],Vector3(0,1.345,.24),ligacoes,{"DEF-spine.002":.60,"DEF-spine.003":.40})
 malhas.append(Placas.marcar(peito,4))
 var cintura:=SurfaceTool.new();cintura.begin(Mesh.PRIMITIVE_TRIANGLES)
 Base.cilindro(cintura,ligacoes,Transform3D.IDENTITY,[[1.005,.255,.199],[1.055,.259,.202],[1.13,.238,.199]],"DEF-hips")
 malhas.append(Placas.marcar(Base.finalizar(cintura),5))
 var inferior:=Placas.placa([Vector3(-.075,1.045,.207),Vector3(.075,1.045,.207),Vector3(.09,.86,.24),Vector3(0,.77,.27),Vector3(-.09,.86,.24)],Vector3(0,.92,.273),ligacoes,{"DEF-hips":1.})
 malhas.append(Placas.marcar(inferior,6))
 return Placas.juntar(malhas)

static func luvas(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 return Placas.luvas(corpo,rig)

static func botas(base: ArrayMesh,corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 return Placas.botas(base,corpo,rig)
