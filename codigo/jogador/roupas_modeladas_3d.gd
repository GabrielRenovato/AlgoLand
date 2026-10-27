extends RefCounted
## Moldes próprios de tecido. Não lê vértices, normais ou pesos do corpo.
## Coordenadas em metros no repouso do rig. A camisa possui quatro aberturas;
## a calça, três. Ombros, mangas e entrepernas compartilham suas costuras.
const LADOS := 32

static func ligacoes(corpo: MeshInstance3D,esqueleto: Skeleton3D) -> Dictionary:
    var mapa := {}
    for i in corpo.skin.get_bind_count():
        var nome := String(corpo.skin.get_bind_name(i))
        if nome.is_empty():nome=esqueleto.get_bone_name(corpo.skin.get_bind_bone(i))
        mapa[nome]=i
    return mapa

static func vertice(p: Vector3,pesos: Dictionary,rig: Dictionary,tom: float=1.0) -> Dictionary:
    var b := PackedInt32Array([0,0,0,0])
    var w := PackedFloat32Array([0,0,0,0])
    var i := 0
    for nome in pesos:
        if pesos[nome]<=0.00001:continue
        assert(i<4 and rig.has(nome))
        b[i]=rig[nome]
        w[i]=pesos[nome]
        i+=1
    return {"p":p,"b":b,"w":w,"tom":tom}

static func face(st: SurfaceTool,a: Dictionary,b: Dictionary,c: Dictionary,fora: Vector3):
    var normal: Vector3 = (b.p-a.p).cross(c.p-a.p)
    if normal.length_squared()<0.0000000001:return
    var vertices := [a,b,c]
    if normal.dot(fora)>0.0:vertices.reverse()
    for v in vertices:
        st.set_normal(fora.normalized())
        st.set_bones(v.b)
        st.set_weights(v.w)
        st.set_color(Color(v.tom,v.tom,v.tom))
        st.set_uv(Vector2(v.p.x,v.p.y))
        st.set_uv2(Vector2(v.p.z,0))
        st.add_vertex(v.p)

static func quad(st: SurfaceTool,a: Dictionary,b: Dictionary,c: Dictionary,d: Dictionary,fora: Vector3):
    face(st,a,b,c,fora)
    face(st,a,c,d,fora)

static func unir(st: SurfaceTool,a: Array,b: Array,centro: Vector3,eixo: int=1):
    for q in a.size():
        var n := (q+1)%a.size()
        var fora: Vector3 = (a[q].p+a[n].p+b[q].p+b[n].p)*0.25-centro
        if eixo==1:fora.y=0
        else:fora.x=0
        quad(st,a[q],b[q],b[n],a[n],fora)

static func pesos_tronco(y: float) -> Dictionary:
    if y<1.14:
        var t := smoothstep(1.015,1.14,y)
        return {"DEF-hips":1.0-t,"DEF-spine.001":t}
    if y<1.27:
        var t := smoothstep(1.14,1.27,y)
        return {"DEF-spine.001":1.0-t,"DEF-spine.002":t}
    var t := smoothstep(1.27,1.40,y)
    return {"DEF-spine.002":1.0-t,"DEF-spine.003":t}

