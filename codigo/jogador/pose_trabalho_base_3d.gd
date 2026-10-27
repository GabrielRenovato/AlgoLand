extends SkeletonModifier3D
## Gestos próprios sobre o rig canônico: ferramentas baixas e vara de pesca.
## As duas pegas e o equipamento compartilham a mesma transformação final.
var heroi: Node
var ferramenta := Transform3D.IDENTITY
var erro_maos := 0.0
var erro_pes := 0.0
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi==null or not heroi.visible or heroi._acao not in ["fazenda_enxada","fazenda_picareta","pesca"]: return
    if heroi._player.assigned_animation.begins_with("ferramentas/") or heroi._player.assigned_animation.begins_with("mixamo/"): return # Preserva o movimento transferido do KayKit.
    var s:=get_skeleton()
    var a=heroi._acoes_manuais
    var pescando: bool=heroi._acao=="pesca"
    var t: float=heroi.progresso_acao_fazenda() if not pescando else 0.0
    var tempos: Array=[0.0,0.32,0.44117647,0.62,1.0]
    var pegas: Array=[Vector3(-.10,1.16,.20),Vector3(-.16,1.48,.09),Vector3(-.06,.94,.38),Vector3(-.06,.91,.40),Vector3(-.10,1.16,.20)]
    var eixos: Array=[Vector3(0,.65,.76),Vector3(-.10,.97,-.20),Vector3(0,-.90,.44),Vector3(0,-.92,.39),Vector3(0,.65,.76)]
    var pega: Vector3
    var eixo: Vector3
    var curvar: float
    var giro:=0.0
    if pescando:
        var sessao=heroi._jogador.get_node_or_null("SessaoPesca")
        if sessao==null:return
        var estado: int=sessao.estado
        pega=Vector3(-.10,1.12,.25)
        eixo=Vector3(0,.40,.92)
        curvar=.03
        if estado==sessao.Estado.CARREGANDO:
            pega=Vector3(-.14,1.27,.12)
            eixo=Vector3(-.08,.92,-.38)
            curvar=-.04
        elif estado==sessao.Estado.LANCANDO:
            t=clampf(sessao._tempo/sessao.DURACAO_LANCE,0,1)
            pega=a._vetor(t,[0.0,.36,.51,.70,1.0],[Vector3(-.14,1.27,.12),Vector3(-.15,1.44,.07),Vector3(-.07,1.22,.35),Vector3(-.10,1.10,.28),Vector3(-.10,1.12,.25)])
            eixo=a._vetor(t,[0.0,.36,.51,.70,1.0],[Vector3(-.08,.92,-.38),Vector3(0,.80,-.60),Vector3(0,.05,1),Vector3(0,.35,.94),Vector3(0,.40,.92)])
            curvar=a._valor(t,[0.0,.36,.51,.70,1.0],[-.04,-.08,.10,.06,.03])
        elif estado==sessao.Estado.PUXANDO:
            var anim=heroi._jogador.get_node_or_null("AnimacaoPesca")
            var tensao: float=anim.tensao if anim!=null else .4
            pega+=Vector3(-.025,.09,-.06)*tensao
            eixo=Vector3(0,.45+.3*tensao,.90-.2*tensao)
            curvar=-.08*tensao
        elif estado==sessao.Estado.PEGOU:
            var subir:=smoothstep(0,.28,sessao._tempo)
            pega=pega.lerp(Vector3(-.14,1.34,.15),subir)
            eixo=eixo.lerp(Vector3(-.18,.96,.20),subir)
            curvar=-.04
    else:
        if heroi._acao=="fazenda_enxada":
            # Depois do impacto puxa a lâmina pela terra antes de recolher.
            pegas[3]=Vector3(-.06,.92,.22)
            eixos[3]=Vector3(0,-.94,.34)
        pega=a._vetor(t,tempos,pegas)
        eixo=a._vetor(t,tempos,eixos)
        curvar=a._valor(t,tempos,[0,-.06,.34,.30,0])
        giro=a._valor(t,tempos,[0,-.10,.06,.04,0])
    var pes: Array=[]
    for lado in ["R","L"]: pes.append(s.get_bone_global_pose(s.find_bone("DEF-foot."+lado)))
    a._orientar(s,s.find_bone("DEF-hips"),Basis(Vector3.UP,giro))
    a._orientar(s,s.find_bone("DEF-spine.001"),Basis(Vector3.UP,giro)*Basis(Vector3.RIGHT,curvar))
    for i in 2:
        var lado: String=["R","L"][i]
        a._resolver(s,"DEF-thigh."+lado,"DEF-shin."+lado,"DEF-foot."+lado,pes[i].origin,Vector3(0,0,1))
        a._orientar(s,s.find_bone("DEF-foot."+lado),pes[i].basis.orthonormalized())
    eixo=eixo.normalized()
    var lateral:=Vector3.RIGHT-eixo*Vector3.RIGHT.dot(eixo)
    lateral=lateral.normalized()
    var base:=Basis(lateral,eixo,lateral.cross(eixo))
    var base_d:=Basis(base.z,base.x,base.y)
    var base_e:=Basis(-base.z,-base.x,base.y)
    var outra:=pega+eixo*(.13 if pescando else .19)
    for repeticao in 16:
        for dados in [["R",pega,base_d],["L",outra,base_e]]:
            var correcao: Vector3=a._limitar_pega(s,dados[0],dados[1],dados[2])-dados[1]
            pega+=correcao
            outra+=correcao
    ferramenta=Transform3D(base,pega)
    erro_maos=0
    for dados in [["R",pega,base_d],["L",outra,base_e]]:
        var lado: String=dados[0]
        var indice:=s.find_bone("DEF-hand."+lado)
        var b: Basis=dados[2]
        var ponto: Vector3=dados[1]
        var escala: float=s.get_bone_global_pose(indice).basis.get_scale().y
        a._resolver(s,"DEF-upper_arm."+lado,"DEF-forearm."+lado,"DEF-hand."+lado,ponto-b.y*.08*escala,Vector3(-1 if lado=="R" else 1,-.25,-.1))
        a._orientar(s,indice,b)
        erro_maos=maxf(erro_maos,(s.get_bone_global_pose(indice)*Vector3(0,.08,0)).distance_to(ponto))
    erro_pes=0
    for i in 2:
        erro_pes=maxf(erro_pes,s.get_bone_global_pose(s.find_bone("DEF-foot."+["R","L"][i])).origin.distance_to(pes[i].origin))
