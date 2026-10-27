extends SceneTree
## Usa os controladores reais em save isolado, sem emitir impactos de revisão.
const SAIDA := "res://arte/previas/personagens/base_3d/ferramentas_kaykit/"
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
    j.set_physics_process(false)
    j.no_fazenda.set_process(false)
    var amostras:=0
    for acao in ["picareta","enxada"]:
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            j.acao_fazenda(acao)
            var c=j.no_fazenda
            for q in 24:
                var t: float=.68*q/24.0
                c._indice=0
                while t>=c._quadros[c._indice][1]:
                    t-=c._quadros[c._indice][1]
                    c._indice+=1
                c._tempo=t
                h._process(0)
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                assert(h._player.assigned_animation=="ferramentas/Pickaxing")
                assert(h._ferramentas._picareta.visible == (acao=="picareta"))
                assert(h._ferramentas._enxada.visible == (acao=="enxada"))
                capturar(h,acao,direcao,q)
                amostras+=1
            j.cancelar_acao_fazenda()
    j.global_position=current_scene.get_node("PescaLago").global_position
    var sessao=load("res://codigo/pesca/sessao_pesca.gd").new()
    sessao.iniciar(j,Vector2.DOWN,"lago",true)
    sessao.set_process(false)
    var anim=j.get_node("AnimacaoPesca")
    var estados=[sessao.Estado.CARREGANDO,sessao.Estado.LANCANDO,sessao.Estado.ESPERANDO,sessao.Estado.BELISCANDO,sessao.Estado.PUXANDO,sessao.Estado.PEGOU]
    var nomes=["preparar","lancar","esperar","beliscar","recolher","capturar"]
    var tempos=[.6,.55,2.333333,1.5,1.6,3.233333]
    for direcao in 4:
        sessao._frente=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        for fase in estados.size():
            sessao.estado=estados[fase]
            for q in 24:
                sessao._tempo=q/24.0*tempos[fase]
                anim.tensao=.4
                h._process(0)
                sessao.queue_redraw()
                await RenderingServer.frame_post_draw
                await RenderingServer.frame_post_draw
                assert(h._acao=="pesca" and h._ferramentas._vara.visible)
                assert(h._player.assigned_animation.begins_with("ferramentas/Fishing_") or h._player.assigned_animation.begins_with("mixamo/Fishing"))
                var mundo: Vector3=h._ferramentas._vara.to_global(h._ferramentas.PONTA_VARA)
                var esperado: Vector2=h.position+h._sprite.to_local(h._sprite.to_global(Vector2.ZERO))+(h._camera.unproject_position(mundo)+h._sprite.offset)*h._sprite.scale
                assert(anim.ponta().distance_to(esperado)<.001)
                if estado_linha_visivel(sessao):
                    assert(sessao._linha_3d.visible)
                    assert(sessao._linha_3d.points[0].distance_to(anim.ponta())<.001,"Linha separada da ponta da vara")
                    assert(sessao._linha_3d.points[-1].distance_to(sessao.posicao_boia())<=2.0,"Linha separada da boia")
                    assert(sessao._boia_3d.position.distance_to(sessao._linha_3d.points[-1])<.001)
                else:
                    assert(not sessao._linha_3d.visible)
                if q==12 and fase==4 and direcao==0:
                    root.get_texture().get_image().save_png(SAIDA+"no_jogo.png")
                capturar(h,nomes[fase],direcao,q)
                amostras+=1
    sessao._terminar()
    for i in 3: await process_frame
    h._process(0)
    await RenderingServer.frame_post_draw
    assert(h._acao=="parado" and not h._ferramentas.visible)
    # O sinal não pode acertar a pedra antes ou depois do contato desenhado.
    j.acao_fazenda("picareta")
    j.no_fazenda._indice=2
    j.no_fazenda._tempo=0
    h._process(0)
    assert(absf(h._player.current_animation_position-.31)<.002)
    j.cancelar_acao_fazenda()
    h._process(0)
    current_scene.queue_free()
    for i in 3: await process_frame
    print("KAYKIT 3D: ",amostras," amostras, 4 direções, clipes reais, equipamento, ponta projetada e cancelamento OK")
    quit()
func capturar(h: Node,nome: String,direcao: int,q: int):
    h._vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%02d.png" % [nome,direcao,q])

func estado_linha_visivel(sessao: Node) -> bool:
    return sessao.estado not in [sessao.Estado.CARREGANDO,sessao.Estado.PEGOU] and not (sessao.estado==sessao.Estado.LANCANDO and sessao._tempo<sessao.INICIO_ARREMESSO)
