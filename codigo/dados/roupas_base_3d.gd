extends RefCounted
## IDs permanentes; opções novas são acrescentadas sem renomear as existentes.
const CATEGORIAS := ["camisa","calca","calcado","cabelo"]
const MODELOS := {
    "camisa":[
        {"id":"camisa_bosque","nome":"Camisa do bosque","cor":"4a6b88","forma":0,"estilo":0},
        {"id":"camisa_trabalho","nome":"Camisa de trabalho","cor":"c9b58e","forma":1,"estilo":1},
        {"id":"tunica_campo","nome":"Túnica do campo","cor":"64734e","forma":2,"estilo":2},
        {"id":"jaqueta_viajante","nome":"Jaqueta de viagem","cor":"985563","forma":3,"estilo":3},
        {"id":"blusa_bufante","nome":"Blusa de mangas bufantes","cor":"c27b70","forma":4,"estilo":4},
        {"id":"casaquinho_lavanda","nome":"Casaquinho rosa antigo","cor":"987588","forma":5,"estilo":5}],
    "calca":[
        {"id":"calca_sarja","nome":"Calça de sarja","cor":"846047","forma":0,"estilo":0},
        {"id":"calca_cargo","nome":"Calça cargo","cor":"69705b","forma":1,"estilo":1},
        {"id":"calca_pescador","nome":"Calça de pescador","cor":"526074","forma":2,"estilo":2},
        {"id":"saia_pregas","nome":"Saia de pregas com meia-calça","cor":"526074","forma":3,"estilo":3},
        {"id":"saia_campo","nome":"Saia do campo com meia-calça","cor":"69705b","forma":4,"estilo":4}],
    "calcado":[
        {"id":"botas_couro","nome":"Botas de couro","cor":"633f3b","forma":0,"estilo":0,"altura":0.30},
        {"id":"botinas_trabalho","nome":"Botinas de trabalho","cor":"8c5a3c","forma":1,"estilo":1,"altura":0.22},
        {"id":"sapatos_viagem","nome":"Sapatos de viagem","cor":"443642","forma":2,"estilo":2,"altura":0.14},
        {"id":"sapatilhas_vinho","nome":"Sapatilhas vinho","cor":"985563","forma":3,"estilo":3,"altura":0.12}],
    "cabelo":[
        # cabelo_curto = penteado masculino original (pintado); o chanel ganhou id próprio.
        {"id":"cabelo_curto","nome":"Bagunçado","forma":0},
        {"id":"cabelo_raspado","nome":"Raspado","forma":4},
        {"id":"cabelo_espetado","nome":"Espetado","forma":5},
        {"id":"cabelo_chanel","nome":"Chanel","forma":1},
        {"id":"cabelo_longo","nome":"Longo","forma":2},
        {"id":"cabelo_cacheado","nome":"Cacheado","forma":3}]
}
static func padrao() -> Dictionary:
    return {"camisa":"camisa_bosque","calca":"calca_sarja","calcado":"botas_couro","cabelo":"cabelo_curto"}
static func modelo(categoria: String,id: String) -> Dictionary:
    if categoria=="cabelo":
        id={"cabelo_rabo":"cabelo_longo","cabelo_trancas":"cabelo_cacheado"}.get(id,id)
    for item in MODELOS[categoria]:
        if item.id==id: return item
    return MODELOS[categoria][0]
static func normalizar(dados: Dictionary) -> Dictionary:
    var resultado:=padrao()
    for categoria in CATEGORIAS:
        resultado[categoria]=modelo(categoria,str(dados.get(categoria,resultado[categoria]))).id
    return resultado

## Deriva os moldes aceitos, preservando os mesmos pesos e encaixes do rig.
static func malha(base: ArrayMesh,categoria: String,forma: int) -> ArrayMesh:
    if forma==0: return base
    var nova:=ArrayMesh.new()
    for superficie in base.get_surface_count():
        var a:=base.surface_get_arrays(superficie)
        var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
        for i in vs.size():
            var p:=vs[i]
            if categoria=="camisa":
                if forma==1:
                    # Manga um pouco mais larga, corpo com folga de camisa de trabalho.
                    p.z*=1.035
                    if absf(p.x)>.26: p.y=1.435+(p.y-1.435)*1.08
                elif forma==2:
                    var barra:=1.0-smoothstep(.97,1.19,p.y)
                    p.y-=.07*barra
                    p.x*=1.0+.035*barra
                elif forma==4:
                    if absf(p.x)>.26:
                        p.y=1.435+(p.y-1.435)*1.22
                        p.z=-.012+(p.z+.012)*1.15
                    else:
                        p.x*=1.0-.035*smoothstep(.97,1.15,p.y)
                elif forma==5:
                    if absf(p.x)>.26:
                        p.x=signf(p.x)*(.26+(absf(p.x)-.26)*1.32)
                    else:
                        p.z*=1.06
                else:
                    p.z*=1.07
                    p.x*=1.025
            elif categoria=="calca":
                if forma==1:
                    var lado:=1.0 if p.x>=0 else -1.0
                    p.x=lado*.112+(p.x-lado*.112)*1.10
                    p.z=-.016+(p.z+.016)*1.06
                else:
                    p.y+=.055*(1.0-smoothstep(.28,.48,p.y))
            else:
                if p.y>.14: p.y=.14+(p.y-.14)*(.64 if forma==1 else .25)
                p.z*=1.06 if forma==1 else 1.0
            vs[i]=p
            # UV permanece no molde canônico: costuras escalam junto à peça.
        a[Mesh.ARRAY_VERTEX]=vs
        nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
    var st:=SurfaceTool.new()
    st.create_from(nova,0)
    st.generate_normals()
    return st.commit()
