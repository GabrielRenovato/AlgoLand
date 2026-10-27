extends RefCounted
## Modelagem nativa para o rig canônico. Cabelo acompanha a cabeça;
## saias conservam a meia-calça e recebem pesos leves das duas coxas.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
static func cabelo(base: ArrayMesh,corpo: MeshInstance3D,s: Skeleton3D,forma: int) -> ArrayMesh:
    if forma==0: return base
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.append_from(base,0,Transform3D.IDENTITY)
    st.deindex()
    var rig:=Modelagem.ligacoes(corpo,s)
    var bind: int=rig["DEF-head"]
    var transformacao:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
    if forma in [1,2]:
        var longo:=forma==2
        # Cortina aberta na frente: nuca e laterais sem cobrir os olhos.
        var aneis: Array=[]
        for nivel in 4:
            var anel: Array=[]
            for q in 25:
                var a:=lerpf(.27,-PI-.27,q/24.0)
                # Raios rentes à cabeça (no espaço do osso, que a proporção chibi amplia 2,4x).
                var raio: float=([.110,.128,.120,.096] if longo else [.110,.126,.124,.116])[nivel]
                var y: float=([.205,.10,-.04,-.15] if longo else [.205,.130,.035,-.035])[nivel]
                y+=.008*cos(a*5)*nivel/3.0
                # Pontas em V nas costas: a mecha central desce mais que as laterais.
                if longo and nivel==3: y-=.05*maxf(0.0,-sin(a))
                anel.append(Vector3(cos(a)*raio,y,sin(a)*raio*.92-(.03*nivel/3.0 if longo else .007)))
            aneis.append(anel)
        for n in 3:
            for q in 24:
                _quad_cabelo(st,[aneis[n][q],aneis[n+1][q],aneis[n+1][q+1],aneis[n][q+1]],transformacao,bind)
        for lado in [-1,1]:
            # Mechas finas emoldurando o rosto (antes eram tubos grossos, como fones).
            _mecha(st,[[Vector3(lado*.100,.20,.035),.018,.018],[Vector3(lado*.116,.13,.045),.020,.022],[Vector3(lado*.120,.02 if longo else .05,.040),.015,.016],[Vector3(lado*.114,-.08 if longo else -.01,.028),.006,.008]],transformacao,bind)
    else:
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
static func _cacho(st: SurfaceTool,centro: Vector3,raios: Vector3,t: Transform3D,bind: int):
    var secoes: Array=[]
    for i in 7:
        var a:=PI*i/6.0
        var largura:=maxf(.025,sin(a))
        var deslocamento:=Vector3(sin(a*2)*.008,cos(a)*raios.y,cos(a*2)*.006)
        secoes.append([centro+deslocamento,raios.x*largura,raios.z*largura])
    _mecha(st,secoes,t,bind)
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
