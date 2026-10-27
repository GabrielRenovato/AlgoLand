extends RefCounted
## Escudo redondo: aro de couro, face de tábuas e ferragem discreta.
const RAIO := 0.32
static func material(cor: Color) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=cor
    m.roughness=0.95
    return m
static func disco(pai: Node3D,raio: float,altura: float,cor: Color) -> MeshInstance3D:
    var no:=MeshInstance3D.new()
    var forma:=CylinderMesh.new()
    forma.top_radius=raio
    forma.bottom_radius=raio
    forma.height=altura
    forma.radial_segments=48
    no.mesh=forma
    no.rotation_degrees.x=90
    no.material_override=material(cor)
    pai.add_child(no)
    return no
static func construir() -> Node3D:
    var escudo:=Node3D.new()
    escudo.name="EscudoMadeira"
    disco(escudo,RAIO,0.075,Color("61413b"))
    var madeira:=disco(escudo,RAIO-0.025,0.088,Color.WHITE)
    var m:=ShaderMaterial.new()
    m.shader=load("res://codigo/jogador/escudo_madeira_3d.gdshader")
    madeira.material_override=m
    disco(escudo,0.045,0.11,Color("79879a"))
    for lado in [-1.0,1.0]:
        for i in 8:
            var rebite:=MeshInstance3D.new()
            var esfera:=SphereMesh.new()
            esfera.radius=0.011
            esfera.height=0.022
            esfera.radial_segments=8
            esfera.rings=4
            rebite.mesh=esfera
            rebite.position=Vector3(cos(i*TAU/8)*0.305,sin(i*TAU/8)*0.305,lado*0.038)
            rebite.material_override=material(Color("c09c67"))
            escudo.add_child(rebite)
    return escudo
