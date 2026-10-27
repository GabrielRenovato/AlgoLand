extends SkeletonModifier3D
## Corrige a orientação do punho Mixamo após a proporção chibi.
## O cabo continua preso à mão; a correção independe da câmera/direção do jogador.
var heroi: Node
var folga := INF
var correcao := 0.0
func _init(): name="EncaixeMachado3D"
const AMOSTRAS := [Vector3(0,.24,0),Vector3(0,.36,0),Vector3(0,.48,0),Vector3(.19,.48,0),Vector3(.19,.56,0)]
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi==null or not heroi.visible or heroi._acao!="fazenda_machado": return
    if not heroi._player.assigned_animation.begins_with("mixamo/"): return
    var s:=get_skeleton()
    var indice:=s.find_bone("DEF-hand.R")
    var mao:=s.get_bone_global_pose(indice)
    var original:=mao.basis.orthonormalized()
    var rotacao: Basis=Basis(heroi._player.get_animation(heroi._player.assigned_animation).get_meta("rotacao_arma",Quaternion.IDENTITY))
    # Folga em profundidade impede que o arco passe por cima das costas
    # e do cabelo ampliados, inclusive quando não há colisão com a malha.
    var volumes: Array[Transform3D]=[]
    var tronco:=s.get_bone_global_pose(s.find_bone("DEF-spine.003"))
    volumes.append(Transform3D(tronco.basis.orthonormalized().scaled_local(Vector3(.25,.29,.45)),tronco.origin-tronco.basis.orthonormalized().y*.12))
    var cabeca:=s.get_bone_global_pose(s.find_bone("DEF-head"))
    volumes.append(Transform3D(cabeca.basis.scaled_local(Vector3(.18,.20,.40)),cabeca*Vector3(0,.13,0)))
    if heroi._escudo.is_visible_in_tree():
        var escudo: Transform3D=s.global_transform.affine_inverse()*heroi._escudo.global_transform
        volumes.append(Transform3D(escudo.basis.scaled_local(Vector3(.34,.34,.65)),escudo.origin))
    var inversas: Array[Transform3D]=[]
    for volume in volumes: inversas.append(volume.affine_inverse())
    # O clipe foi feito para proporções humanas. Quando a lâmina entra na
    # área de resguardo, abre o punho na direção do antebraço, preservando
    # o braço e o giro do golpe. A pega acompanha a rotação da própria mão.
    var cotovelo:=s.get_bone_global_pose(s.find_bone("DEF-forearm.R")).origin
    var extensao: Vector3=(mao.origin-cotovelo).normalized()
    var eixo: Vector3=(original*rotacao).y
    var giro:=Quaternion(eixo,extensao)
    var melhor:=mao.basis
    folga=_folga(mao,rotacao,inversas)
    if folga<1.12:
        for passo in range(1,33):
            var candidata:=Transform3D(Basis(Quaternion.IDENTITY.slerp(giro,passo/32.0))*mao.basis,mao.origin)
            var distancia:=_folga(candidata,rotacao,inversas)
            if distancia>folga:
                folga=distancia
                melhor=candidata.basis
            if distancia>=1.12: break
    mao.basis=melhor
    correcao=original.get_rotation_quaternion().angle_to(mao.basis.orthonormalized().get_rotation_quaternion())
    var pai:=s.get_bone_parent(indice)
    var acima:=s.get_bone_global_pose(pai).basis.orthonormalized()
    s.set_bone_pose_rotation(indice,(acima.inverse()*mao.basis.orthonormalized()).get_rotation_quaternion())

func _folga(mao: Transform3D,rotacao: Basis,inversas: Array[Transform3D]) -> float:
    var ferramenta:=Transform3D(mao.basis.orthonormalized()*rotacao,mao*Vector3(0,.08,0))
    var menor:=INF
    for ponto in AMOSTRAS:
        var pos: Vector3=ferramenta*ponto
        for inversa in inversas: menor=minf(menor,(inversa*pos).length())
    return menor
