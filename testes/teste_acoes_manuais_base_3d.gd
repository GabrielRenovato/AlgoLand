extends SceneTree
## Verifica o cabo realmente desenhado, o alcance e o apoio durante o gesto próprio.
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    root.get_node("Introducao").pular_prologo()
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
    var erro_maos:=0.0
    var erro_pes:=0.0
    for acao in ["plantar"]:
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            var dados: Dictionary=j.no_fazenda.ACOES[acao]
            var total:=0.0
            for quadro in dados.quadros: total+=quadro[1]
            for q in 35:
                j.cancelar_acao_fazenda()
                j.acao_fazenda(acao)
                var t: float=total*q/35.0
                while t>=j.no_fazenda._quadros[j.no_fazenda._indice][1]:
                    t-=j.no_fazenda._quadros[j.no_fazenda._indice][1]
                    j.no_fazenda._indice+=1
                j.no_fazenda._tempo=t
                j.no_fazenda._impacto_emitido=j.no_fazenda._indice>=dados.quadro_impacto
                h._process(0.0)
                await RenderingServer.frame_post_draw
                var m=h._acoes_manuais
                assert(m.erro_maos<0.004,"Braço fora do alcance: "+acao)
                assert(m.erro_pes<0.012,"Pé deslizou: "+acao)
                erro_maos=maxf(erro_maos,m.erro_maos)
                erro_pes=maxf(erro_pes,m.erro_pes)
                assert(h._player.assigned_animation=="Idle_Loop","Gesto não pode herdar o corte importado")
                amostras+=1
    j.cancelar_acao_fazenda()
    h._process(0)
    await RenderingServer.frame_post_draw
    assert(h._acao=="parado" and not h._ferramentas.visible)
    print("AÇÕES PRÓPRIAS: ",amostras," amostras, 4 direções; cabo, duas mãos, pés e cancelamento OK; erros máximos mãos=",erro_maos," pés=",erro_pes)
    quit()
