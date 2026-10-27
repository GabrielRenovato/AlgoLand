extends SceneTree
## Transfere os FBX escolhidos pelo usuário ao rig canônico, preservando as fontes.
const SAIDA := "res://assets/personagens/base_3d/mixamo.res"
const MAPA := {"DEF-hips":"Hips","DEF-spine.001":"Spine","DEF-spine.002":"Spine1","DEF-spine.003":"Spine2","DEF-neck":"Neck","DEF-head":"Head"}
var alvo: Skeleton3D
var cena_alvo: Node3D
var biblioteca:=AnimationLibrary.new()
var relatorio: Array=[]
func _initialize(): rodar.call_deferred()
func mapa(nome: String) -> String:
    if MAPA.has(nome): return "mixamorig_"+MAPA[nome]
    for lado in ["L","R"]:
        var prefixo: String="Left" if lado=="L" else "Right"
        for par in [["shoulder","Shoulder"],["upper_arm","Arm"],["forearm","ForeArm"],["hand","Hand"],["thigh","UpLeg"],["shin","Leg"],["foot","Foot"],["toe","ToeBase"]]:
            if nome=="DEF-%s.%s" % [par[0],lado]: return "mixamorig_"+prefixo+par[1]
        for dedo in [["f_index","Index"],["f_middle","Middle"],["f_ring","Ring"],["f_pinky","Pinky"],["thumb","Thumb"]]:
            for numero in [1,2,3]:
                if nome=="DEF-%s.%02d.%s" % [dedo[0],numero,lado]: return "mixamorig_"+prefixo+"Hand"+dedo[1]+str(numero)
    return ""
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    cena_alvo=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
    root.add_child(cena_alvo)
    alvo=cena_alvo.find_children("*","Skeleton3D",true,false)[0]
    for modificador in alvo.find_children("*","SkeletonModifier3D",true,false): modificador.active=false
    var catalogo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/personagens/base_3d/mixamo/catalogo.json"))
    for id in catalogo:
        var dados: Dictionary=catalogo[id]
        await importar(ProjectSettings.globalize_path("res://arte/fontes/personagens/base_3d/mixamo/"+dados.arquivo),id,dados.loop)
    FileAccess.open("res://arte/fontes/personagens/base_3d/mixamo/importacao.json",FileAccess.WRITE).store_string(JSON.stringify(relatorio,"  "))
    assert(ResourceSaver.save(biblioteca,SAIDA,ResourceSaver.FLAG_COMPRESS)==OK)
    quit()
