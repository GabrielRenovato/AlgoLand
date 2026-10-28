extends RefCounted
## Modelagem nativa para o rig canônico. Cabelo acompanha a cabeça;
## saias conservam a meia-calça e recebem pesos leves das duas coxas.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
static func cabelo(base: ArrayMesh,corpo: MeshInstance3D,s: Skeleton3D,forma: int) -> ArrayMesh:
    var cabeca_para_malha:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
    if forma==6: return _cabelo_liso(corpo,s)
    base=_abrir_franja(base,cabeca_para_malha)
    if forma not in [3,4]: return base
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
    if forma==3:
        # Volume cacheado contínuo, com cachos sobrepostos e distribuição
        # irregular; nenhuma divisão em duas tranças ou caudas laterais.
        for faixa in 3:
            var quantidade: int=[11,15,13][faixa]
            for i in quantidade:
                var a: float=TAU*(i+.37*faixa)/quantidade
                var frente:=sin(a)>.25
                if frente and faixa>0: continue
                var raio: float=[.095,.124,.118][faixa]
                var y: float=[.235,.145,.035][faixa]
                var tamanho:=.033+.005*sin(i*2.7+faixa)
                var centro:=Vector3(cos(a)*raio,y+.009*sin(i*1.9),sin(a)*raio-.015)
                _cacho(st,centro,Vector3(tamanho,.046 if faixa==0 else .055,tamanho*.90),transformacao,bind)
        _cacho(st,Vector3(0,.267,-.015),Vector3(.067,.033,.060),transformacao,bind)
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

static func _cacho(st: SurfaceTool,centro: Vector3,raios: Vector3,t: Transform3D,bind: int):
    var secoes: Array=[]
    for i in 7:
        var a:=PI*i/6.0
        var largura:=maxf(.025,sin(a))
        var deslocamento:=Vector3(sin(a*2)*.008,cos(a)*raios.y,cos(a*2)*.006)
        secoes.append([centro+deslocamento,raios.x*largura,raios.z*largura])
    _mecha(st,secoes,t,bind)

## Longo liso: calota lisa no alto, fios retos pelas laterais e costas até o meio das costas,
## pontas em leve V. Fica aberto na frente abaixo da testa para não cobrir rosto e olhos.
## Medidas no espaço do osso da cabeça (a proporção chibi amplia 2,38× / 1,75× / 2,3×).
static func _cabelo_liso(corpo: MeshInstance3D,s: Skeleton3D) -> ArrayMesh:
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var bind: int=Modelagem.ligacoes(corpo,s)["DEF-head"]
    var t:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
    # [altura, raio, recuo para trás, abertura da frente (0 = fechado)]
    var niveis:=[
        [.292,.022,.000,0.0],[.280,.078,.000,0.0],[.250,.114,.000,0.0],[.200,.130,.000,0.0], # Calota (acima da cabeça chibi).
        [.140,.130,.004,.62],[.080,.130,.010,.95],[.010,.124,.020,1.15], # Testa e laterais do rosto.
        [-.070,.118,.032,1.45],[-.150,.112,.045,1.75],[-.230,.106,.055,1.95],[-.300,.100,.060,2.05]] # Fios até as costas.
    var segmentos:=32
    var aneis: Array=[]
    for n in niveis.size():
        var nivel: Array=niveis[n]
        var abertura: float=nivel[3]
        var anel: Array=[]
        for q in segmentos+1:
            # Ângulo decrescente (ordem das faces do _quad_cabelo); a frente é sin(a)=1.
            var a: float
            if abertura<=0.0:
                a=PI*.5-TAU*q/segmentos
            else:
                a=lerpf(PI*.5-abertura,-PI*1.5+abertura,float(q)/segmentos)
            var y: float=nivel[0]
            # Pontas em leve V: o centro das costas desce um pouco mais.
            if n==niveis.size()-1: y-=.025*maxf(0.0,-sin(a))
            var raio: float=nivel[1]*(1.0+.012*sin(a*7.0+n)) # Fios levemente irregulares.
            anel.append(Vector3(cos(a)*raio,y,sin(a)*raio*.92-nivel[2]))
        aneis.append(anel)
    for n in aneis.size()-1:
        for q in segmentos:
            _quad_cabelo(st,[aneis[n][q],aneis[n+1][q],aneis[n+1][q+1],aneis[n][q+1]],t,bind)
            # Avesso nos fios soltos: visto de baixo/de lado não fica oco.
            if n>=4:
                var dentro: Array=[aneis[n][q],aneis[n+1][q],aneis[n+1][q+1],aneis[n][q+1]].map(func(p): return Vector3(p.x*.95,p.y,p.z*.95-.003))
                _quad_cabelo(st,[dentro[3],dentro[2],dentro[1],dentro[0]],t,bind)
    st.generate_normals()
    st.index()
    return st.commit()
