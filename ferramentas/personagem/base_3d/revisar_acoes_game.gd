extends SceneTree
## Amostra os tempos reais do controlador, inclusive o frame do impacto.
const SAIDA := "res://arte/previas/personagens/base_3d/acoes_game/"
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
    var duracoes: Dictionary={}
    var erros: Array=[]
    for acao in ["regar","plantar","colher","machado"]:
        var dados: Dictionary=j.no_fazenda.ACOES[acao]
        var total:=0.0
        for quadro in dados.quadros: total+=quadro[1]
        duracoes[acao]=total
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            for q in 12:
                j.cancelar_acao_fazenda()
                j.acao_fazenda(acao)
                # Reprodução de amostragem, sem emitir impactos no mapa de revisão.
                var tempo: float=total*q/12.0
                j.no_fazenda._indice=0
                while tempo>=j.no_fazenda._quadros[j.no_fazenda._indice][1]:
                    tempo-=j.no_fazenda._quadros[j.no_fazenda._indice][1]
                    j.no_fazenda._indice+=1
                j.no_fazenda._tempo=tempo
                j.no_fazenda._impacto_emitido=j.no_fazenda._indice>=dados.quadro_impacto
                h._tempo=total*q/12.0
                h._process(0.0)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%02d.png" % [acao,direcao,q])
                if acao in ["machado","plantar"]: erros.append({"acao":acao,"direcao":direcao,"quadro":q,"maos":h._acoes_manuais.erro_maos,"pes":h._acoes_manuais.erro_pes})
    j.cancelar_acao_fazenda()
    j.no_fazenda.set_process(true)
    for acao in ["sentar","sentado","avanco"]:
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            h._restante_levantar=0.0
            h._estava_sentado=false
            j.esta_em_dash=acao=="avanco"
            j.velocity=j._direcao_ataque*j.velocidade_dash if acao=="avanco" else Vector2.ZERO
            j.esta_sentado=acao in ["sentar","sentado"]
            j._frente_sentado=[1,0,-1,0][direcao]
            j._lado_sentado=-1 if direcao==3 else 1
            duracoes[acao]=h.TEMPO_SENTAR if acao=="sentar" else (0.8 if acao=="sentado" else j.duracao_dash)
            for q in 12:
                j._tempo_sentado=q/12.0*h.TEMPO_SENTAR if acao=="sentar" else 1.0
                h._process(0.0)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%02d.png" % [acao,direcao,q])
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(duracoes,"  "))
    FileAccess.open(SAIDA+"erros_pegas.json",FileAccess.WRITE).store_string(JSON.stringify(erros))
    print("AÇÕES GAME: 7 ações, 4 direções, 12 fases; renderização real com o filtro")
    quit()
