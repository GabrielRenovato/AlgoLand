extends Node3D
## Ferramentas visuais. Energia, sementes, água e recursos pertencem ao Plantio.
var _regador: Node3D
var _machado: Node3D
var _enxada: Node3D
var _picareta: Node3D
var _vara: Node3D
const PONTA_VARA := Vector3(0,1.35,0)
var _sementes: Node3D
var _gotas: Array[MeshInstance3D]=[]
var _graos: Array[MeshInstance3D]=[]
func _init():
    name="FerramentasFazenda"
    _regador=Node3D.new()
    add_child(_regador)
    _cilindro(_regador,0.13,0.20,Vector3.ZERO,Color("4b7696"))
    _cilindro(_regador,0.14,0.025,Vector3(0,0.105,0),Color("a6c6c0"))
    _tubo(_regador,Vector3(0,-0.025,0.09),Vector3(0,-0.005,0.35),0.025,Color("a6c6c0"))
    _tubo(_regador,Vector3(-0.095,0.08,0),Vector3(-0.095,0.21,0),0.018,Color("e6d5b8"))
    _tubo(_regador,Vector3(-0.095,0.21,0),Vector3(0.095,0.21,0),0.018,Color("e6d5b8"))
    _tubo(_regador,Vector3(0.095,0.21,0),Vector3(0.095,0.08,0),0.018,Color("e6d5b8"))
    _machado=Node3D.new()
    add_child(_machado)
    _caixa(_machado,Vector3(0.04,0.57,0.04),Vector3(0,0.245,0),Color("8c5a3c"))
    _caixa(_machado,Vector3(0.23,0.14,0.055),Vector3(0.075,0.48,0),Color("a6c6c0"))
    _caixa(_machado,Vector3(0.035,0.16,0.065),Vector3(0.19,0.48,0),Color("e6d5b8"))
    _picareta=Node3D.new()
    add_child(_picareta)
    _caixa(_picareta,Vector3(.04,.90,.04),Vector3(0,.25,0),Color("8c5a3c"))
    _tubo(_picareta,Vector3(-.25,.61,0),Vector3(0,.70,0),.035,Color("a6c6c0"))
    _tubo(_picareta,Vector3(0,.70,0),Vector3(.25,.61,0),.035,Color("a6c6c0"))
    _enxada=Node3D.new()
    add_child(_enxada)
    _caixa(_enxada,Vector3(.04,.90,.04),Vector3(0,.25,0),Color("8c5a3c"))
    # A lâmina fica perpendicular ao cabo e desce pelo eixo X do encaixe.
    _caixa(_enxada,Vector3(.22,.035,.24),Vector3(.10,.70,0),Color("718b96"))
    _caixa(_enxada,Vector3(.025,.045,.25),Vector3(.21,.70,0),Color("d2ddd5"))
    _vara=Node3D.new()
    add_child(_vara)
    _cilindro(_vara,.025,.26,Vector3(0,.02,0),Color("61413b"))
    _tubo(_vara,Vector3(0,.15,0),PONTA_VARA,.012,Color("c09c67"))
    _cilindro(_vara,.05,.045,Vector3(.04,.06,0),Color("718b96"))
    _sementes=Node3D.new()
    add_child(_sementes)
    var saco:=MeshInstance3D.new()
    var esfera:=SphereMesh.new()
    esfera.radius=0.085
    esfera.height=0.19
    esfera.radial_segments=10
    esfera.rings=5
    saco.mesh=esfera
    saco.material_override=_material(Color("c09c67"))
    _sementes.add_child(saco)
    _cilindro(_sementes,0.045,0.035,Vector3(0,0.08,0),Color("61413b"))
    for i in 3:
        var grao:=MeshInstance3D.new()
        var forma:=BoxMesh.new()
        forma.size=Vector3(0.025,0.025,0.025)
        grao.mesh=forma
        grao.material_override=_material(Color("ffe5b9"))
        grao.visible=false
        add_child(grao)
        _graos.append(grao)
    for i in 12:
        var gota:=MeshInstance3D.new()
        var bolinha:=SphereMesh.new()
        bolinha.radius=0.019
        bolinha.height=0.038
        bolinha.radial_segments=6
        bolinha.rings=3
        gota.mesh=bolinha
        gota.material_override=_material(Color("71a2b2"))
        add_child(gota)
        _gotas.append(gota)
    visible=false
