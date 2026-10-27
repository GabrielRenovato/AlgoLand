extends SceneTree
## Renderiza o ciclo transferido no rig final e exercita a troca corrida/repouso.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/"
var ultima_pose: Dictionary={}
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    for i in 6: await process_frame
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    j.set_physics_process(false)
    h.set_process(false)
    h._esqueleto.skeleton_updated.connect(func():
        ultima_pose={}
        for nome in ["DEF-hips","DEF-foot.L","DEF-foot.R","DEF-toe.L","DEF-toe.R","DEF-hand.L","DEF-hand.R"]:
            var t: Transform3D=h._modelo.global_transform.affine_inverse()*h._esqueleto.global_transform*h._esqueleto.get_bone_global_pose(h._esqueleto.find_bone(nome))
            ultima_pose[nome]=[t.origin.x,t.origin.y,t.origin.z]
    )
    var registros: Array=[]
    var duracao: float=h._player.get_animation("mixamo/Running").length
    assert(absf(duracao-.7)<.001)
    for direcao in 8:
        var dir:=Vector2.from_angle(PI/2-direcao*PI/4)
        j.velocity=dir*114
        h._process(0)
        assert(h._acao=="correr" and h._player.assigned_animation=="mixamo/Running")
        assert(absf(angle_difference(h._modelo.rotation.y,atan2(dir.x,dir.y)))<.001)
        h._player.play("mixamo/Running",0.0) # Amostragem sem congelar a mistura de entrada.
        h._player.speed_scale=0
        for q in 24:
            h._player.seek(duracao*q/24.0,true)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            var imagem: Image=h._vp.get_texture().get_image()
            var limites:=imagem.get_used_rect()
            assert(limites.position.x>0 and limites.position.y>0 and limites.end.x<imagem.get_width() and limites.end.y<imagem.get_height(),"Pose cortada pelo viewport")
            imagem.save_png(SAIDA+"corrida_%d_%02d.png" % [direcao,q])
            registros.append({"direcao":direcao,"q":q,"tempo":duracao*q/24.0,"ossos":ultima_pose.duplicate(true)})
            if direcao==2 and q==6: root.get_texture().get_image().save_png(SAIDA+"no_jogo.png")
        j.velocity=Vector2.ZERO
        h._process(0)
        assert(h._acao=="parado" and h._player.assigned_animation=="mixamo/Idle")
        h._player.seek(.2,true)
        await RenderingServer.frame_post_draw
        await RenderingServer.frame_post_draw
        h._vp.get_texture().get_image().save_png(SAIDA+"parado_%d.png" % direcao)
    var alternancia: Array[float]=[]
    for pose in registros:
        if pose.direcao==0: alternancia.append(pose.ossos["DEF-foot.L"][2]-pose.ossos["DEF-foot.R"][2])
    assert(alternancia.min()<-.10 and alternancia.max()>.10,"Corrida deve alternar as duas pernas")
    FileAccess.open(SAIDA+"poses.json",FileAccess.WRITE).store_string(JSON.stringify(registros))
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"clipe":duracao,"ciclo_no_jogo":h.PASSADA/114.0,"passada":h.PASSADA,"velocidade":114,"amostras":24},"  "))
    current_scene.queue_free()
    for i in 3: await process_frame
    print("CORRIDA MIXAMO: 192 poses, oito direções, ciclo, troca para repouso e margens OK")
    quit()
