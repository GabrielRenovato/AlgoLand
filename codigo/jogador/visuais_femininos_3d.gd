extends RefCounted
## Modelagem nativa para o rig canônico. Cabelo acompanha a cabeça;
## saias conservam a meia-calça e recebem pesos leves das duas coxas.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
static func cabelo(base: ArrayMesh,corpo: MeshInstance3D,s: Skeleton3D,forma: int) -> ArrayMesh:
    var cabeca_para_malha:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
    base=_abrir_franja(base,cabeca_para_malha)
    if forma not in [4,5]: return base
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.append_from(base,0,Transform3D.IDENTITY)
    st.deindex()
    var rig:=Modelagem.ligacoes(corpo,s)
    var bind: int=rig["DEF-head"]
    var transformacao:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
    if forma==4:
        # Raspado: sem malha; o shader da pele pinta o cabelo rente (raspado no acabamento_base_3d).
        return ArrayMesh.new()
    if forma==5:
        # Espetado: touca curta e pontas cônicas pelo topo, inclinadas para trás.
        var aneis5: Array=[]
        for nivel in 3:
            var anel5: Array=[]
            for q in 33:
                var a:=-TAU*q/32.0
                var raio: float=[.070,.114,.120][nivel]
                var y: float=[.255,.215,.140][nivel]
                if nivel==2: y+=.06*maxf(0.0,sin(a))-.03*maxf(0.0,-sin(a))
                anel5.append(Vector3(cos(a)*raio,y,sin(a)*raio*.95-.012))
            aneis5.append(anel5)
        for n in 2:
            for q in 32:
                _quad_cabelo(st,[aneis5[n][q],aneis5[n+1][q],aneis5[n+1][q+1],aneis5[n][q+1]],transformacao,bind)
        for i in 9:
            var a:=TAU*i/9.0+.3
            var base5:=Vector3(cos(a)*.065,.245,sin(a)*.062-.02)
            var ponta5:=base5+Vector3(cos(a)*.045,.075,sin(a)*.03-.035)
            _mecha(st,[[base5,.028,.026],[base5.lerp(ponta5,.55),.016,.015],[ponta5,.002,.002]],transformacao,bind)
    st.generate_normals()
    st.index()
    return st.commit()

## Levanta somente a frente do molde, sem alterar nuca, UVs ou pesos do rig.
static func _abrir_franja(base: ArrayMesh,t: Transform3D) -> ArrayMesh:
    var nova:=ArrayMesh.new()
    var inversa:=t.affine_inverse()
    for superficie in base.get_surface_count():
        var dados:=base.surface_get_arrays(superficie).duplicate(true)
        var vertices: PackedVector3Array=dados[Mesh.ARRAY_VERTEX]
        for i in vertices.size():
            var p:=inversa*vertices[i]
            var frente:=smoothstep(0.065,0.105,p.z)
            var ponta:=1.0-smoothstep(0.185,0.245,p.y)
            var centro:=1.0-smoothstep(0.080,0.115,absf(p.x))
            var levantamento:=0.035*frente*ponta*centro
            if levantamento<=0.0: continue
            p.y+=levantamento
            vertices[i]=t*p
        dados[Mesh.ARRAY_VERTEX]=vertices
        nova.add_surface_from_arrays(base.surface_get_primitive_type(superficie),dados)
        nova.surface_set_material(superficie,base.surface_get_material(superficie))
    return nova

static func _mecha(st: SurfaceTool,secoes: Array,t: Transform3D,bind: int):
    for n in range(secoes.size()-1):
        for q in 12:
            var a:=-TAU*q/12.0
            var b:=-TAU*(q+1)/12.0
            var cima: Array=secoes[n]
            var baixo: Array=secoes[n+1]
            _quad_cabelo(st,[cima[0]+Vector3(cos(a)*cima[1],0,sin(a)*cima[2]),baixo[0]+Vector3(cos(a)*baixo[1],0,sin(a)*baixo[2]),baixo[0]+Vector3(cos(b)*baixo[1],0,sin(b)*baixo[2]),cima[0]+Vector3(cos(b)*cima[1],0,sin(b)*cima[2])],t,bind)
static func _quad_cabelo(st: SurfaceTool,pontos: Array,t: Transform3D,bind: int):
    for face in [[0,1,2],[0,2,3]]:
        var normal: Vector3=(pontos[face[1]]-pontos[face[0]]).cross(pontos[face[2]]-pontos[face[0]]).normalized()
        # Ordem horária e normal exterior das seções verticais.
        for k in [2,1,0]:
            var p: Vector3=pontos[face[k]]
            st.set_bones(PackedInt32Array([bind,0,0,0]))
            st.set_weights(PackedFloat32Array([1,0,0,0]))
            st.set_color(Color.WHITE)
            st.set_normal(t.basis*normal)
            st.set_uv(Vector2(atan2(p.x,p.z)/TAU+.5,clampf((.28-p.y)/.40,.1,.98)))
            st.add_vertex(t*p)
static func saia(base: ArrayMesh,corpo: MeshInstance3D,s: Skeleton3D,forma: int) -> ArrayMesh:
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.append_from(base,0,Transform3D.IDENTITY)
    st.deindex()
    var rig:=Modelagem.ligacoes(corpo,s)
    var aneis: Array=[]
    var longa:=forma==4
    var medidas: Array=[[1.055,.242,.178],[1.018,.247,.184],[.92,.285,.215],[.80,.321,.247],[.64 if longa else .71,.355 if longa else .342,.280 if longa else .263]]
    for nivel in medidas.size():
        var m: Array=medidas[nivel]
        var anel: Array=[]
        for q in 48:
            var a:=TAU*q/48.0
            var prega:=.009*cos(a*(12 if longa else 8))*nivel/4.0
            var p:=Vector3(cos(a)*(m[1]+prega),m[0],-.012+sin(a)*(m[2]+prega))
            var perna: String="DEF-thigh.L" if p.x>0 else "DEF-thigh.R"
            var peso:=.20*smoothstep(1.02,.70,p.y)
            anel.append(Modelagem.vertice(p,{"DEF-hips":1.0-peso,perna:peso},rig,.86 if nivel==0 else 1.0))
        aneis.append(anel)
    for n in range(aneis.size()-1): Modelagem.unir(st,aneis[n],aneis[n+1],Vector3(0,0,-.012))
    # Barra com espessura; o avesso usa as mesmas influências.
    var interno: Array=[]
    for v in aneis[-1]:
        var novo: Dictionary=v.duplicate()
        novo.p=Vector3(v.p.x*.975,v.p.y+.018,-.012+(v.p.z+.012)*.975)
        novo.tom=.78
        interno.append(novo)
    Modelagem.unir(st,aneis[-1],interno,Vector3(0,0,-.012))
    st.generate_normals()
    st.index()
    return st.commit()
