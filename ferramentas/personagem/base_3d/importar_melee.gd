extends SceneTree
## Retarget por orientação global de repouso; preserva comprimentos do modelo.
const SAIDA := "res://assets/personagens/base_3d/kevin_melee_free.res"
const MAPA := {"DEF-hips":"B-hips","DEF-spine.001":"B-spine","DEF-spine.003":"B-chest","DEF-neck":"B-neck","DEF-head":"B-head"}
var alvo: Skeleton3D
var cena_alvo: Node3D
var biblioteca := AnimationLibrary.new()
var relatorio: Array = []
func _initialize(): rodar.call_deferred()
func mapa(nome: String) -> String:
    if MAPA.has(nome): return MAPA[nome]
    for lado in ["L","R"]:
        for par in [["shoulder","shoulder"],["upper_arm","upperArm"],["forearm","forearm"],["hand","hand"],["thigh","thigh"],["shin","shin"],["foot","foot"],["toe","toe"]]:
            if nome=="DEF-%s.%s" % [par[0],lado]: return "B-%s.%s" % [par[1],lado]
        for dedo in [["f_index","indexFinger"],["f_middle","middleFinger"],["f_ring","ringFinger"],["f_pinky","pinky"],["thumb","thumb"]]:
            for numero in [1,2,3]:
                if nome=="DEF-%s.%02d.%s" % [dedo[0],numero,lado]: return "B-%s%02d.%s" % [dedo[1],numero,lado]
    return ""
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var pasta := "/tmp/algoland-human-melee-free/Animations"
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--fonte="): pasta=argumento.trim_prefix("--fonte=")
    cena_alvo = load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
    root.add_child(cena_alvo)
    alvo = cena_alvo.find_children("*","Skeleton3D",true,false)[0]
    for modificador in alvo.find_children("*","SkeletonModifier3D",true,false): modificador.active=false
    var arquivos: Array[String] = []
    coletar(pasta,arquivos)
    for arquivo in arquivos: await importar(arquivo,pasta)
    assert(biblioteca.get_animation_list().size()==arquivos.size())
    for arquivo in arquivos:
        if arquivo.ends_with("Attack1H01_L.fbx"): await importar(arquivo,pasta,true)
    assert(ResourceSaver.save(biblioteca,SAIDA,ResourceSaver.FLAG_COMPRESS)==OK)
    FileAccess.open("res://arte/fontes/personagens/base_3d/kevin_melee_free/manifesto.json",FileAccess.WRITE).store_string(JSON.stringify({"fonte":"https://kevdev.itch.io/human-melee-animatons-free","autor":"Kevin Iglesias","licenca":"Standard Asset Store EULA; uso comercial permitido, sem revenda dos arquivos; documentação original dentro do ZIP.","animacoes":relatorio},"  "))
    print("MELEE IMPORTADO: ",arquivos.size()," animações retargetadas")
    quit()
func coletar(pasta: String,arquivos: Array[String]):
    for diretorio in DirAccess.get_directories_at(pasta): coletar(pasta+"/"+diretorio,arquivos)
    for arquivo in DirAccess.get_files_at(pasta):
        if arquivo.ends_with(".fbx"): arquivos.append(pasta+"/"+arquivo)
