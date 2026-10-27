extends RefCounted
## Adaptação da referência cavalheiro ao rig canônico, em metros de repouso.
const Tecido = preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Recorte = preload("res://codigo/jogador/roupas_base_3d.gd")

static func espaco(no: Node3D) -> Transform3D:
 var resultado:=no.transform
 var pai:=no.get_parent()
 while pai is Node3D:
  resultado=pai.transform*resultado
  pai=pai.get_parent()
 return resultado

static func cilindro(st: SurfaceTool,rig: Dictionary,t: Transform3D,secoes: Array,osso: String):
 var anterior: Array=[]
 for secao in secoes:
  var anel: Array=[]
  for q in 32:
   var a:=TAU*q/32.0
   anel.append(Tecido.vertice(t*Vector3(cos(a)*secao[1],secao[0],sin(a)*secao[2]),{osso:1.0},rig))
  if not anterior.is_empty():
   for q in 32:
    var n: int=(q+1)%32
    var fora:=t.basis*Vector3(cos(TAU*(q+.5)/32.0),0,sin(TAU*(q+.5)/32.0))
    if secao[1]<.001:fora=t.basis*Vector3.UP
    Tecido.quad(st,anterior[q],anel[q],anel[n],anterior[n],fora)
  anterior=anel

static func finalizar(st: SurfaceTool) -> ArrayMesh:
 st.set_smooth_group(0)
 st.generate_normals()
 st.index()
 return st.commit()

static func cartola(corpo: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var t:=espaco(corpo).affine_inverse()*espaco(rig)*rig.get_bone_global_rest(rig.find_bone("DEF-head"))
 cilindro(st,Tecido.ligacoes(corpo,rig),t,[[.235,.001,.001],[.235,.148,.162],[.249,.148,.162],[.255,.115,.130],[.295,.115,.130],[.425,.113,.128],[.436,.117,.132],[.448,.117,.132],[.448,.001,.001]],"DEF-head")
 var malha:=finalizar(st)
 var a:=malha.surface_get_arrays(0)
 var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
 for p in a[Mesh.ARRAY_VERTEX]:
  var local: Vector3=t.affine_inverse()*p
  uv.append(Vector2(local.x,local.y));uv2.append(Vector2(local.z,0))
 a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_TEX_UV2]=uv2
 var nova:=ArrayMesh.new();nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 return nova

static func ajustar(mesh: ArrayMesh,rig: Dictionary,modo: String) -> ArrayMesh:
 var st:=SurfaceTool.new()
 for s in mesh.get_surface_count():
  var a:=mesh.surface_get_arrays(s)
  var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
  var bs: PackedInt32Array=a[Mesh.ARRAY_BONES]
  var ws: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
  var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
  for i in vs.size():
   var p:=vs[i]
   if modo=="casaca" and absf(p.x)>.265:
    var x:=absf(p.x)
    var u:=clampf((x-.265)/(.427-.265),0,1)
    p.x=signf(p.x)*lerpf(.265,.733,u)
    p.y=1.4408+(p.y-1.435)*lerpf(1.0,.56,u)
    p.z=lerpf(-.012,-.0654,u)+(p.z+.012)*lerpf(1.0,.56,u)
    var cotovelo:=smoothstep(.419,.513,absf(p.x))
    var pesos: Dictionary={"DEF-upper_arm.L" if p.x>0 else "DEF-upper_arm.R":1.0-cotovelo,"DEF-forearm.L" if p.x>0 else "DEF-forearm.R":cotovelo}
    var v:=Tecido.vertice(p,pesos,rig)
    for k in 4:bs[i*4+k]=v.b[k];ws[i*4+k]=v.w[k]
   if modo=="botas" and p.y>.14:p.y=.14+(p.y-.14)*.70
   vs[i]=p;uv.append(Vector2(p.x,p.y));uv2.append(Vector2(p.z,0))
  a[Mesh.ARRAY_VERTEX]=vs;a[Mesh.ARRAY_BONES]=bs;a[Mesh.ARRAY_WEIGHTS]=ws
  a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_TEX_UV2]=uv2
  var parcial:=ArrayMesh.new();parcial.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
  if s==0:st.create_from(parcial,0)
  else:st.append_from(parcial,0,Transform3D.IDENTITY)
 return finalizar(st)

static func casaca(corpo: MeshInstance3D,rig: Skeleton3D,camisa: ArrayMesh,calca: ArrayMesh) -> ArrayMesh:
 var ligacoes:=Tecido.ligacoes(corpo,rig)
 var st:=SurfaceTool.new()
 st.create_from(ajustar(camisa,ligacoes,"casaca"),0)
 st.append_from(ajustar(calca,ligacoes,"calca"),0,Transform3D.IDENTITY)
 var abas:=SurfaceTool.new();abas.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Duas abas traseiras com costura no quadril e liberdade na passada.
 for lado in [-1,1]:
  var anterior: Array=[]
  for linha in [[1.055,.19,.0],[.94,.235,.0],[.69,.225,.22]]:
   var atual: Array=[]
   for q in 9:
    var u:=q/8.0
    var angulo:=lerpf(1.5*PI,TAU,u)
    var x:=lerpf(.018,linha[1],sin(u*PI*.5))
    var y: float=linha[0]+linha[2]*pow(1.-u,2.)
    var p:=Vector3(lado*x,y,-.026+sin(angulo)*.174)
    var peso:=lerpf(.75,1.0,smoothstep(.69,1.025,p.y))
    atual.append(Tecido.vertice(p,{"DEF-hips":peso,"DEF-thigh.L" if lado>0 else "DEF-thigh.R":1.0-peso},ligacoes))
   if not anterior.is_empty():
    for q in 8:Tecido.quad(abas,anterior[q],atual[q],atual[q+1],anterior[q+1],Vector3(0,0,-1))
   anterior=atual
 var cauda:=finalizar(abas)
 var a:=cauda.surface_get_arrays(0)
 var uv2: PackedVector2Array=a[Mesh.ARRAY_TEX_UV2]
 for i in uv2.size():uv2[i].y=1.0
 a[Mesh.ARRAY_TEX_UV2]=uv2
 var marcada:=ArrayMesh.new();marcada.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 st.append_from(marcada,0,Transform3D.IDENTITY)
 return finalizar(st)

static func luvas(corpo: MeshInstance3D) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for s in corpo.mesh.get_surface_count():
  var a:=corpo.mesh.surface_get_arrays(s)
  var vertices: Array=[]
  for i in a[Mesh.ARRAY_VERTEX].size():
   var p: Vector3=a[Mesh.ARRAY_VERTEX][i]
   vertices.append({"p":p,"n":a[Mesh.ARRAY_NORMAL][i],"b":a[Mesh.ARRAY_BONES].slice(i*4,i*4+4),"w":a[Mesh.ARRAY_WEIGHTS].slice(i*4,i*4+4),"f":minf(absf(p.x)-.716,minf(p.y-1.20,1.67-p.y))})
  var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
  for i in range(0,indices.size(),3):
   var poligono:=Recorte.recortar([vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]])
   for j in range(1,poligono.size()-1):
    for v in [poligono[0],poligono[j],poligono[j+1]]:
     st.set_color(Color.WHITE);st.set_uv(Vector2(v.p.x,v.p.y));st.set_uv2(Vector2(v.p.z,0))
     Recorte.emitir(st,v,.005)
 return finalizar(st)
