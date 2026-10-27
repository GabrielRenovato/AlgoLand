extends Node3D
## Arco cosmético; o controlador original decide quando criar o projétil e o dano.
var heroi: Node
var _aljava: Node3D
var _madeira: Node3D
var _corda: MeshInstance3D
var _flecha: Node3D
var origem_visual := Vector2.ZERO
func _ready():
    _aljava=Node3D.new()
    heroi._costas.add_child(_aljava)
    _aljava.position=Vector3(-.20,.04,-.20)
    _aljava.rotation_degrees.z=18
    _tubo(_aljava,Vector3(0,-.22,0),Vector3(0,.18,0),.085,Color("61413b"))
    _tubo(_aljava,Vector3(0,.181,0),Vector3(0,.19,0),.07,Color("302b38"))
    for i in 3:
        var x: float=(i-1)*.035
        _tubo(_aljava,Vector3(x,.10,.015),Vector3(x,.44,.015),.008,Color("c09c67"))
        _tubo(_aljava,Vector3(x-.025,.38,.015),Vector3(x+.025,.42,.015),.014,Color("e6d5b8"))
    _madeira=Node3D.new()
    add_child(_madeira)
    for i in 12:
        var y0: float=-.48+i*.08
        var y1: float=y0+.08
        _tubo(_madeira,Vector3(0,y0,-.15*pow(absf(y0)/.48,2)),Vector3(0,y1,-.15*pow(absf(y1)/.48,2)),.018,Color("8c5a3c"))
    _tubo(_madeira,Vector3(0,-.09,0),Vector3(0,.09,0),.026,Color("61413b"))
    _corda=MeshInstance3D.new()
    _corda.mesh=ImmediateMesh.new()
    var material:=StandardMaterial3D.new()
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color=Color("e6d5b8")
    _corda.material_override=material
    add_child(_corda)
    _flecha=Node3D.new()
    add_child(_flecha)
    _tubo(_flecha,Vector3.ZERO,Vector3(0,0,.65),.008,Color("c09c67"))
    _tubo(_flecha,Vector3(0,0,.65),Vector3(0,0,.74),.018,Color("a6c6c0"))
    visible=false
func atualizar(s: Skeleton3D):
    _aljava.visible=heroi._jogador.usando_arco
    visible=heroi._jogador.usando_arco and heroi._acao in ["parado","correr","arco"]
    if not visible:return
    var base: Transform3D=heroi._modelo.global_transform.affine_inverse()*s.global_transform
    var esquerda: Transform3D=base*s.get_bone_global_pose(s.find_bone("DEF-hand.L"))
    var direita: Transform3D=base*s.get_bone_global_pose(s.find_bone("DEF-hand.R"))
    var pega: Vector3=esquerda*Vector3(0,.08,0)
    var mao: Vector3=direita*Vector3(0,.08,0)
    _madeira.position=pega
    var preparando: bool=heroi._acao=="arco" and heroi.progresso_arco()<.40
    var soltou: bool=heroi._jogador.no_arco._indice>=heroi._jogador.no_arco.QUADRO_SOLTAR
    var meio:=pega+Vector3(0,0,-.15)
    if heroi._acao=="arco" and not preparando and not soltou: meio=mao
    var malha: ImmediateMesh=_corda.mesh
    malha.clear_surfaces()
    malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
    malha.surface_add_vertex(pega+Vector3(0,-.48,-.15))
    malha.surface_add_vertex(meio)
    malha.surface_add_vertex(pega+Vector3(0,.48,-.15))
    malha.surface_end()
    _flecha.visible=heroi._acao=="arco" and not soltou
    _flecha.position=mao
    _flecha.basis=Basis.IDENTITY
    if preparando:
        var eixo: Vector3=direita.basis.orthonormalized().x
        var lateral:=Vector3.UP.cross(eixo).normalized()
        if lateral.length()<.1:lateral=Vector3.RIGHT
        _flecha.basis=Basis(lateral,eixo.cross(lateral),eixo)
    if _flecha.visible:
        var ponta: Vector3=_flecha.to_global(Vector3(0,0,.37))
        origem_visual=heroi._sprite.to_global(heroi._camera.unproject_position(ponta)+heroi._sprite.offset)
func _tubo(pai: Node3D,inicio: Vector3,fim: Vector3,raio: float,cor: Color):
    var cilindro:=CylinderMesh.new()
    cilindro.top_radius=raio
    cilindro.bottom_radius=raio
    cilindro.height=inicio.distance_to(fim)
    cilindro.radial_segments=8
    var m:=StandardMaterial3D.new()
    m.albedo_color=cor
    m.roughness=.9
    var no:=MeshInstance3D.new()
    no.mesh=cilindro
    no.material_override=m
    var eixo: Vector3=(fim-inicio).normalized()
    var x:=Vector3.RIGHT
    if absf(eixo.dot(x))>.95:x=Vector3.FORWARD
    x=(x-eixo*x.dot(eixo)).normalized()
    no.transform=Transform3D(Basis(x,eixo,x.cross(eixo)),(inicio+fim)*.5)
    pai.add_child(no)
