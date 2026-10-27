extends RefCounted
## Roupas com seções próprias, folga e bordas espessas, ligadas ao rig da base.
const MODELAGEM = preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const NOMES := ["Camisa","Calca","Botas","Cabelo"]

static func interpolar(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
    var influencias := {}
    for i in 4:
        influencias[a.b[i]] = influencias.get(a.b[i],0.0)+a.w[i]*(1.0-t)
        influencias[b.b[i]] = influencias.get(b.b[i],0.0)+b.w[i]*t
    var chaves = influencias.keys()
    chaves.sort_custom(func(x,y):return influencias[x]>influencias[y])
    var ossos := PackedInt32Array([0,0,0,0])
    var pesos := PackedFloat32Array([0,0,0,0])
    var soma := 0.0
    for i in mini(4,chaves.size()):
        ossos[i] = chaves[i]
        pesos[i] = influencias[chaves[i]]
        soma += pesos[i]
    if soma > 0.0:
        for i in 4:pesos[i] /= soma
    return {"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"b":ossos,"w":pesos,"f":0.0}

static func recortar(triangulo: Array) -> Array:
    var saida := []
    for i in 3:
        var a: Dictionary = triangulo[i]
        var b: Dictionary = triangulo[(i+1)%3]
        if a.f >= 0.0:saida.append(a)
        if (a.f >= 0.0) != (b.f >= 0.0):
            saida.append(interpolar(a,b,a.f/(a.f-b.f)))
    return saida

static func emitir(st: SurfaceTool,v: Dictionary,espessura: float):
    st.set_normal(v.n)
    st.set_bones(v.b)
    st.set_weights(v.w)
    st.add_vertex(v.p+v.n*espessura)

static func construir(corpo: MeshInstance3D,esqueleto: Skeleton3D) -> Array[MeshInstance3D]:
    var resultado: Array[MeshInstance3D] = []
    var malha: ArrayMesh = corpo.mesh
    var head := esqueleto.find_bone("DEF-head")
    var da_cabeca := corpo.global_transform.affine_inverse()*esqueleto.global_transform*esqueleto.get_bone_global_rest(head)
    var para_cabeca := da_cabeca.affine_inverse()
    var bind_head := -1
    var nomes := []
    var inversas := []
    for b in corpo.skin.get_bind_count():
        var indice := corpo.skin.get_bind_bone(b)
        var nome := String(corpo.skin.get_bind_name(b))
        if not nome.is_empty():indice = esqueleto.find_bone(nome)
        else:nome = esqueleto.get_bone_name(indice)
        nomes.append(nome)
        inversas.append((corpo.global_transform.affine_inverse()*esqueleto.global_transform*esqueleto.get_bone_global_rest(indice)).affine_inverse())
        if indice == head:bind_head = b
    var rig := MODELAGEM.ligacoes(corpo,esqueleto)
    var amostras := []
    for peca in 4:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for s in malha.get_surface_count():
            var a := malha.surface_get_arrays(s)
            var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
            var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
            var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
            var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
            var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
            var vertices := []
            for v in vs.size():
                var ossos := PackedInt32Array()
                var pesos := PackedFloat32Array()
                var maior := 0
                for k in 4:
                    ossos.append(bs[v*4+k])
                    pesos.append(ws[v*4+k])
                    if pesos[k]>pesos[maior]:maior=k
                var bind := ossos[maior]
                var nome: String = nomes[bind]
                var ponto := vs[v]
                var f := -1.0
                match peca:
                    3:
                        if nome == "DEF-head":
                            var local: Vector3 = para_cabeca*ponto
                            var linha := 0.175+0.25*local.x if local.z>0.045 else (0.10 if absf(local.x)>0.055 else 0.055)
                            f = local.y-linha
                vertices.append({"p":ponto,"n":ns[v],"b":ossos,"w":pesos,"f":f})
                if peca == 0:amostras.append({"p":ponto,"n":ns[v],"b":ossos,"w":pesos,"nome":nome})
            var total := indices.size() if not indices.is_empty() else vs.size()
            for t in range(0,total,3):
                var triangulo := []
                for k in 3:triangulo.append(vertices[indices[t+k] if not indices.is_empty() else t+k])
                if peca != 3:continue
                var poligono := recortar(triangulo)
                for k in range(1,poligono.size()-1):
                    var face: Array=[poligono[0],poligono[k],poligono[k+1]]
                    var uvs: Array=[]
                    for v in face: uvs.append(_uv_cabelo(para_cabeca*v.p))
                    var minimo: float=minf(uvs[0].x,minf(uvs[1].x,uvs[2].x))
                    var maximo: float=maxf(uvs[0].x,maxf(uvs[1].x,uvs[2].x))
                    for i in 3:
                        var uv: Vector2=uvs[i]
                        # Não interpola a textura inteira no triângulo da emenda.
                        if maximo-minimo>0.5 and uv.x<0.5: uv.x+=1.0
                        st.set_color(Color.WHITE)
                        st.set_uv(uv)
                        emitir(st,face[i],0.017)
        if peca == 0:MODELAGEM.camisa(st,rig)
        if peca == 1:MODELAGEM.calca(st,rig)
        if peca == 2:botas(st,amostras)
        if peca == 3 and bind_head >= 0:
            _franja_pintada(st,da_cabeca,bind_head)
        if peca in [0,1]:st=MODELAGEM.orientar_costuras(st)
        st.set_smooth_group(0)
        st.generate_normals()
        st.index()
        var nova := MeshInstance3D.new()
        nova.name = NOMES[peca]
        nova.mesh = st.commit()
        nova.skin = corpo.skin
        nova.skeleton = corpo.skeleton
        corpo.get_parent().add_child(nova)
        resultado.append(nova)
    return resultado

## Transfere pesos da superfície próxima para a roupa, sem copiar a sua silhueta.
static func vestir(p: Vector3,amostras: Array,filtro: String = "") -> Dictionary:
    var proximas := []
    for v in amostras:
        if not filtro.is_empty() and not v.nome.begins_with(filtro):continue
        var d: float = p.distance_squared_to(v.p)
        if proximas.size()<3 or d<proximas[-1].d:
            proximas.append({"v":v,"d":d})
            proximas.sort_custom(func(a,b):return a.d<b.d)
            if proximas.size()>3:proximas.pop_back()
    var v: Dictionary = proximas[0].v.duplicate()
    var soma: float = 1.0/maxf(proximas[0].d,0.00001)
    for i in range(1,proximas.size()):
        var peso: float = 1.0/maxf(proximas[i].d,0.00001)
        v = interpolar(v,proximas[i].v,peso/(soma+peso))
        soma += peso
    v.p = p
    return v

## Costura seções desenhadas para a peça. Cada seção tem centro e dois raios;
## a roupa possui espessura nas bordas e não reproduz músculos do manequim.
static func costurar(st: SurfaceTool,secoes: Array,amostras: Array,eixo: int = 1,filtro: String = "",tons: Array = []):
    const LADOS := 16
    var aneis := []
    for s in secoes.size():
        var secao: Array = secoes[s]
        var anel := []
        for q in LADOS:
            var angulo := TAU*q/LADOS
            var deslocamento := Vector3(cos(angulo)*secao[1],0,sin(angulo)*secao[2])
            if eixo == 0:deslocamento = Vector3(0,cos(angulo)*secao[1],sin(angulo)*secao[2])
            var v := vestir(secao[0]+deslocamento,amostras,filtro)
            v.tom = tons[s] if s<tons.size() else 1.0
            anel.append(v)
        aneis.append(anel)
    for s in range(aneis.size()-1):
        for q in LADOS:
            var n := (q+1)%LADOS
            for face in [[aneis[s][q],aneis[s+1][q],aneis[s+1][n]],[aneis[s][q],aneis[s+1][n],aneis[s][n]]]:
                var normal: Vector3 = (face[1].p-face[0].p).cross(face[2].p-face[0].p).normalized()
                # A convenção de faces do Godot é horária. As seções progridem
                # para cima (ou para fora na manga); corrigir o sentido da esquerda.
                if eixo == 0 and secoes[1][0].x>secoes[0][0].x:
                    face.reverse()
                    normal = -normal
                face.reverse() # Faces horárias por fora; normal mantém o sentido externo.
                for v in face:
                    v.n = normal
                    st.set_color(Color(v.tom,v.tom,v.tom))
                    st.set_uv(Vector2(v.p.x,v.p.y))
                    st.set_uv2(Vector2(v.p.z,0))
                    emitir(st,v,0)

static func botas(st: SurfaceTool,amostras: Array):
    for lado in [-1,1]:
        var sufixo: String = ".L" if lado>0 else ".R"
        var amostras_lado: Array = amostras.filter(func(v):return v.nome.ends_with(sufixo))
        var pe: Dictionary = amostras_lado.filter(func(v):return v.nome.begins_with("DEF-foot"))[0]
        var canela: Dictionary = amostras_lado.filter(func(v):return v.nome.begins_with("DEF-shin"))[0]
        for v in [pe,canela]:
            var maior := 0
            for k in 4:
                if v.w[k]>v.w[maior]:maior=k
            v.b = PackedInt32Array([v.b[maior],0,0,0])
            v.w = PackedFloat32Array([1,0,0,0])
        var secoes := []
        for medidas in [[0.008,0.077,0.129,0.036],[0.026,0.081,0.134,0.036],[0.043,0.081,0.134,0.036],[0.083,0.079,0.123,0.033],[0.14,0.074,0.099,0.004],[0.23,0.076,0.089,-0.019],[0.30,0.082,0.095,-0.019],[0.33,0.087,0.101,-0.019],[0.35,0.087,0.101,-0.019],[0.35,0.073,0.087,-0.019],[0.32,0.073,0.087,-0.019]]:
            secoes.append([Vector3(lado*0.089,medidas[0],medidas[3]),medidas[1],medidas[2]])
        # Pé e cano recebem pesos contínuos do mesmo lado. A sola permanece
        # solidária ao pé em vez de esticar entre ossos do tornozelo ou da outra perna.
        var pontos := []
        for secao in secoes:
            for q in 16:
                var p: Vector3 = secao[0]+Vector3(cos(TAU*q/16)*secao[1],0,sin(TAU*q/16)*secao[2])
                var v := interpolar(pe,canela,smoothstep(0.13,0.30,p.y))
                v.p = p
                v.nome = ""
                pontos.append(v)
        costurar(st,secoes,pontos,1,"",[0.55,0.55,0.65,1.05,1.08,1,0.85,1.18,1.18,0.65,0.65])
        costurar(st,[[Vector3(lado*0.089,0.008,0.036),0.001,0.001],secoes[0]],pontos,1,"",[1,1])

## Superfície contínua e franja fina: o desenho dos fios pertence à textura,
## não a tubos e peças geométricas sobre a cabeça.
static func _uv_cabelo(p: Vector3) -> Vector2:
    return Vector2(atan2(p.x,p.z)/TAU+0.5,clampf((0.28-p.y)/0.24,0,1))

static func _franja_pintada(st: SurfaceTool,da_cabeca: Transform3D,osso: int):
    var franjas := [
        [Vector3(0.042,0.274,0.029),Vector3(0.001,0.253,0.109),Vector3(-0.064,0.177,0.139),0.044],
        [Vector3(0.069,0.250,0.047),Vector3(0.048,0.232,0.119),Vector3(0.004,0.182,0.145),0.034],
        [Vector3(-0.047,0.258,0.035),Vector3(-0.077,0.218,0.100),Vector3(-0.077,0.165,0.109),0.024]]
    for franja in franjas:
        var grade: Array=[]
        for linha in 13:
            var t:=linha/12.0
            var a: Vector3=franja[0]
            var b: Vector3=franja[1]
            var c: Vector3=franja[2]
            var centro:=a*(1-t)*(1-t)+b*2*(1-t)*t+c*t*t
            var largura: float=franja[3]*pow(1-t,0.85)+0.0003
            var anel: Array=[]
            for coluna in 9:
                var u:=coluna/4.0-1.0
                var ponto:=centro+Vector3(largura*u,0.002*(1-u*u),0.003*(1-u*u))
                anel.append(ponto)
            grade.append(anel)
        for linha in 12:
            for coluna in 8:
                for face in [[grade[linha][coluna],grade[linha+1][coluna],grade[linha+1][coluna+1]],[grade[linha][coluna],grade[linha+1][coluna+1],grade[linha][coluna+1]]]:
                    face.reverse()
                    for ponto in face:
                        st.set_color(Color.WHITE)
                        st.set_uv(_uv_cabelo(ponto))
                        emitir(st,{"p":da_cabeca*ponto,"n":(da_cabeca.basis*Vector3.BACK).normalized(),"b":PackedInt32Array([osso,0,0,0]),"w":PackedFloat32Array([1,0,0,0]),"f":0.0},0.0)
