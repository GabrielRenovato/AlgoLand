extends SceneTree
## Confere encaixes das costas no rig real, com save isolado e filtro do jogo.
var saida := "/tmp/algoland-armas-costas/depois/"
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    if "--antes" in OS.get_cmdline_user_args(): saida=saida.replace("depois/","antes/")
    DirAccess.make_dir_recursive_absolute(saida)
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("Transicao").limpar()
    var jogador=current_scene.get_node("Jogador")
    var mochila=jogador.inventario.fotografar_mochila()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    for i in 6: await process_frame
    var h=jogador.get_node("HeroiBase3D")
    h.set_process(false)
    h._empunhadura_lanca.amostragem_automatica=false
    jogador.usando_espada=true
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
    for arma in 2:
        h.arma_demonstracao=arma
        h._acao="parado"
        h._encaixar_espada(false)
        for direcao in 4:
            h._modelo.rotation.y=[0.0,PI/2.0,PI,-PI/2.0][direcao]
            for q in 13:
                var nome: String="Idle_Loop" if q==0 else h._nome_animacao("correr")
                h._player.play(nome,0.0)
                h._player.speed_scale=0
                h._player.seek(0.0 if q==0 else h._player.get_animation(nome).length*(q-1)/12.0,true)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                var imagem:=vp.get_texture().get_image()
                imagem.save_png(saida+"%d_%d_%02d.png" % [arma,direcao,q])
                if direcao==0 and q==0:
                    var indice: int=h._esqueleto.find_bone(h.OSSO_COSTAS)
                    print("COSTAS ",h._costas.global_transform," REST ",h._esqueleto.get_bone_global_rest(indice))
                    var no: Node3D=h._espada if arma==0 else h._lanca
                    var modelo: Transform3D=h._modelo.global_transform.affine_inverse()*no.global_transform
                    print("ARMA ",arma," ENCAIXE ",modelo," EXTREMOS ",modelo*Vector3(0,-0.36 if arma else -0.12,0)," -> ",modelo*Vector3(0,1.04 if arma else 0.75,0))
    assert(jogador.inventario.fotografar_mochila()==mochila)
    print("COSTAS REVISÃO: 2 armas, 4 direções, parado e 12 fases de corrida; inventário preservado")
    quit()
