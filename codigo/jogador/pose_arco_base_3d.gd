extends SkeletonModifier3D
## O FBX pega a flecha; esta extensão puxa e solta a corda com os mesmos braços.
var heroi: Node
var erro_maos := 0.0
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi==null or not heroi.visible or heroi._acao!="arco":return
    var p: float=heroi.progresso_arco()
    if p<.40:return
    var s:=get_skeleton()
    var a=heroi._acoes_manuais
    var peso:=smoothstep(.40,.54,p)
    var liberar: bool=heroi._jogador.no_arco._indice>=heroi._jogador.no_arco.QUADRO_SOLTAR
    var puxar:=smoothstep(.50,.70,p)
    var direita:=Vector3(.12,1.20,.40).lerp(Vector3(-.16,1.26,.10),puxar)
    if liberar:direita=Vector3(-.16,1.26,.10).lerp(Vector3(-.25,1.27,.07),smoothstep(.72,.82,p))
    var esquerda:=Vector3(.18,1.20,.48)
    erro_maos=0
    for dados in [["R",direita],["L",esquerda]]:
        var lado: String=dados[0]
        var i:=s.find_bone("DEF-hand."+lado)
        var atual:=s.get_bone_global_pose(i)
        var orientacao:=atual.basis.orthonormalized()
        var pega: Vector3=(atual*Vector3(0,.08,0)).lerp(dados[1],peso)
        pega=a._limitar_pega(s,lado,pega,orientacao)
        var punho:=pega-orientacao.y*.08*atual.basis.get_scale().y
        a._resolver(s,"DEF-upper_arm."+lado,"DEF-forearm."+lado,"DEF-hand."+lado,punho,Vector3(-1 if lado=="R" else 1,-.2,-.1))
        a._orientar(s,i,orientacao)
        erro_maos=maxf(erro_maos,(s.get_bone_global_pose(i)*Vector3(0,.08,0)).distance_to(pega))
