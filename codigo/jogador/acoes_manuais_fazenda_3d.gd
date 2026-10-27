extends SkeletonModifier3D
## Poses próprias: corte à altura do tronco e gesto curto de semear à frente.
## Resolve os braços depois da proporção chibi; equipamento usa a mesma pega.
var heroi: Node
var transformacao_machado := Transform3D.IDENTITY
var erro_maos := 0.0
var erro_pes := 0.0
var pegas_reais: Array[Vector3]=[]
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi == null or not heroi.visible: return
    if heroi._acao not in ["fazenda_machado","fazenda_plantar"]: return
    if heroi._player.assigned_animation.begins_with("mixamo/"): return
    var s := get_skeleton()
    var t: float=heroi.progresso_acao_fazenda()
    var corte: bool=heroi._acao=="fazenda_machado"
    var pes: Array=[]
    for lado in ["R","L"]: pes.append(s.get_bone_global_pose(s.find_bone("DEF-foot."+lado)))
    var esforco: float=sin(t*PI)
    var quadril := s.find_bone("DEF-hips")
    var pos := s.get_bone_global_pose(quadril).origin-Vector3(0,0.025*esforco,0)
    var pai_quadril:=s.get_bone_parent(quadril)
    s.set_bone_pose_position(quadril,s.get_bone_global_pose(pai_quadril).affine_inverse()*pos)
    var giro := _valor(t,[0.0,0.32,0.441176,0.62,1.0],[0.0,-0.25,0.17,0.19,0.0]) if corte else 0.0
    _orientar(s,quadril,Basis(Vector3.UP,giro))
    _orientar(s,s.find_bone("DEF-spine.001"),Basis(Vector3.UP,giro)*Basis(Vector3.RIGHT,deg_to_rad(8.0 if corte else 16.0)*esforco))
    for i in 2:
        var lado: String=["R","L"][i]
        var pe: Transform3D=pes[i]
        _resolver(s,"DEF-thigh."+lado,"DEF-shin."+lado,"DEF-foot."+lado,pe.origin,Vector3(0,0,1))
        _orientar(s,s.find_bone("DEF-foot."+lado),pe.basis.orthonormalized())
    var direita: Vector3
    var esquerda: Vector3
    var base_d: Basis
    var base_e: Basis
    if corte:
        var tempos := [0.0,0.32,0.441176,0.62,1.0]
        direita=_vetor(t,tempos,[Vector3(-0.09,1.13,0.20),Vector3(-0.24,1.26,0.07),Vector3(-0.07,1.13,0.20),Vector3(0.02,1.09,0.24),Vector3(-0.09,1.13,0.20)])
        var eixo:=_vetor(t,tempos,[Vector3(0,0.65,0.76),Vector3(-0.30,0.94,-0.16),Vector3(0,-0.10,0.995),Vector3(0.25,-0.23,0.94),Vector3(0,0.65,0.76)]).normalized()
        var lateral:=Vector3.RIGHT-eixo*Vector3.RIGHT.dot(eixo)
        lateral=lateral.normalized()
        var base:=Basis(lateral,eixo,lateral.cross(eixo))
        esquerda=direita+eixo*0.14
        # Os dedos atravessam a largura do cabo; os punhos ficam para fora.
        base_d=Basis(base.z,base.x,base.y)
        base_e=Basis(-base.z,-base.x,base.y)
    else:
        var tempos := [0.0,0.36,0.50,0.67,1.0]
        direita=_vetor(t,tempos,[Vector3(-0.17,1.10,0.16),Vector3(0.08,1.16,0.22),Vector3(-0.06,1.15,0.36),Vector3(-0.06,1.13,0.36),Vector3(-0.17,1.10,0.16)])
        esquerda=Vector3(0.18,1.10,0.23)
        base_d=Basis(Vector3.UP,Vector3.RIGHT,Vector3.FORWARD)
        base_e=Basis(Vector3.DOWN,Vector3.LEFT,Vector3.FORWARD)
    if corte:
        # Encaixa a trajetória no alcance real dos dois braços, sem esticar a malha.
        for repeticao in 16:
            for dados in [["R",direita,base_d],["L",esquerda,base_e]]:
                var ajustada:=_limitar_pega(s,dados[0],dados[1],dados[2])
                var correcao: Vector3=ajustada-dados[1]
                direita+=correcao
                esquerda+=correcao
        transformacao_machado.origin=direita
        var eixo: Vector3=(esquerda-direita).normalized()
        var lateral: Vector3=base_d.y
        transformacao_machado.basis=Basis(lateral,eixo,lateral.cross(eixo))
    else:
        direita=_limitar_pega(s,"R",direita,base_d)
        esquerda=_limitar_pega(s,"L",esquerda,base_e)
    erro_maos=0.0
    pegas_reais.clear()
    for dados in [["R",direita,base_d],["L",esquerda,base_e]]:
        var lado: String=dados[0]
        var indice:=s.find_bone("DEF-hand."+lado)
        var escala: Vector3=s.get_bone_global_pose(indice).basis.get_scale()
        var base: Basis=dados[2]
        var pega: Vector3=dados[1]
        var punho:=pega-base.y*0.08*escala.y
        _resolver(s,"DEF-upper_arm."+lado,"DEF-forearm."+lado,"DEF-hand."+lado,punho,Vector3(-1 if lado=="R" else 1,-0.3,-0.1))
        _orientar(s,indice,base)
        var real:=s.get_bone_global_pose(indice)*Vector3(0,0.08,0)
        erro_maos=maxf(erro_maos,real.distance_to(pega))
        pegas_reais.append(real)
    erro_pes=0.0
    for i in 2:
        var real:=s.get_bone_global_pose(s.find_bone("DEF-foot."+["R","L"][i])).origin
        erro_pes=maxf(erro_pes,real.distance_to(pes[i].origin))
