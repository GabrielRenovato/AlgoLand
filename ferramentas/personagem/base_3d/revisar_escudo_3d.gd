extends SceneTree
## Poses de defesa e escudada no modelo final, com o filtro real do jogo.
const SAIDA := "res://arte/previas/personagens/base_3d/escudo_madeira/"
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
    var inv=root.get_node("InventarioJogador")
    inv.limpar();inv.criar_itens_iniciais()
    inv.equipar(inv.buscar_por_tipo("espada_basica"))
    inv.equipar(inv.buscar_por_tipo("escudo_basico"))
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    for i in 8: await process_frame
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    j.set_physics_process(false)
    j.modo_fazenda=false
    j.velocity=Vector2.ZERO
    h.set_process(false)
    var d=j.defesa
    var vp:=SubViewport.new()
    vp.size=h._vp.size
    vp.transparent_bg=true
    vp.world_2d=World2D.new()
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=h._vp.get_texture()
    sprite.material=h._sprite.material
    sprite.texture_filter=h._sprite.texture_filter
    vp.add_child(sprite)
    var tempos: Array=[0.0,0.025,0.05,0.075,0.10,0.12,0.20,0.40,0.80]
    for direcao in 4:
        var dir: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        j._direcao_ataque=dir
        d.direcao_guarda=dir
        d.estado=d.Estado.LIVRE
        h._process(0)
        h._player.play("Idle_Loop",0);h._player.speed_scale=0;h._player.seek(0,true)
        await RenderingServer.frame_post_draw
        await RenderingServer.frame_post_draw
        vp.get_texture().get_image().save_png(SAIDA+"costas_%d.png" % direcao)
        d.estado=d.Estado.GUARDA
        for q in tempos.size():
            h._pose_guarda.tempo_de_revisao=tempos[q]
            h._process(0)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            vp.get_texture().get_image().save_png(SAIDA+"erguer_%d_%02d.png" % [direcao,q])
        vp.get_texture().get_image().save_png(SAIDA+"guarda_%d.png" % direcao)
        d.estado=d.Estado.ESCUDADA
        d._indice=0;d._tempo=0
        for q in 12:
            h._process(0)
            h._player.seek(h._player.get_animation(h._nome_animacao("escudada")).length*q/12.0,true)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            vp.get_texture().get_image().save_png(SAIDA+"escudada_%d_%02d.png" % [direcao,q])
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"erguer":tempos,"escudada":0.50,"fases_escudada":12},"  "))
    print("ESCUDO REVISÃO: quatro direções, 36 fases de erguer e 48 de escudada; madeira e equipamento reais")
    quit()