static func camisa(st: SurfaceTool,rig: Dictionary):
    # Barra solta, cintura sem estreitamento anatômico e peito de tecido contínuo.
    var medidas := [[0.955,0.245,0.185],[0.974,0.246,0.186],[1.025,0.240,0.180],
        [1.115,0.233,0.173],[1.225,0.243,0.177],[1.315,0.248,0.169],
        [1.405,0.247,0.157],[1.480,0.234,0.136],
        [1.516,0.083,0.054],[1.531,0.083,0.054],[1.531,0.073,0.044],[1.500,0.073,0.044]]
    var aneis := []
    for linha in medidas.size():
        var m: Array=medidas[linha]
        var anel := []
        for q in LADOS:
            var angulo := TAU*q/LADOS
            var y: float=m[0]
            # Ombro levemente erguido; 0.050 formava corcunda na altura do queixo e escondia o pescoço.
            if linha==7:y+=0.018*pow(absf(cos(angulo)),3.0)
            # Dobras pequenas da barra; não há relevo de peito, abdômen ou quadril.
            var dobra := 0.003*sin(angulo*5.0)*maxf(0.0,1.0-absf(y-1.01)/0.13)
            var centro_z := 0.014 if linha>=8 else -0.012
            var p := Vector3(cos(angulo)*(m[1]+dobra),y,centro_z+sin(angulo)*(m[2]+dobra))
            var pesos := {"DEF-neck":1.0} if linha>=8 else pesos_tronco(y)
            if linha>=5 and linha<=7:
                var angular := smoothstep(0.60,0.90,absf(cos(angulo)))
                var altura := (linha-5)/2.0
                var ombro := angular*altura*0.55
                var braco := angular*(1.0-altura)*0.35
                var sufixo := ".L" if p.x>0 else ".R"
                for nome in pesos:pesos[nome]*=1.0-ombro-braco
                pesos["DEF-shoulder"+sufixo]=ombro
                pesos["DEF-upper_arm"+sufixo]=braco
            var tom := 0.88 if linha<2 else (0.70 if linha>=8 else 1.0)
            anel.append(vertice(p,pesos,rig,tom))
        aneis.append(anel)
    for linha in range(aneis.size()-1):
        for q in LADOS:
            # Abertura real das cavas: as mangas serão costuradas nestas bordas.
            if linha in [5,6] and (q>=28 or q<4 or (q>=12 and q<20)):continue
            var n := (q+1)%LADOS
            var fora: Vector3=(aneis[linha][q].p+aneis[linha+1][n].p)*0.5-Vector3(0,0,-0.012)
            fora.y=0
            if linha in [7,9]:fora=Vector3.UP
            elif linha>9:fora=-fora
            quad(st,aneis[linha][q],aneis[linha+1][q],aneis[linha+1][n],aneis[linha][n],fora)
    for lado in [-1,1]:
        var inicio := 28 if lado>0 else 12
        var cava := []
        for q in range(9):cava.append(aneis[5][(inicio+q)%LADOS])
        for linha in [6,7]:cava.append(aneis[linha][(inicio+8)%LADOS])
        for q in range(7,-1,-1):cava.append(aneis[7][(inicio+q)%LADOS])
        cava.append(aneis[6][inicio])
        var anterior: Array=cava
        var osso := "DEF-upper_arm.L" if lado>0 else "DEF-upper_arm.R"
        var centro := Vector3(lado*0.22,1.435,-0.012)
        for etapa in [[0.285,0.135,0.130,1.0],[0.335,0.133,0.128,1.0],[0.402,0.122,0.117,1.0],
            [0.427,0.121,0.116,0.78],[0.427,0.111,0.106,0.72],[0.404,0.111,0.106,0.72]]:
            var anel := []
            for v in cava:
                var angulo := atan2(v.p.z-centro.z,v.p.y-centro.y)
                var p := Vector3(lado*etapa[0],1.435+cos(angulo)*etapa[1],-0.012+sin(angulo)*etapa[2])
                var participacao := 0.45 if etapa[0]<0.30 else 0.0
                anel.append(vertice(p,{osso:1.0-participacao,"DEF-shoulder.L" if lado>0 else "DEF-shoulder.R":participacao},rig,etapa[3]))
            unir(st,anterior,anel,Vector3(lado*0.35,1.435,-0.012),0)
            anterior=anel
    # Dobra para dentro da barra, com espessura e abertura de verdade.
    var interno := []
    for v in aneis[0]:
        var p: Vector3=v.p
        p.x*=0.95
        p.z=-0.012+(p.z+0.012)*0.94
        interno.append(vertice(p,pesos_tronco(p.y),rig,0.83))
    for q in LADOS:
        var n := (q+1)%LADOS
        quad(st,aneis[0][q],aneis[0][n],interno[n],interno[q],Vector3.DOWN)
    var cima := []
    for v in interno:
        cima.append(vertice(v.p+Vector3(0,0.024,0),pesos_tronco(v.p.y+0.012),rig,0.83))
    unir(st,interno,cima,Vector3(0,0,-0.012))

static func pesos_perna(y: float,lado: int) -> Dictionary:
    var sufixo := ".L" if lado>0 else ".R"
    if y>0.72:
        var t := smoothstep(0.72,0.99,y)
        return {"DEF-thigh"+sufixo:1.0-t,"DEF-hips":t}
    var t := smoothstep(0.43,0.61,y)
    return {"DEF-shin"+sufixo:1.0-t,"DEF-thigh"+sufixo:t}

