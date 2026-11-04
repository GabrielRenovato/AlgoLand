extends "res://ferramentas/personagem/base_3d/importar_melee.gd"
## Transferência de poses do Schoolkid CC0; somente clips, sem trocar nosso corpo.
const MAPA_INFANTIL={"DEF-hips":"ahn3vx","DEF-spine.001":"fajheg","DEF-neck":"ekp3jr","DEF-head":"ape5q7","DEF-upper_arm.L":"kgt65p","DEF-forearm.L":"mu2k44","DEF-upper_arm.R":"e5zhbk","DEF-forearm.R":"cpjt9b","DEF-thigh.L":"jtgqkt","DEF-shin.L":"ddr7xp","DEF-thigh.R":"meax35","DEF-shin.R":"facug3"}
func mapa(nome: String) -> String:return MAPA_INFANTIL.get(nome,"")
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var fonte:=ProjectSettings.globalize_path("res://arte/fontes/personagens/base_3d/movimentos_infantis/Schoolkid-compativel.glb")
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--fonte="):fonte=a.trim_prefix("--fonte=")
    cena_alvo=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
    root.add_child(cena_alvo)
    alvo=cena_alvo.find_children("*","Skeleton3D",true,false)[0]
    for m in alvo.find_children("*","SkeletonModifier3D",true,false):m.active=false
    await importar(fonte,fonte.get_base_dir(),false,"Walk","Caminhada_Infantil")
    await importar(fonte,fonte.get_base_dir(),false,"Idle","Descanso_Infantil")
    biblioteca.set_meta("passada_infantil_px",medir_passada_infantil())
    biblioteca.set_meta("autor","Gobkit")
    biblioteca.set_meta("fonte","https://gobkit.itch.io/gobkit-free-character-pack-vol-1")
    biblioteca.set_meta("licenca","CC0 1.0")
    assert(ResourceSaver.save(biblioteca,"res://assets/personagens/base_3d/movimentos_infantis.res",ResourceSaver.FLAG_COMPRESS)==OK)
    print("MOVIMENTOS INFANTIS: ",relatorio)
    cena_alvo.free()
    quit()
func importar(arquivo: String,pasta: String,espelhar: bool = false,clipe_fonte: String="Walk",destino: String="Caminhada_Infantil"):
    
    var doc = ClassDB.instantiate("GLTFDocument")
    var estado = ClassDB.instantiate("GLTFState")
    assert(doc.append_from_file(arquivo,estado)==OK)
    var cena = doc.generate_scene(estado)
    root.add_child(cena)
    var origem: Skeleton3D = cena.find_children("*","Skeleton3D",true,false)[0]
    var player: AnimationPlayer = cena.find_children("*","AnimationPlayer",true,false)[0]
    var nome_fonte := clipe_fonte
    var fonte := player.get_animation(nome_fonte)
    var animacao := Animation.new()
    animacao.length=fonte.length
    var nome := destino
    if espelhar: nome += "_Espelhado"
    var mascarada := arquivo.contains("Masked Poses")
    var movimento := arquivo.contains("Movement/")
    animacao.loop_mode=Animation.LOOP_LINEAR
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
    var quadril_fonte := origem.find_bone("ahn3vx")
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
        # A fonte mantém braços abertos. Baixa o repouso dos braços sem mexer
        # nas oscilações amostradas, nem na aparência do manequim.
        for lado in ["L","R"]:
            var correcao:=Basis(Vector3.BACK,-.80 if lado=="L" else .80)
            for segmento in ["upper_arm","forearm"]:
                var osso_braco:=alvo.find_bone("DEF-%s.%s" % [segmento,lado])
                desejadas[osso_braco]=correcao*desejadas[osso_braco]
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

func medir_passada_infantil() -> float:
    var player:AnimationPlayer=cena_alvo.find_children("*","AnimationPlayer",true,false)[0]
    player.add_animation_library("infantis",biblioteca)
    var proporcao=load("res://codigo/npcs/proporcao_infantil_3d.gd").new()
    alvo.add_child(proporcao);proporcao.active=false
    var duracao:float=biblioteca.get_animation("Caminhada_Infantil").length
    var amostras:=ceili(duracao*120)
    var pes:Array=[[],[]]
    for q in amostras:
        alvo.reset_bone_poses()
        player.play("infantis/Caminhada_Infantil",0);player.speed_scale=0
        player.seek(duracao*q/amostras,true)
        proporcao._aplicar()
        for i in 2:pes[i].append(alvo.get_bone_global_pose(alvo.find_bone("DEF-foot."+["L","R"][i])).origin*.8)
    var velocidades:Array[float]=[]
    for pontos in pes:
        var piso:float=pontos.map(func(p):return p.y).min()
        for i in range(1,pontos.size()):
            if pontos[i].y>piso+.018 or pontos[i-1].y>piso+.018:continue
            var velocidade:float=-(pontos[i].z-pontos[i-1].z)/(duracao/amostras)
            if velocidade>.01:velocidades.append(velocidade)
    assert(not velocidades.is_empty(),"Sem apoio para medir passada infantil")
    velocidades.sort()
    var passada:float=velocidades[velocidades.size()/2]*duracao*20.0
    assert(passada>1 and passada<40)
    print("PASSADA INFANTIL: ",passada)
    return passada