func _orientar(s: Skeleton3D,i: int,base: Basis):
    var pai:=s.get_bone_parent(i)
    var acima:=s.get_bone_global_pose(pai).basis.orthonormalized() if pai>=0 else Basis.IDENTITY
    s.set_bone_pose_rotation(i,(acima.inverse()*base).orthonormalized().get_rotation_quaternion())
func _resolver(s: Skeleton3D,a: String,b: String,c: String,alvo: Vector3,polo: Vector3):
    var ia:=s.find_bone(a)
    var ib:=s.find_bone(b)
    var ic:=s.find_bone(c)
    var pa:=s.get_bone_global_pose(ia).origin
    var pb:=s.get_bone_global_pose(ib).origin
    var pc:=s.get_bone_global_pose(ic).origin
    var l1:=pa.distance_to(pb)
    var l2:=pb.distance_to(pc)
    var distancia:=clampf(pa.distance_to(alvo),absf(l1-l2)+0.0001,l1+l2-0.0001)
    var eixo: Vector3=(alvo-pa).normalized()
    var plano: Vector3=(polo-eixo*polo.dot(eixo)).normalized()
    var x: float=(l1*l1-l2*l2+distancia*distancia)/(2.0*distancia)
    var cotovelo:=pa+eixo*x+plano*sqrt(maxf(0,l1*l1-x*x))
    var base:=s.get_bone_global_pose(ia).basis.orthonormalized()
    _orientar(s,ia,Basis(Quaternion((pb-pa).normalized(),(cotovelo-pa).normalized()))*base)
    pb=s.get_bone_global_pose(ib).origin
    pc=s.get_bone_global_pose(ic).origin
    base=s.get_bone_global_pose(ib).basis.orthonormalized()
    _orientar(s,ib,Basis(Quaternion((pc-pb).normalized(),(alvo-pb).normalized()))*base)
func _vetor(t: float,tempos: Array,valores: Array) -> Vector3:
    for i in range(1,tempos.size()):
        if t<=tempos[i]:
            var f:=smoothstep(tempos[i-1],tempos[i],t)
            return (valores[i-1] as Vector3).lerp(valores[i],f)
    return valores.back()
func _valor(t: float,tempos: Array,valores: Array) -> float:
    for i in range(1,tempos.size()):
        if t<=tempos[i]: return lerpf(valores[i-1],valores[i],smoothstep(tempos[i-1],tempos[i],t))
    return valores.back()

func _limitar_pega(s: Skeleton3D,lado: String,pega: Vector3,base: Basis) -> Vector3:
    var ombro:=s.get_bone_global_pose(s.find_bone("DEF-upper_arm."+lado)).origin
    var cotovelo:=s.get_bone_global_pose(s.find_bone("DEF-forearm."+lado)).origin
    var mao:=s.get_bone_global_pose(s.find_bone("DEF-hand."+lado))
    var alcance:=ombro.distance_to(cotovelo)+cotovelo.distance_to(mao.origin)-0.002
    var offset:=base.y*0.08*mao.basis.get_scale().y
    var punho:=pega-offset
    return ombro+(punho-ombro).limit_length(alcance)+offset