func importar(arquivo: String,id: String,repetir: bool):
    var doc = ClassDB.instantiate("FBXDocument")
    var estado = ClassDB.instantiate("FBXState")
    assert(doc.append_from_file(arquivo,estado)==OK)
    var cena = doc.generate_scene(estado)
    root.add_child(cena)
    var origem: Skeleton3D = cena.find_children("*","Skeleton3D",true,false)[0]
    var player: AnimationPlayer = cena.find_children("*","AnimationPlayer",true,false)[0]
    var nome_fonte := player.get_animation_list()[0]
    var fonte := player.get_animation(nome_fonte)
    var animacao := Animation.new()
    animacao.length=fonte.length
    var nome := arquivo.get_file().get_basename().replace("@","_").replace(" [RM]","_RM")
    animacao.loop_mode=Animation.LOOP_LINEAR if repetir else Animation.LOOP_NONE
    var pares: Array = []
    var trilhas := {}
    for osso in alvo.get_bone_count():
        var nome_mapeado := mapa(alvo.get_bone_name(osso))
        var fonte_osso := origem.find_bone(nome_mapeado)
        if fonte_osso<0: continue
        pares.append([osso,fonte_osso])
        var trilha := animacao.add_track(Animation.TYPE_ROTATION_3D)
        animacao.track_set_path(trilha,NodePath(str(cena_alvo.get_path_to(alvo))+":"+alvo.get_bone_name(osso)))
        trilhas[osso]=trilha
    var quadril := alvo.find_bone("DEF-hips")
    var quadril_fonte := origem.find_bone("mixamorig_Hips")
    var trilha_pos:=animacao.add_track(Animation.TYPE_POSITION_3D)
    animacao.track_set_path(trilha_pos,NodePath(str(cena_alvo.get_path_to(alvo))+":DEF-hips"))
    var base_origem := origem.global_basis.orthonormalized()
    var base_alvo := alvo.global_basis.orthonormalized()
    var proporcao := alvo.get_bone_global_rest(quadril).origin.y/maxf(0.01,(origem.global_transform*origem.get_bone_global_rest(quadril_fonte).origin).y)
    player.play(nome_fonte,0.0)
    player.speed_scale=0
    var amostras := maxi(1,ceili(fonte.length*30))
    for q in range(amostras+1):
        var tempo := fonte.length*q/amostras
        origem.reset_bone_poses()
        player.seek(tempo,true)
        alvo.reset_bone_poses()
        var desejadas := {}
        for par in pares:
            var osso: int=par[0]
            var fonte_osso: int=par[1]
            var repouso_fonte := base_origem*origem.get_bone_global_rest(fonte_osso).basis.orthonormalized()
            var pose_fonte := base_origem*origem.get_bone_global_pose(fonte_osso).basis.orthonormalized()
            var repouso_alvo := base_alvo*alvo.get_bone_global_rest(osso).basis.orthonormalized()
            var delta_rotacao := pose_fonte*repouso_fonte.inverse()
            desejadas[osso]=base_alvo.inverse()*delta_rotacao*repouso_alvo
        # Ordem hierárquica, independente dos índices (o rig original tem filhos antes dos pais).
        aplicar_poses(-1,desejadas)
        for par in pares:
            var osso: int=par[0]
            animacao.rotation_track_insert_key(trilhas[osso],tempo,alvo.get_bone_pose_rotation(osso))
        var deslocamento := origem.global_basis*(origem.get_bone_global_pose(quadril_fonte).origin-origem.get_bone_global_rest(quadril_fonte).origin)*proporcao
        deslocamento.x=0
        deslocamento.z=0
        animacao.position_track_insert_key(trilha_pos,tempo,alvo.get_bone_rest(quadril).origin+base_alvo.inverse()*deslocamento)
    var mao_alvo:=alvo.find_bone("DEF-hand.R")
    var mao_fonte:=origem.find_bone("mixamorig_RightHand")
    var rotacao: Basis=alvo.get_bone_global_rest(mao_alvo).basis.orthonormalized().inverse()*base_alvo.inverse()*base_origem*origem.get_bone_global_rest(mao_fonte).basis.orthonormalized()*Basis(Vector3.BACK,-PI/2)
    animacao.set_meta("rotacao_arma",rotacao.orthonormalized().get_rotation_quaternion())
    animacao.set_meta("fonte",arquivo.get_file())
    biblioteca.add_animation(id,animacao)
    print("MIXAMO IMPORTADO: ",nome," duracao=",fonte.length," ossos=",pares.size())
    relatorio.append({"id":id,"arquivo":arquivo.get_file(),"duracao":fonte.length,"ossos":pares.size(),"amostras":amostras+1,"loop":repetir,"raiz":"Deslocamento XZ removido; física do jogador controla a posição."})
    cena.queue_free()
    await process_frame
func aplicar_poses(pai: int,desejadas: Dictionary):
    var filhos := alvo.get_parentless_bones() if pai<0 else alvo.get_bone_children(pai)
    for osso in filhos:
        if desejadas.has(osso):
            var base_pai := Basis.IDENTITY if pai<0 else alvo.get_bone_global_pose(pai).basis.orthonormalized()
            alvo.set_bone_pose_rotation(osso,(base_pai.inverse()*desejadas[osso]).get_rotation_quaternion())
        aplicar_poses(osso,desejadas)
