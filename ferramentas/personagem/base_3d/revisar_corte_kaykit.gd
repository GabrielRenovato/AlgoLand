extends SceneTree
## Amostra os tempos reais do controlador, inclusive o frame do impacto.
const SAIDA := "/tmp/algoland-kaykit-corte/"
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
    h.set_process(false)
    h._empunhadura_lanca.amostragem_automatica=false
    j.set_physics_process(false)
    j.no_fazenda.set_process(false)
    var vp:=SubViewport.new()
    vp.size=h._vp.size
    vp.transparent_bg=true
    vp.world_2d=World2D.new()
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=h._vp.get_texture()
    sprite.texture_filter=h._sprite.texture_filter
    sprite.material=h._sprite.material
    vp.add_child(sprite)
    var biblioteca=load("res://assets/personagens/base_3d/kaykit_corte.res")
    h._player.add_animation_library("kaykit",biblioteca)
    for nome in ["fazenda/TreeChopping_Loop","kaykit/Chop","kaykit/Chopping"]:
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            for q in 16:
                j.cancelar_acao_fazenda()
                j.acao_fazenda("machado")
                h._process(0.0)
                h._player.play(nome,0)
                h._player.speed_scale=0
                h._player.seek(h._player.get_animation(nome).length*q/16.0,true)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%02d.png" % [nome.get_file(),direcao,q])
    print("CORTE KAYKIT: 3 clipes, 4 direções, 16 fases")
    quit()
