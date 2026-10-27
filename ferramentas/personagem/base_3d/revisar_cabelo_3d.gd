extends SceneTree
## Amostra os tempos reais do controlador, inclusive o frame do impacto.
const SAIDA := "res://arte/previas/personagens/base_3d/cabelo/"
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
    j.cancelar_acao_fazenda()
    j.velocity=Vector2.ZERO
    var pasta: String="res://arte/previas/personagens/base_3d/cabelo/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
    for pixel in [false,true]:
        h.acabamento_pixel_art=pixel
        vp.size=h._vp.size
        sprite.material=h._sprite.material
        sprite.texture_filter=h._sprite.texture_filter
        for cabelo in [false,true]:
            h.pecas_visiveis=15 if cabelo else 7
            for direcao in 4:
                j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
                h._process(0)
                h._player.pause()
                h._player.seek(0,true)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                vp.get_texture().get_image().save_png(pasta+"%s_%s_%d.png" % ["pixel" if pixel else "suave","cabelo" if cabelo else "rosto",direcao])
    print("CABELO: 4 direções, com/sem cabelo, dois acabamentos; pose e câmera comuns")
    quit()
