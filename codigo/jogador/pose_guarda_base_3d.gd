extends SkeletonModifier3D
## Guarda apoiada: escudo à frente do peito, tronco protegido e pernas firmes.
## Referência de gesto fornecida pelo usuário (Zelda); preserva o corpo chibi.
var heroi: Node
var tempo_de_revisao := -1.0
const TEMPO_ERGUER := 0.12
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi==null or not heroi.visible or heroi._acao!="guarda": return
    if heroi._player.assigned_animation in ["mixamo/SwordBlockIdle","mixamo/GreatSwordBlocking"]: return # Conserva a guarda escolhida.
    var s:=get_skeleton()
    var d: Node=heroi._jogador.defesa
    var tempo: float=tempo_de_revisao if tempo_de_revisao>=0 else maxf(0.0,(Time.get_ticks_msec()-d._inicio_guarda_ms)/1000.0)
    var peso:=smoothstep(0.0,TEMPO_ERGUER,tempo)
    var pes: Array=[]
    var maos: Array=[]
    for lado in ["R","L"]:
        pes.append(s.get_bone_global_pose(s.find_bone("DEF-foot."+lado)))
        maos.append(s.get_bone_global_pose(s.find_bone("DEF-hand."+lado)))
    var cabeca:=s.find_bone("DEF-head")
    var olhar:=s.get_bone_global_pose(cabeca).basis.orthonormalized()
    var quadril:=s.find_bone("DEF-hips")
    var pose:=s.get_bone_global_pose(quadril)
    var posicao:=pose.origin-Vector3(0,0.045*peso,0)
    var pai:=s.get_bone_parent(quadril)
    s.set_bone_pose_position(quadril,s.get_bone_global_pose(pai).affine_inverse()*posicao)
    _orientar(s,quadril,Basis(Vector3.UP,-0.35*peso)*pose.basis.orthonormalized())
    for i in 2:
        var lado: String=["R","L"][i]
        var pe: Transform3D=pes[i]
        var apoio:=pe.origin+Vector3(-0.03 if i==0 else 0.03,0,-0.025 if i==0 else 0.025)*peso
        heroi._acoes_manuais._resolver(s,"DEF-thigh."+lado,"DEF-shin."+lado,"DEF-foot."+lado,apoio,Vector3.BACK)
        _orientar(s,s.find_bone("DEF-foot."+lado),pe.basis.orthonormalized())
    # A cabeça acompanha o alvo, sem virar junto com o tronco.
    _orientar(s,cabeca,olhar)
    var respiro:=sin(maxf(tempo-TEMPO_ERGUER,0)*4.0)*0.006*peso
    var aparo:=0.0
    if d.estado==d.Estado.CONTRA:
        var fase: float=1.0-d._pausa/d.PAUSA_ANTES_DA_ESCUDADA
        aparo=sin(clampf(fase,0,1)*PI)*0.035
    var esquerda:=Vector3(0.03,1.12+respiro,0.30+aparo)
    var direita:=Vector3(-0.23,1.03,0.08)
    var base_l:=Basis(Vector3.UP,-0.10)*Basis(Vector3.RIGHT,-0.14)
    var base_r:=Basis(Vector3.BACK,0.35)*Basis(Vector3.RIGHT,-0.15)
    for dados in [["R",direita,base_r,maos[0]],["L",esquerda,base_l,maos[1]]]:
        var inicial: Transform3D=dados[3]
        var destino: Vector3=inicial.origin.lerp(dados[1],peso)
        var base: Basis=Basis(inicial.basis.orthonormalized().get_rotation_quaternion().slerp((dados[2] as Basis).get_rotation_quaternion(),peso))
        _braco(s,dados[0],destino,base)
func _orientar(s: Skeleton3D,i: int,base: Basis):
    var pai:=s.get_bone_parent(i)
    var acima:=s.get_bone_global_pose(pai).basis.orthonormalized()
    s.set_bone_pose_rotation(i,(acima.inverse()*base).get_rotation_quaternion())
func _braco(s: Skeleton3D,lado: String,punho: Vector3,base: Basis):
    var mao:=s.find_bone("DEF-hand."+lado)
    # CCD limitado aos dois segmentos; não move o corpo nem estica os membros.
    for passo in 6:
        for nome in ["DEF-forearm.","DEF-upper_arm."]:
            var i:=s.find_bone(nome+lado)
            var pose:=s.get_bone_global_pose(i)
            var atual:=s.get_bone_global_pose(mao).origin-pose.origin
            var destino:=punho-pose.origin
            if atual.length()<0.001 or destino.length()<0.001: continue
            var giro:=Quaternion(atual.normalized(),destino.normalized())
            _orientar(s,i,Basis(giro)*pose.basis.orthonormalized())
    _orientar(s,mao,base)
