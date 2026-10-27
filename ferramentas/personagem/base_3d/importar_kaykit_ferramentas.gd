extends SceneTree
## Transfere pesca e mineração CC0 do KayKit para o personagem canônico.
const NOMES := ["Pickaxe","Pickaxing","Fishing_Bite","Fishing_Cast","Fishing_Catch","Fishing_Idle","Fishing_Reeling","Fishing_Struggling","Fishing_Tug"]
const MAPA := {"DEF-hips":"hips","DEF-spine.001":"spine","DEF-spine.003":"chest","DEF-head":"head"}
var alvo: Skeleton3D
func _initialize(): rodar.call_deferred()
func mapear(nome: String) -> String:
    if MAPA.has(nome): return MAPA[nome]
    for lado in ["L","R"]:
        for par in [["upper_arm","upperarm"],["forearm","lowerarm"],["hand","hand"],["thigh","upperleg"],["shin","lowerleg"],["foot","foot"],["toe","toes"]]:
            if nome=="DEF-%s.%s" % [par[0],lado]: return "%s.%s" % [par[1],lado.to_lower()]
    return ""
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var origem_arquivo := ProjectSettings.globalize_path("res://arte/fontes/personagens/base_3d/kaykit/Rig_Medium_Tools.glb")
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--fonte="): origem_arquivo=argumento.trim_prefix("--fonte=")
    var doc:=GLTFDocument.new()
    var estado:=GLTFState.new()
    assert(doc.append_from_file(origem_arquivo,estado)==OK)
    var cena:=doc.generate_scene(estado)
    root.add_child(cena)
    var origem: Skeleton3D=cena.find_children("*","Skeleton3D",true,false)[0]
    var player: AnimationPlayer=cena.find_children("*","AnimationPlayer",true,false)[0]
    var destino: Node3D=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
    root.add_child(destino)
    alvo=destino.find_children("*","Skeleton3D",true,false)[0]
    for modificador in alvo.find_children("*","SkeletonModifier3D",true,false): modificador.active=false
    var pares: Array=[]
    for osso in alvo.get_bone_count():
        var fonte_osso:=origem.find_bone(mapear(alvo.get_bone_name(osso)))
        if fonte_osso>=0: pares.append([osso,fonte_osso])
    var biblioteca:=AnimationLibrary.new()
    var pega_ref:=Node3D.new()
    pega_ref.name="PegaKayKit"
    destino.add_child(pega_ref)
    var slot_fonte:=origem.find_bone("handslot.r")
    var mao_alvo:=alvo.find_bone("DEF-hand.R")
    var base_origem:=origem.global_basis.orthonormalized()
    var base_alvo:=alvo.global_basis.orthonormalized()
    var quadril:=alvo.find_bone("DEF-hips")
    var quadril_fonte:=origem.find_bone("hips")
    var proporcao:=alvo.get_bone_global_rest(quadril).origin.y/maxf(0.01,(origem.global_transform*origem.get_bone_global_rest(quadril_fonte).origin).y)
    var relatorio: Array=[]
    for nome in NOMES:
        var fonte:=player.get_animation(nome)
        var animacao:=Animation.new()
        animacao.length=fonte.length
        if nome in ["Pickaxing","Fishing_Idle","Fishing_Reeling","Fishing_Struggling"]:
            animacao.loop_mode=Animation.LOOP_LINEAR
        var slot_rot:=animacao.add_track(Animation.TYPE_ROTATION_3D)
        animacao.track_set_path(slot_rot,NodePath("PegaKayKit"))
        var trilhas: Dictionary={}
        for par in pares:
            var trilha:=animacao.add_track(Animation.TYPE_ROTATION_3D)
            animacao.track_set_path(trilha,NodePath(str(destino.get_path_to(alvo))+":"+alvo.get_bone_name(par[0])))
            trilhas[par[0]]=trilha
        var trilha_pos:=animacao.add_track(Animation.TYPE_POSITION_3D)
        animacao.track_set_path(trilha_pos,NodePath(str(destino.get_path_to(alvo))+":DEF-hips"))
        player.play(nome,0)
        player.speed_scale=0
        var amostras:=ceili(fonte.length*30)
        for q in range(amostras+1):
            var tempo:=fonte.length*q/amostras
            origem.reset_bone_poses()
            player.seek(tempo,true)
            alvo.reset_bone_poses()
            var desejadas: Dictionary={}
            for par in pares:
                var osso: int=par[0]
                var fonte_osso: int=par[1]
                var repouso_fonte:=base_origem*origem.get_bone_global_rest(fonte_osso).basis.orthonormalized()
                var pose_fonte:=base_origem*origem.get_bone_global_pose(fonte_osso).basis.orthonormalized()
                var repouso_alvo:=base_alvo*alvo.get_bone_global_rest(osso).basis.orthonormalized()
                desejadas[osso]=base_alvo.inverse()*pose_fonte*repouso_fonte.inverse()*repouso_alvo
            aplicar(-1,desejadas)
            var orientacao_slot:=base_alvo.inverse()*base_origem*origem.get_bone_global_pose(slot_fonte).basis.orthonormalized()
            var local_slot:=alvo.get_bone_global_pose(mao_alvo).basis.orthonormalized().inverse()*orientacao_slot
            animacao.rotation_track_insert_key(slot_rot,tempo,local_slot.get_rotation_quaternion())
            for par in pares: animacao.rotation_track_insert_key(trilhas[par[0]],tempo,alvo.get_bone_pose_rotation(par[0]))
            var deslocamento:=origem.global_basis*(origem.get_bone_global_pose(quadril_fonte).origin-origem.get_bone_global_rest(quadril_fonte).origin)*proporcao
            # O jogo decide a posição no chão; o agachamento permanece na pelve.
            deslocamento.x=0
            deslocamento.z=0
            animacao.position_track_insert_key(trilha_pos,tempo,alvo.get_bone_rest(quadril).origin+base_alvo.inverse()*deslocamento)
        biblioteca.add_animation(nome,animacao)
        relatorio.append({"nome":nome,"duracao":fonte.length,"ossos":pares.size()})
        print("KAYKIT IMPORTADO ",nome," ",fonte.length,"s")
    assert(ResourceSaver.save(biblioteca,"res://assets/personagens/base_3d/kaykit_ferramentas.res",ResourceSaver.FLAG_COMPRESS)==OK)
    FileAccess.open("res://arte/fontes/personagens/base_3d/kaykit/ferramentas.json",FileAccess.WRITE).store_string(JSON.stringify({"fonte":"https://kaylousberg.itch.io/kaykit-character-animations","licenca":"CC0","animacoes":relatorio},"  "))
    quit()
func aplicar(pai: int,desejadas: Dictionary):
    var filhos:=alvo.get_parentless_bones() if pai<0 else alvo.get_bone_children(pai)
    for osso in filhos:
        if desejadas.has(osso):
            var base:=Basis.IDENTITY if pai<0 else alvo.get_bone_global_pose(pai).basis.orthonormalized()
            alvo.set_bone_pose_rotation(osso,(base.inverse()*desejadas[osso]).get_rotation_quaternion())
        aplicar(osso,desejadas)
