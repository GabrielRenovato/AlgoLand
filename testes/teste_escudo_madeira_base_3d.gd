extends SceneTree
## Escudo no equipamento real: costas, guarda, aparo perfeito e contra-ataque.
const SAIDA := "res://arte/previas/personagens/base_3d/escudo_madeira/"
var falhas:=0
var verificacoes:=0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool,mensagem: String):
    verificacoes+=1
    if not ok: falhas+=1; push_error(mensagem)
func esperar(n: int):
    for i in n: await process_frame
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var inv=root.get_node("InventarioJogador")
    inv.limpar();inv.criar_itens_iniciais()
    inv.equipar(inv.buscar_por_tipo("espada_basica"))
    inv.equipar(inv.buscar_por_tipo("escudo_basico"))
    await esperar(5)
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    await esperar(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    j.modo_fazenda=false
    j._sem_acao_ate_ms=0
    var d=j.defesa
    conferir(j.usando_espada and j.usando_escudo,"Espada de uma mão e escudo equipados")
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
    var mochila=inv.fotografar_mochila()
    for direcao in 4:
        var dir: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        j._direcao_ataque=dir
        await esperar(4)
        conferir(h._escudo.visible and h._escudo.get_parent()==h._costas and h._espada.get_parent()==h._costas,"Espada e escudo guardados nas costas")
        await RenderingServer.frame_post_draw
        vp.get_texture().get_image().save_png(SAIDA+"mecanica_costas_%d.png" % direcao)
        await create_timer(0.35).timeout
        j._sem_acao_ate_ms=0
        j.stamina=j.stamina_maxima
        Input.action_press(j.acao("aparar"))
        for i in 4: await physics_frame
        await esperar(2)
        conferir(d.em_guarda() and h.visible and h._acao=="guarda","Aparo mantém o personagem 3D")
        conferir(h._escudo.visible and h._escudo.get_parent()==h._mao_esquerda,"Aparo levanta o mesmo escudo no braço esquerdo")
        conferir(h._espada.get_parent()==h._mao,"Espada permanece na mão direita")
        conferir(j.stamina<j.stamina_maxima,"Aparo mantém o custo de estamina")
        await RenderingServer.frame_post_draw
        vp.get_texture().get_image().save_png(SAIDA+"mecanica_guarda_%d.png" % direcao)
        if direcao==0:
            var vida: int=j.hp_atual
            d._inicio_guarda_ms=Time.get_ticks_msec()
            j.invulneravel=false
            j.receber_dano(10,-dir*100)
            conferir(j.hp_atual==vida and d.estado==d.Estado.CONTRA,"Parry frontal evita dano e inicia contra-ataque")
            await create_timer(0.18).timeout
            conferir(d.escudando() and h._acao=="escudada" and h._escudo.visible,"Contra-ataque usa a escudada 3D com o escudo de madeira")
            await RenderingServer.frame_post_draw
            vp.get_texture().get_image().save_png(SAIDA+"mecanica_escudada.png")
            Input.action_release(j.acao("aparar"))
            await create_timer(0.65).timeout
        else:
            Input.action_release(j.acao("aparar"))
            await esperar(5)
        conferir(h._escudo.get_parent()==h._costas and h._escudo.visible,"Escudo volta às costas ao terminar a defesa")
    # Verifica a animação mais lenta sem editar a velocidade física.
    j.set_physics_process(false)
    j.velocity=Vector2.RIGHT*100.0
    h._process(0)
    var duracao: float=h._player.get_animation(h._nome_animacao("correr")).length
    conferir(is_equal_approx(h._player.speed_scale,100.0/h.PASSADA*duracao),"Cadência da corrida acompanha a passada calibrada")
    conferir(j.velocity==Vector2.RIGHT*100.0,"Velocidade física preservada")
    conferir(inv.fotografar_mochila()==mochila,"Defesa não altera inventário")
    print("ESCUDO MADEIRA 3D: ",verificacoes," verificações, ",falhas," falhas; costas, quatro direções, parry, escudada e corrida")
    quit(1 if falhas else 0)