static func calca(st: SurfaceTool,rig: Dictionary):
    const N := 24
    # A calça nasce de duas pernas e uma costura de gancho, sem recortes do corpo.
    var cintura := []
    for lado in [-1,1]:
        var aneis := []
        var medidas := [[0.255,0.079,0.104],[0.280,0.086,0.111],[0.370,0.092,0.124],
            [0.470,0.100,0.132],[0.560,0.103,0.136],[0.670,0.108,0.142]]
        for m in medidas:
            var anel := []
            for q in N:
                var angulo := TAU*q/N
                var p := Vector3(lado*(0.112+cos(angulo)*m[1]),m[0],-0.016+sin(angulo)*m[2])
                anel.append(vertice(p,pesos_perna(p.y,lado),rig,0.93 if m[0]<0.29 else 1.0))
            aneis.append(anel)
        var topo := []
        for q in N:
            var angulo := TAU*q/N
            var exterior := cos(angulo)>=-0.0001
            var p := Vector3(lado*maxf(0,cos(angulo))*0.165,1.024,0.015+sin(angulo)*0.128)
            if not exterior:p.y-=0.252*pow(-cos(angulo),1.3)
            topo.append(vertice(p,{"DEF-hips":1.0},rig))
            if exterior:cintura.append({"v":topo[-1],"angulo":atan2(p.z-0.015,p.x)})
        var transicao := []
        for q in N:
            var p: Vector3=aneis[-1][q].p.lerp(topo[q].p,0.52)
            var y_peso: float=p.y if absf(p.x)>0.035 else lerpf(p.y,0.99,0.70)
            transicao.append(vertice(p,pesos_perna(y_peso,lado),rig))
        aneis.append(transicao)
        aneis.append(topo)
        for linha in range(aneis.size()-1):unir(st,aneis[linha],aneis[linha+1],Vector3(lado*0.112,0,-0.016))
        # Avesso do tornozelo.
        var interno := []
        var retorno := []
        for v in aneis[0]:
            var p: Vector3=v.p
            p.x=lado*0.112+(p.x-lado*0.112)*0.87
            p.z=-0.016+(p.z+0.016)*0.90
            interno.append(vertice(p,pesos_perna(p.y,lado),rig,0.85))
            retorno.append(vertice(p+Vector3(0,0.022,0),pesos_perna(p.y+0.022,lado),rig,0.85))
        for q in N:
            var n := (q+1)%N
            quad(st,aneis[0][q],aneis[0][n],interno[n],interno[q],Vector3.DOWN)
        unir(st,interno,retorno,Vector3(lado*0.112,0,-0.016))
    # Cós contínuo: remove apenas os duplicados da costura frontal/traseira.
    cintura.sort_custom(func(a,b):return a.angulo<b.angulo)
    var base := []
    for item in cintura:
        if base.is_empty() or base[-1].p.distance_to(item.v.p)>0.00001:base.append(item.v)
    if base[0].p.distance_to(base[-1].p)<0.00001:base.pop_back()
    var anterior: Array=base
    for nivel in [[1.044,1.012,0.96],[1.044,0.965,0.96],[1.014,0.965,0.93]]:
        var anel := []
        for v in base:
            var p:=Vector3(v.p.x*nivel[1],nivel[0],0.015+(v.p.z-0.015)*nivel[1])
            anel.append(vertice(p,{"DEF-hips":1.0},rig,nivel[2]))
        unir(st,anterior,anel,Vector3(0,0,-0.016))
        anterior=anel

## Mantém o lado externo contínuo nas costuras, inclusive gola, punhos e avessos.
## A primeira face de cada peça aponta para fora; as adjacentes herdam a orientação.
static func orientar_costuras(st: SurfaceTool) -> SurfaceTool:
    st.index()
    var malha := st.commit()
    var a: Array=malha.surface_get_arrays(0)
    var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
    var pontos := {}
    var ids := []
    for p in vs:
        var chave := Vector3i((p*100000.0).round())
        if not pontos.has(chave):pontos[chave]=pontos.size()
        ids.append(pontos[chave])
    var arestas := {}
    var vizinhos := []
    var total := indices.size()/3
    for t in total:vizinhos.append([])
    for t in total:
        for k in 3:
            var i: int=ids[indices[t*3+k]]
            var j: int=ids[indices[t*3+(k+1)%3]]
            var chave := Vector2i(mini(i,j),maxi(i,j))
            var sentido := 1 if i<j else -1
            if arestas.has(chave):
                var anterior: Dictionary=arestas[chave]
                var inverter: bool=anterior.sentido==sentido
                vizinhos[t].append({"t":anterior.t,"inverter":inverter})
                vizinhos[anterior.t].append({"t":t,"inverter":inverter})
            else:arestas[chave]={"t":t,"sentido":sentido}
    var inversoes := {}
    for raiz in total:
        if inversoes.has(raiz):continue
        inversoes[raiz]=false
        var fila := [raiz]
        while not fila.is_empty():
            var t: int=fila.pop_back()
            for vizinho in vizinhos[t]:
                if inversoes.has(vizinho.t):continue
                inversoes[vizinho.t]=bool(inversoes[t])!=bool(vizinho.inverter)
                fila.append(vizinho.t)
    for t in total:
        if not inversoes[t]:continue
        var temporario: int=indices[t*3+1]
        indices[t*3+1]=indices[t*3+2]
        indices[t*3+2]=temporario
    a[Mesh.ARRAY_INDEX]=indices
    var nova := ArrayMesh.new()
    nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
    var resultado := SurfaceTool.new()
    resultado.create_from(nova,0)
    return resultado
