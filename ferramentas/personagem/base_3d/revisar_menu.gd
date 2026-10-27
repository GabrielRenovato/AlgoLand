extends SceneTree
func _initialize():
    rodar.call_deferred()
func esperar(n: int):
    for i in n:await process_frame
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    root.mode = Window.MODE_WINDOWED
    root.get_node("Introducao").pular_prologo()
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var painel = root.get_node("PainelDebug")
    var opcoes: Array=painel._opcoes["PERSONAGEM"]
    var entradas_3d:=0
    for opcao in opcoes:
        if opcao[0].contains("3D"): entradas_3d+=1
    assert(entradas_3d==1,"F3 deve ter somente uma versão 3D")
    assert(opcoes[3][0]=="PERSONAGEM 3D: COMPLETO")
    opcoes[3][1].call()
    await esperar(3)
    var h=current_scene.get_node("Jogador/HeroiBase3D")
    assert(h.pecas_visiveis==15 and h.acabamento_pixel_art and not h.demonstrar_combate_na_fazenda)
    painel._area.select(2)
    painel._selecionar_area(2)
    painel._categoria.select(0)
    painel._selecionar_categoria(0)
    var acao := 3
    painel._acao.select(acao)
    painel._selecionar_acao(acao)
    painel._painel.show()
    for tamanho in [Vector2i(576,360),Vector2i(288,512)]:
        root.content_scale_size = tamanho
        root.size = tamanho*2
        await esperar(8)
        painel._ajustar_altura()
        await esperar(3)
        var caixa: Rect2 = painel._painel.get_global_rect()
        assert(Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(caixa))
        assert(caixa.grow(-10).encloses(painel._acao.get_global_rect()))
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://arte/previas/personagens/base_3d/f3_completo_%dx%d.png" % [tamanho.x,tamanho.y])
    print("MENU BASE 3D: margens verificadas em desktop e celular.")
    quit()
