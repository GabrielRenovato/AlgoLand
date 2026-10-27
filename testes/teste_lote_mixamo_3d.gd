extends SceneTree
## Exercita as escolhas do controlador, equipamento e fases nas quatro vistas.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/aplicado/"
var amostras:=0
var disparos:=0
func _initialize(): rodar.call_deferred()
func quadros(n: int):
    for i in n: await process_frame
func foto(h: Node,nome: String,direcao: int,q: int):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var im: Image=h._vp.get_texture().get_image()
    var limites:=im.get_used_rect()
    assert(limites.position.x>0 and limites.position.y>0 and limites.end.x<im.get_width() and limites.end.y<im.get_height(),"Equipamento cortado: "+nome)
    im.save_png(SAIDA+"%s_%d_%02d.png" % [nome,direcao,q])
    amostras+=1
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await quadros(35)
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    await quadros(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    var inv=j.inventario
    j.set_physics_process(false)
    h.set_process(false)
    j.no_fazenda.set_process(false)
    j.no_arco.set_process(false)
    var fabrica=preload("res://codigo/dados/forja_armas.gd")
    var espada=inv.buscar_por_tipo("espada_basica")
    var montante=fabrica.criar_item("espada_gemea")
    var arco=fabrica.criar_item("arco_curto")
    inv.mochila[22]=montante
    inv.mochila[23]=arco
    for familia in ["espada","montante"]:
        assert(inv.equipar(montante if familia=="montante" else espada))
        await quadros(3)
        var combo=h.COMBO_MONTANTE if familia=="montante" else h.COMBO
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            for golpe in combo.NOMES.size():
                for q in 24:
                    h._demonstracao=true
                    h._golpe_demonstracao=golpe+1
                    h._direcao_demonstracao=j._direcao_ataque
                    h._tempo_demonstracao=combo.DURACOES[golpe]*q/24.0
                    h._process(0)
                    h._delta_rastro=combo.DURACOES[golpe]/48.0
                    assert(h._acao=="espada" and h._player.assigned_animation==combo.NOMES[golpe])
                    assert(str(h._player.get_animation(combo.NOMES[golpe]).get_meta("fonte")).begins_with("mixamo/"))
                    if q==0:h._player.play(combo.NOMES[golpe],0)
                    h._player.speed_scale=0
                    h._player.seek(combo.DURACOES[golpe]*q/24.0,true)
                    await foto(h,familia+"_%d" % (golpe+1),direcao,q)
                    assert(h._espada.visible)
                    if familia=="montante":
                        assert(not h._escudo.visible)
                        assert(h._empunhadura_lanca.erro_montante<.055,"Segunda mão fora do cabo")
        h._demonstracao=false
    assert(inv.equipar(espada))
    await quadros(3)
    for acao in ["idle","guarda","machado"]:
        for direcao in 4:
            j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
            if acao=="guarda":
                j.defesa.estado=j.defesa.Estado.GUARDA
                j.defesa.direcao_guarda=j._direcao_ataque
            elif acao=="machado":j.acao_fazenda("machado")
            for q in 24:
                if acao=="machado":
                    var t: float=.68*q/24.0
                    j.no_fazenda._indice=0
                    while t>=j.no_fazenda._quadros[j.no_fazenda._indice][1]:
                        t-=j.no_fazenda._quadros[j.no_fazenda._indice][1]
                        j.no_fazenda._indice+=1
                    j.no_fazenda._tempo=t
                h._process(0)
                var nome: String="mixamo/"+{"idle":"Idle","guarda":"SwordBlockIdle","machado":"AxeTreeChop"}[acao]
                assert(h._player.assigned_animation==nome)
                var instante: float=h._player.current_animation_position
                h._player.play(nome,0)
                h._player.speed_scale=0
                h._player.seek(instante if acao=="machado" else h._player.get_animation(nome).length*q/24.0,true)
                await foto(h,acao,direcao,q)
                if acao=="guarda":assert(h._escudo.visible and h._escudo.get_parent()==h._mao_esquerda)
                if acao=="machado":assert(h._ferramentas._machado.visible)
            j.defesa.cancelar()
            j.cancelar_acao_fazenda()
    var aljava=fabrica.criar_item("aljava_basica")
    inv.mochila[24]=aljava
    assert(inv.equipar(aljava))
    assert(inv.equipar(arco))
    j.modo_fazenda=false
    await quadros(3)
    for direcao in 4:
        var dir: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        j.no_arco.disparar(dir,1.0)
        for q in 24:
            var t: float=1.08*q/24.0
            j.no_arco._indice=0
            while t>=j.no_arco.DURACAO_DISPARO[j.no_arco._indice]:
                t-=j.no_arco.DURACAO_DISPARO[j.no_arco._indice]
                j.no_arco._indice+=1
            j.no_arco._tempo=t
            h._process(0)
            assert(h._acao=="arco" and h._player.assigned_animation=="mixamo/BowDraw")
            h._player.play("mixamo/BowDraw",0)
            h._player.speed_scale=0
            h._player.seek(minf(h.progresso_arco()/.40,1.0)*h._player.get_animation("mixamo/BowDraw").length,true)
            await foto(h,"arco",direcao,q)
            assert(h._arco_visual.visible)
            if h.progresso_arco()>.54: assert(h._pose_arco.erro_maos<.005,"Braço do arco fora do alcance")
            assert(h._arco_visual._flecha.visible==(j.no_arco._indice<j.no_arco.QUADRO_SOLTAR))
        j.no_arco.parar_disparo()
    # Reprodução normal: um sinal de soltura e o projétil original, com colisão intacta.
    j.no_arco.disparo_liberado.connect(func(_dir): disparos+=1)
    h.set_process(true)
    j.no_arco.visible=true
    j.no_arco.set_process(true)
    j._direcao_ataque=Vector2.DOWN
    j._iniciar_disparo()
    await create_timer(1.2).timeout
    assert(disparos==1 and not j.no_arco.esta_disparando())
    print("LOTE MIXAMO: ",amostras," poses; idle, guarda, 5 golpes, machado, arco/soltura, 4 direções OK")
    current_scene.queue_free()
    await quadros(3)
    quit()
