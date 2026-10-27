extends SceneTree
## Comparação real do render atual com o teste pixelizado. Não grava o save do usuário.
const SAIDA := "res://arte/previas/personagens/base_3d/teste_pixel_art/"
func _initialize():rodar.call_deferred()
func esperar(n: int):
    for i in n:await process_frame
func foto(vp: SubViewport,nome: String):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var im := vp.get_texture().get_image()
    assert(im.save_png(SAIDA+nome+".png")==OK)
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var painel=root.get_node("PainelDebug")
    painel._ativar_base_3d(true,false)
    await esperar(6)
    var heroi=current_scene.get_node("Jogador/HeroiBase3D")
    var mochila=current_scene.get_node("Jogador").inventario.fotografar_mochila()
    var ancora: Vector2=heroi._sprite.offset/8.0
    var duracao: float=heroi._player.get_animation(heroi._nome_animacao("correr")).length
    heroi.set_process(false)
    heroi._espada.visible=false
    for pixel in [false,true]:
        var nome := "pixel" if pixel else "suave"
        heroi.acabamento_pixel_art=pixel
        assert(heroi._sprite.offset/(2.0 if pixel else 8.0)==ancora)
        assert(heroi._vp.size==Vector2i(160,160) if pixel else heroi._vp.size==Vector2i(640,640))
        assert(heroi._sprite.material!=null if pixel else heroi._sprite.material==null)
        # Renderiza o mesmo material do Sprite2D em viewport transparente para exportar
        # o resultado processado, além de capturar a reprodução real sobre o mapa.
        var vp := SubViewport.new()
        vp.size=heroi._vp.size
        vp.transparent_bg=true
        vp.world_2d=World2D.new()
        vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        root.add_child(vp)
        var sprite := Sprite2D.new()
        sprite.centered=false
        sprite.texture=heroi._vp.get_texture()
        sprite.texture_filter=heroi._sprite.texture_filter
        sprite.material=heroi._sprite.material
        vp.add_child(sprite)
        for direcao in 4:
            heroi._modelo.rotation.y=[0.0,PI/2.0,PI,-PI/2.0][direcao]
            heroi._player.play("Idle_Loop",0.0)
            heroi._player.seek(0,true)
            heroi._player.pause()
            await foto(vp,"%s_parado_%d" % [nome,direcao])
            if direcao==0:
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(SAIDA+nome+"_mapa.png")
            heroi._player.play(heroi._nome_animacao("correr"),0.0)
            for q in 12:
                heroi._player.seek(duracao*q/12.0,true)
                heroi._player.pause()
                await foto(vp,"%s_correr_%d_%02d" % [nome,direcao,q])
        vp.queue_free()
        await esperar(2)
    heroi.acabamento_pixel_art=false
    assert(heroi._vp.size==Vector2i(640,640) and heroi._sprite.material==null)
    assert(current_scene.get_node("Jogador").inventario.fotografar_mochila()==mochila)
    # F3 ativa pixel art por padrão; o modo suave continua disponível explicitamente.
    painel._ativar_base_3d(true)
    await esperar(3)
    heroi=current_scene.get_node("Jogador/HeroiBase3D")
    assert(heroi.acabamento_pixel_art and heroi._vp.size==Vector2i(160,160))
    painel._ativar_base_3d(true,false)
    await esperar(3)
    assert(not current_scene.get_node("Jogador/HeroiBase3D").acabamento_pixel_art)
    FileAccess.open(SAIDA+"revisao.json",FileAccess.WRITE).store_string(JSON.stringify({"duracao_corrida":duracao,"quadros":12,"direcoes":4,"modos":2,"save":OS.get_user_data_dir()},"  "))
    print("PIXEL 3D OK: 2 modos, 4 direções, 96 fases de corrida; pivô, reversão e inventário preservados.")
    quit()
