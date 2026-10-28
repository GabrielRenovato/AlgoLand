extends SkeletonModifier3D
## O movimento vem das animações Polearm do Kevin Iglesias. Os dois pontos
## de pega determinam o eixo da haste depois da proporção chibi.
var heroi: Node
var erro_apoio := 0.0
var erro_montante := 0.0
var amostragem_automatica := true
func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()
func _aplicar():
    if heroi == null or not heroi.visible: return
    var s := get_skeleton()
    heroi._ferramentas.atualizar(s,heroi)
    heroi._arco_visual.atualizar(s)
    heroi.orientar_escudo_3d(s)
    if not heroi._arma_de_lanca():
        _elevar_corte_uma_mao(s)
        var direita := s.get_bone_global_pose(s.find_bone("DEF-hand.R"))
        var encaixe := Transform3D(heroi._espada.basis,heroi.MAO_POSICAO)
        if heroi._arma_de_duas_maos() and heroi._acao in ["espada","guarda"]:
            # As duas mãos do clipe orientam o cabo, sem modificar a animação.
            var esquerda:=s.get_bone_global_pose(s.find_bone("DEF-hand.L"))
            var pega_d:=direita*Vector3(0,.08,0)
            var pega_e:=esquerda*Vector3(0,.08,0)
            var eixo: Vector3=(pega_d-pega_e).normalized()
            var lateral: Vector3=encaixe.basis.x
            lateral=direita.basis*lateral
            lateral=(lateral-eixo*lateral.dot(eixo)).normalized()
            if lateral.length()<.1: lateral=Vector3.RIGHT
            var escala: float=direita.basis.get_scale().x
            var base:=Basis(lateral,eixo,lateral.cross(eixo)).scaled(Vector3.ONE*escala)
            var t: Transform3D=heroi._modelo.global_transform.affine_inverse()*s.global_transform*Transform3D(base,pega_d)
            heroi._espada.transform=t
            heroi._transformacao_rastro=t
            erro_montante=maxf(0,pega_d.distance_to(pega_e)-.31*escala)
            if amostragem_automatica: heroi._atualizar_rastro(true)
            return
        heroi._transformacao_rastro=heroi._modelo.global_transform.affine_inverse()*s.global_transform*direita*encaixe
        if amostragem_automatica: heroi._atualizar_rastro(true)
        return
    if heroi._lanca.get_parent()!=heroi._modelo:
        if amostragem_automatica: heroi._atualizar_rastro(true)
        return
    var direita := s.get_bone_global_pose(s.find_bone("DEF-hand.R"))
    var esquerda := s.get_bone_global_pose(s.find_bone("DEF-hand.L"))
    var pega_direita := direita*Vector3(0,0.08,0)
    var pega_esquerda := esquerda*Vector3(0,0.08,0)
    var eixo := (pega_esquerda-pega_direita).normalized()
    var lateral := Vector3.UP.cross(eixo).normalized()
    if lateral.length()<0.1: lateral=Vector3.RIGHT
    var base := Basis(lateral,eixo,lateral.cross(eixo)).scaled(Vector3.ONE*direita.basis.get_scale().x)
    var transformacao := s.global_transform*Transform3D(base,pega_direita)
    heroi._lanca.transform=heroi._modelo.global_transform.affine_inverse()*transformacao
    erro_apoio=pega_esquerda.distance_to(pega_direita+eixo*pega_direita.distance_to(pega_esquerda))
    if amostragem_automatica: heroi._atualizar_rastro(true)

## O corte horizontal fica encurtado pela câmera quando aponta para o norte.
## Inclina o punho junto da lâmina; o rastro e a colisão seguem a mesma pose real.
func _elevar_corte_uma_mao(s: Skeleton3D) -> void:
    if heroi._acao!="espada" or heroi._arma_de_duas_maos(): return
    var direcao: Vector2=heroi._direcao_demonstracao if heroi._demonstracao else heroi._jogador._direcao_golpe_3d
    var norte:=maxf(-direcao.normalized().y,0.0)
    if norte<=0.0: return
    var p: float=heroi._progresso_golpe
    var peso:=sin(PI*clampf((p-.10)/.80,0.0,1.0))*norte
    if peso<=.001: return
    var indice:=s.find_bone("DEF-hand.R")
    var mao: Transform3D=s.global_transform*s.get_bone_global_pose(indice)
    var clipe: Animation=heroi._player.get_animation(heroi._player.assigned_animation)
    if str(clipe.get_meta("fonte","")).begins_with("quaternius/"):
        # Preserva o corte visível acima do tronco baixo do modelo chibi ao atacar para o norte.
        var fase: int=heroi._golpe_demonstracao if heroi._demonstracao else clampi(heroi._jogador._fase_combo,1,3)
        var elevacao: float=[.28,.80,.50][fase-1]
        var alvo: Vector3=s.global_transform.affine_inverse()*(mao.origin+Vector3.UP*elevacao*peso)
        var cotovelo:=s.get_bone_global_pose(s.find_bone("DEF-forearm.R")).origin
        var ombro:=s.get_bone_global_pose(s.find_bone("DEF-upper_arm.R")).origin
        heroi._acoes_manuais._resolver(s,"DEF-upper_arm.R","DEF-forearm.R","DEF-hand.R",alvo,(cotovelo-ombro).normalized())
        var nova:=s.global_transform*s.get_bone_global_pose(indice)
        nova.basis=mao.basis
        s.set_bone_global_pose(indice,s.global_transform.affine_inverse()*nova)
        mao=nova
    var eixo: Vector3=(mao.basis*heroi._espada.basis*Vector3.UP).normalized()
    var novo_combo: bool=str(clipe.get_meta("fonte","")).begins_with("quaternius/")
    var segundo: bool=novo_combo and (heroi._golpe_demonstracao if heroi._demonstracao else heroi._jogador._fase_combo)==2
    var elevado: Vector3=(eixo+Vector3.UP*(3.5 if segundo else 1.25)).normalized()
    var giro:=Quaternion(eixo,elevado)
    # Limita a extensão do punho, inclusive quando o clipe aponta a lâmina para baixo.
    giro=Quaternion.IDENTITY.slerp(giro,minf(1.0,deg_to_rad(100.0 if segundo else 55.0)/maxf(giro.get_angle(),.001)))
    var correcao:=Quaternion.IDENTITY.slerp(giro,peso)
    mao.basis=Basis(correcao)*mao.basis
    s.set_bone_global_pose(indice,s.global_transform.affine_inverse()*mao)