func importar(arquivo: String,pasta: String,espelhar: bool = false):
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
    if espelhar: nome += "_Espelhado"
    var mascarada := arquivo.contains("Masked Poses")
    var movimento := arquivo.contains("Movement/")
    if movimento or nome.contains("Idle") or mascarada: animacao.loop_mode=Animation.LOOP_LINEAR
    var pares: Array = []
    var trilhas := {}
    for osso in alvo.get_bone_count():
        var nome_mapeado := mapa(alvo.get_bone_name(osso))
        if espelhar:
            nome_mapeado=nome_mapeado.replace(".L",".TEMP").replace(".R",".L").replace(".TEMP",".R")
        var fonte_osso := origem.find_bone(nome_mapeado)
        if fonte_osso<0: continue
        # Máscaras não podem substituir pernas/raiz quando combinadas com corrida.
        if mascarada and (alvo.get_bone_name(osso).contains("thigh") or alvo.get_bone_name(osso).contains("shin") or alvo.get_bone_name(osso).contains("foot") or alvo.get_bone_name(osso).contains("toe") or alvo.get_bone_name(osso)=="DEF-hips"): continue
        pares.append([osso,fonte_osso])
        var trilha := animacao.add_track(Animation.TYPE_ROTATION_3D)
        animacao.track_set_path(trilha,NodePath(str(cena_alvo.get_path_to(alvo))+":"+alvo.get_bone_name(osso)))
        trilhas[osso]=trilha
    var quadril := alvo.find_bone("DEF-hips")
    var quadril_fonte := origem.find_bone("B-hips")
    var trilha_pos := -1
    if not mascarada:
        trilha_pos=animacao.add_track(Animation.TYPE_POSITION_3D)
        animacao.track_set_path(trilha_pos,NodePath(str(cena_alvo.get_path_to(alvo))+":DEF-hips"))
    var base_origem := origem.global_basis.orthonormalized()
    var base_alvo := alvo.global_basis.orthonormalized()
    var proporcao := alvo.get_bone_global_rest(quadril).origin.y/maxf(0.01,(origem.global_transform*origem.get_bone_global_rest(quadril_fonte).origin).y)
    player.play(nome_fonte,0.0)
    player.speed_scale=0
    var correcao_vertical_rm := 0.0
    if nome.ends_with("_RM"):
        player.seek(0.0,true)
        var inicio := (origem.global_basis*origem.get_bone_global_pose(quadril_fonte).origin).y
        player.seek(fonte.length,true)
        var fim := (origem.global_basis*origem.get_bone_global_pose(quadril_fonte).origin).y
        correcao_vertical_rm=(fim-inicio)*proporcao
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
            if espelhar:
                var reflexao := Basis.from_scale(Vector3(-1,1,1))
                delta_rotacao=reflexao*delta_rotacao*reflexao
            desejadas[osso]=base_alvo.inverse()*delta_rotacao*repouso_alvo
        # Ordem hierárquica, independente dos índices (o rig original tem filhos antes dos pais).
        aplicar_poses(-1,desejadas)
        for par in pares:
            var osso: int=par[0]
            animacao.rotation_track_insert_key(trilhas[osso],tempo,alvo.get_bone_pose_rotation(osso))
        if trilha_pos>=0:
            var delta := origem.global_basis*(origem.get_bone_global_pose(quadril_fonte).origin-origem.get_bone_global_rest(quadril_fonte).origin)*proporcao
            if not nome.ends_with("_RM"): delta.x=0; delta.z=0
            else: delta.y-=correcao_vertical_rm*tempo/maxf(fonte.length,0.001)
            animacao.position_track_insert_key(trilha_pos,tempo,alvo.get_bone_rest(quadril).origin+base_alvo.inverse()*delta)
    var mao_direita := alvo.find_bone("DEF-hand.R")
    var prop_direita := origem.find_bone("B-handProp.R")
    if prop_direita>=0:
        var base_mao := base_alvo*alvo.get_bone_global_rest(mao_direita).basis.orthonormalized()
        var base_prop := base_origem*origem.get_bone_global_rest(prop_direita).basis.orthonormalized()
        if espelhar:
            var prop_esquerda := origem.find_bone("B-handProp.L")
            if prop_esquerda>=0:
                var reflexao := Basis.from_scale(Vector3(-1,1,1))
                base_prop=reflexao*(base_origem*origem.get_bone_global_rest(prop_esquerda).basis.orthonormalized())*reflexao
        animacao.set_meta("rotacao_arma",(base_mao.inverse()*base_prop).get_rotation_quaternion())
    biblioteca.add_animation(nome,animacao)
    relatorio.append({"nome":nome,"arquivo":arquivo.trim_prefix(pasta+"/"),"duracao":fonte.length,"ossos":pares.size(),"mascara":mascarada,"correcao_vertical_rm":correcao_vertical_rm})
    print("IMPORTADO ",nome," ",fonte.length,"s")
    cena.queue_free()
    await process_frame
func aplicar_poses(pai: int,desejadas: Dictionary):
    var filhos := alvo.get_parentless_bones() if pai<0 else alvo.get_bone_children(pai)
    for osso in filhos:
        if desejadas.has(osso):
            var base_pai := Basis.IDENTITY if pai<0 else alvo.get_bone_global_pose(pai).basis.orthonormalized()
            alvo.set_bone_pose_rotation(osso,(base_pai.inverse()*desejadas[osso]).get_rotation_quaternion())
        aplicar_poses(osso,desejadas)