func atualizar(s: Skeleton3D,heroi: Node):
    var acao: String=heroi._acao.trim_prefix("fazenda_") if heroi._acao.begins_with("fazenda_") else ""
    var pescando: bool=heroi._acao=="pesca"
    visible=pescando or acao in ["regar","encher","machado","plantar","picareta","enxada"]
    if not visible: return
    _regador.visible=acao in ["regar","encher"]
    _machado.visible=acao=="machado"
    _sementes.visible=acao=="plantar"
    _picareta.visible=acao=="picareta"
    _enxada.visible=acao=="enxada"
    _vara.visible=pescando
    var base: Transform3D=heroi._modelo.global_transform.affine_inverse()*s.global_transform
    var direita: Transform3D=base*s.get_bone_global_pose(s.find_bone("DEF-hand.R"))
    var esquerda: Transform3D=base*s.get_bone_global_pose(s.find_bone("DEF-hand.L"))
    var pega:=direita*Vector3(0,0.08,0)
    if _picareta.visible or _enxada.visible or _vara.visible:
        var slot: Basis=direita.basis.orthonormalized()*heroi._pega_kaykit.basis
        if pescando and heroi._player.assigned_animation.begins_with("mixamo/"):
            var animacao: Animation=heroi._player.get_animation(heroi._player.assigned_animation)
            slot=direita.basis.orthonormalized()*Basis(animacao.get_meta("rotacao_arma",Quaternion.IDENTITY))
        # Mantém os eixos animados do encaixe original do KayKit.
        var orientacao:=slot
        var objeto: Node3D=_vara if pescando else (_enxada if _enxada.visible else _picareta)
        objeto.transform=Transform3D(orientacao,pega)
    if _machado.visible:
        var animacao: Animation=heroi._player.get_animation(heroi._player.assigned_animation)
        var rotacao: Basis=direita.basis.orthonormalized()*Basis(animacao.get_meta("rotacao_arma",Quaternion.IDENTITY))
        _machado.transform=Transform3D(rotacao,pega)
    if _sementes.visible:
        _sementes.transform=Transform3D(Basis.IDENTITY,esquerda*Vector3(0,0.04,0)+Vector3(0,-0.08,0))
    for i in _graos.size():
        var grao:=_graos[i]
        var t: float=(heroi.progresso_acao_fazenda()-0.50-i*0.025)/0.24 if acao=="plantar" else -1.0
        grao.visible=t>=0.0 and t<1.0
        if grao.visible:
            var inicio: Vector3=direita*Vector3(0,0.08,0)
            grao.position=inicio.lerp(heroi.destino_ferramenta_3d(),t)+Vector3((i-1)*0.025,sin(t*PI)*0.07,0)
    var despejando: bool=acao=="regar" and heroi._jogador.no_fazenda._impacto_emitido
    if _regador.visible:
        var inclinacao:=deg_to_rad(28.0) if despejando else 0.0
        var orientacao:=Basis(Vector3.RIGHT,inclinacao)
        _regador.transform=Transform3D(orientacao,pega-orientacao*Vector3(0,0.21,0))
    var origem:=_regador.transform*Vector3(0,-0.005,0.36)
    var destino: Vector3=heroi.destino_ferramenta_3d()+Vector3(0,0.02,0)
    for i in _gotas.size():
        var gota:=_gotas[i]
        gota.visible=despejando
        if not despejando: continue
        var t:=fposmod(heroi._tempo*2.2+i/12.0,1.0)
        gota.position=origem.lerp(destino,t)
        gota.position.y+=sin(t*PI)*0.12
func _material(cor: Color) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=cor
    m.roughness=0.85
    return m
func _caixa(pai: Node3D,tamanho: Vector3,posicao: Vector3,cor: Color):
    var no:=MeshInstance3D.new()
    var forma:=BoxMesh.new()
    forma.size=tamanho
    no.mesh=forma
    no.position=posicao
    no.material_override=_material(cor)
    pai.add_child(no)
func _cilindro(pai: Node3D,raio: float,altura: float,posicao: Vector3,cor: Color):
    var no:=MeshInstance3D.new()
    var forma:=CylinderMesh.new()
    forma.top_radius=raio
    forma.bottom_radius=raio
    forma.height=altura
    forma.radial_segments=12
    no.mesh=forma
    no.position=posicao
    no.material_override=_material(cor)
    pai.add_child(no)
func _tubo(pai: Node3D,inicio: Vector3,fim: Vector3,raio: float,cor: Color):
    var no:=Node3D.new()
    var eixo: Vector3=(fim-inicio).normalized()
    var lateral:=Vector3.FORWARD.cross(eixo).normalized()
    if lateral.length()<0.1: lateral=Vector3.RIGHT
    no.transform=Transform3D(Basis(lateral,eixo,lateral.cross(eixo)),(inicio+fim)*0.5)
    pai.add_child(no)
    _cilindro(no,raio,inicio.distance_to(fim),Vector3.ZERO,cor)
