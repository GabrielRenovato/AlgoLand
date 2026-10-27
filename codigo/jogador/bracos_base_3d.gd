extends RefCounted
## Reconstrói o trecho entre manga e punho. Remove os encaixes do manequim;
## mantém o resto do corpo, as mãos e o rig. Perfis em metros no repouso do GLB.
const INICIO := 0.265
const FIM := 0.751
const SECOES := [
    [0.255,0.087,0.081],[0.275,0.087,0.081],[0.305,0.086,0.080],
    [0.340,0.083,0.078],[0.375,0.079,0.075],[0.410,0.074,0.071],
    [0.435,0.071,0.068],[0.450,0.070,0.067],[0.4663,0.069,0.066],
    [0.482,0.070,0.067],[0.500,0.072,0.069],[0.525,0.073,0.069],
    [0.555,0.071,0.067],[0.590,0.066,0.061],[0.625,0.060,0.055],
    [0.660,0.053,0.049],[0.695,0.047,0.043],[0.720,0.043,0.039],
    [0.740,0.040,0.036],[0.759,0.039,0.035]]

static func interpolar(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
    var v := preload("res://codigo/jogador/roupas_base_3d.gd").interpolar(a,b,t)
    v.c=a.c.lerp(b.c,t)
    v.uv2=a.uv2.lerp(b.uv2,t)
    return v

static func recortar(vertices: Array,limite: float,menor: bool) -> Array:
    var saida := []
    for i in vertices.size():
        var a: Dictionary=vertices[i]
        var b: Dictionary=vertices[(i+1)%vertices.size()]
        var fa: float=(limite-absf(a.p.x)) if menor else (absf(a.p.x)-limite)
        var fb: float=(limite-absf(b.p.x)) if menor else (absf(b.p.x)-limite)
        if fa>=0:saida.append(a)
        if (fa>=0)!=(fb>=0):saida.append(interpolar(a,b,fa/(fa-fb)))
    return saida

static func emitir(st: SurfaceTool,v: Dictionary):
    st.set_color(v.c)
    st.set_uv2(v.uv2)
    st.set_normal(v.n)
    st.set_bones(v.b)
    st.set_weights(v.w)
    st.add_vertex(v.p)

static func poligono(st: SurfaceTool,vertices: Array):
    for k in range(1,vertices.size()-1):
        for v in [vertices[0],vertices[k],vertices[k+1]]:emitir(st,v)

static func construir(corpo: MeshInstance3D,esqueleto: Skeleton3D):
    var rig := preload("res://codigo/jogador/roupas_modeladas_3d.gd").ligacoes(corpo,esqueleto)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for s in corpo.mesh.get_surface_count():
        var a: Array=corpo.mesh.surface_get_arrays(s)
        var vertices := []
        for v in a[Mesh.ARRAY_VERTEX].size():
            var b := PackedInt32Array()
            var w := PackedFloat32Array()
            for k in 4:
                b.append(a[Mesh.ARRAY_BONES][v*4+k])
                w.append(a[Mesh.ARRAY_WEIGHTS][v*4+k])
            vertices.append({"p":a[Mesh.ARRAY_VERTEX][v],"n":a[Mesh.ARRAY_NORMAL][v],"b":b,"w":w,"c":a[Mesh.ARRAY_COLOR][v],"uv2":a[Mesh.ARRAY_TEX_UV2][v]})
        var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
        for t in range(0,indices.size(),3):
            var triangulo := [vertices[indices[t]],vertices[indices[t+1]],vertices[indices[t+2]]]
            var centro: Vector3=(triangulo[0].p+triangulo[1].p+triangulo[2].p)/3.0
            if centro.y<1.20 or centro.y>1.67 or absf(centro.z+0.067)>0.23:
                poligono(st,triangulo)
                continue
            # São preservados ombro e mão; os dois trechos novos entram por dentro
            # deles para não produzir uma borda aberta junto da manga ou do punho.
            poligono(st,recortar(triangulo,INICIO,true))
            poligono(st,recortar(triangulo,FIM,false))
    for lado in [-1,1]:
        var sufixo := ".L" if lado>0 else ".R"
        var aneis := []
        for secao in SECOES:
            var x: float=secao[0]
            var z := lerpf(-0.0654,-0.0701,clampf((x-0.1919)/0.2744,0,1)) if x<0.4663 else lerpf(-0.0701,-0.0654,clampf((x-0.4663)/0.2726,0,1))
            var cotovelo := smoothstep(0.419,0.513,x)
            var mao := smoothstep(0.705,0.751,x)
            var pesos := {"DEF-upper_arm"+sufixo:(1.0-cotovelo)*(1.0-mao),"DEF-forearm"+sufixo:cotovelo*(1.0-mao),"DEF-hand"+sufixo:mao}
            var anel := []
            for q in 32:
                var angulo := TAU*q/32.0
                var p := Vector3(lado*x,1.4408+cos(angulo)*secao[1],z+sin(angulo)*secao[2])
                var v := preload("res://codigo/jogador/roupas_modeladas_3d.gd").vertice(p,pesos,rig)
                v.n=Vector3(0,cos(angulo)/secao[1],sin(angulo)/secao[2]).normalized()
                v.c=Color.BLACK
                # A borda da manga continua ocultando a parte coberta do braço.
                v.uv2=Vector2(0.427-x,2.0)
                anel.append(v)
            aneis.append(anel)
        for linha in range(aneis.size()-1):
            for q in 32:
                var n := (q+1)%32
                for face in [[aneis[linha][q],aneis[linha+1][q],aneis[linha+1][n]],[aneis[linha][q],aneis[linha+1][n],aneis[linha][n]]]:
                    var normal: Vector3=(face[1].p-face[0].p).cross(face[2].p-face[0].p)
                    var fora: Vector3=face[0].n+face[1].n+face[2].n
                    if normal.dot(fora)>0:face.reverse()
                    for v in face:emitir(st,v)
    st.index()
    corpo.mesh=st.commit()
