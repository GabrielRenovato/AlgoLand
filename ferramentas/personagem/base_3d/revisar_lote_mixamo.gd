extends SceneTree
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/lote/"
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
    h._pose_guarda.active=false
    var inv=j.inventario
    var montante=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
    inv.mochila[23]=montante
    var registros: Array=[]
    var pontos: Array=[]
    h._esqueleto.skeleton_updated.connect(func():
        pontos.clear()
        for nome in ["DEF-hand.R","DEF-hand.L","DEF-foot.R","DEF-foot.L"]:
            var t: Transform3D=h._modelo.global_transform.affine_inverse()*h._esqueleto.global_transform*h._esqueleto.get_bone_global_pose(h._esqueleto.find_bone(nome))
            pontos.append([t.origin.x,t.origin.y,t.origin.z])
    )
    var biblioteca: AnimationLibrary=h._player.get_animation_library("mixamo")
    var clipes: Array=["Idle","SwordSlashA","SwordSlashB","SwordBlockIdle","TwoHandCombo","FishingCast","FishingIdle"]
    if "--novos" in OS.get_cmdline_user_args(): clipes=["BowDraw","AxeHorizontal"]
    if "--espadão" in OS.get_cmdline_user_args(): clipes=["GreatSwordSlash","GreatSwordJumpAttack"]
    for id in clipes:
        inv.equipar(montante if id in ["TwoHandCombo","GreatSwordSlash","GreatSwordJumpAttack"] else inv.buscar_por_tipo("espada_basica"))
        for i in 3: await process_frame
        var a: Animation=biblioteca.get_animation(id)
        for direcao in 4:
            h._modelo.rotation.y=[0.0,PI/2,PI,-PI/2][direcao]
            h._acao="pesca" if id.begins_with("Fishing") else ("guarda" if id=="SwordBlockIdle" else ("parado" if id=="Idle" else "espada"))
            h._encaixar_espada(h._acao in ["guarda","espada"])
            if h._acao in ["guarda","espada"] and id not in ["TwoHandCombo","GreatSwordSlash","GreatSwordJumpAttack"]: h._espada.quaternion=a.get_meta("rotacao_arma",Quaternion.IDENTITY)
            h._player.play("mixamo/"+id,0)
            h._player.speed_scale=0
            for q in 32:
                var tempo: float=a.length*q/31.0
                h._player.seek(tempo,true)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                h._vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%02d.png" % [id,direcao,q])
                if direcao==1: registros.append({"id":id,"q":q,"tempo":tempo,"pontos":pontos.duplicate(true)})
    FileAccess.open(SAIDA+"movimento.json",FileAccess.WRITE).store_string(JSON.stringify(registros))
    print("LOTE MIXAMO: ",clipes.size()," clipes, 4 direções, 32 amostras com as armas reais")
    current_scene.queue_free()
    for i in 3: await process_frame
    quit()
