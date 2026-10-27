extends SceneTree
const SAIDA := "res://arte/previas/personagens/base_3d/oito_direcoes/"
var falhas:=0
var verificacoes:=0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,msg: String):
    verificacoes+=1
    if not ok:falhas+=1;push_error(msg)
func esperar(n: int):
    for i in n:await process_frame
func foto(vp: SubViewport,nome: String):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    vp.get_texture().get_image().save_png(SAIDA+nome+".png")
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var inv=root.get_node("InventarioJogador")
    inv.limpar();inv.criar_itens_iniciais()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    await esperar(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    j.set_physics_process(false)
    j.no_fazenda.set_process(false)
    h.set_process(false)
    h._empunhadura_lanca.amostragem_automatica=false
    var mochila: Array=inv.fotografar_mochila()
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
    for direcao in 8:
        var dir:=Vector2.from_angle(PI/2-direcao*PI/4)
        var yaw:=atan2(dir.x,dir.y)
        j._direcao_ataque=dir
        conferir(j.direcao_da_acao(dir).is_equal_approx(dir),"Mira em oito direções")
        # Corrida e repouso mantêm a mesma orientação; a física não ganha velocidade.
        for andando in [false,true]:
            j.velocity=dir*100 if andando else Vector2.ZERO
            h._process(0)
            h._player.play(h._nome_animacao("correr" if andando else "parado"),0)
            h._player.speed_scale=0
            h._player.seek(h._player.get_animation(h._nome_animacao("correr")).length*.25 if andando else 0,true)
            conferir(absf(angle_difference(h._modelo.rotation.y,yaw))<0.001,"Giro da locomoção")
            await foto(vp,("corrida" if andando else "parado")+"_%d" % direcao)
        j.velocity=Vector2.ZERO
        j._apontar_golpe()
        conferir(j._direcao_golpe_3d.is_equal_approx(dir),"Ataque conserva direção diagonal")
        conferir(absf(angle_difference(j.get_node("AreaAtaque").rotation+j._cardinal_anterior.angle(),dir.angle()))<0.001,"Área de acerto acompanha a diagonal")
        # Executa a mesma entrada de ataque do combate e amostra seu meio.
        j.modo_fazenda=false
        j._fase_combo=1
        j.iniciar_slash_ataque("AtaqueEspadaSlash_1",.38)
        h._process(0)
        h._player.seek(h.COMBO.DURACOES[0]*.45,true)
        conferir(absf(angle_difference(h._modelo.rotation.y,yaw))<0.001,"Giro do ataque")
        # Mudar a mira durante o golpe não separa a lâmina da área de dano.
        j._direcao_ataque=-dir
        h._process(0)
        conferir(absf(angle_difference(h._modelo.rotation.y,yaw))<0.001,"Golpe mantém direção até terminar")
        await foto(vp,"espada_%d" % direcao)
        j._cancelar_golpe()
        conferir(is_zero_approx(j.get_node("AreaAtaque").rotation),"Cancelar restaura rotação da área")
        j._direcao_ataque=dir
        j.defesa.estado=j.defesa.Estado.GUARDA
        j.defesa.direcao_guarda=j.defesa._cardinal(dir)
        h._pose_guarda.tempo_de_revisao=.20
        h._process(0)
        conferir(j.defesa.direcao_guarda.is_equal_approx(dir),"Escudo protege na diagonal")
        conferir(absf(angle_difference(h._modelo.rotation.y,yaw))<0.001,"Giro da guarda")
        await foto(vp,"guarda_%d" % direcao)
        j.defesa.cancelar()
        h._pose_guarda.tempo_de_revisao=-1
        j.modo_fazenda=true
        var esperado: Vector2=j.global_position+Vector2(0,preload("res://codigo/globais/profundidade.gd").PES_JOGADOR)+dir*j.ALCANCE_ACAO_FAZENDA
        conferir(j.ponto_acao_fazenda().distance_to(esperado)<.001,"Alvo real da ferramenta segue a diagonal")
        for acao in ["regar","plantar","machado","colher"]:
            j.cancelar_acao_fazenda()
            conferir(j.acao_fazenda(acao),"Inicia ação da fazenda")
            var dados: Dictionary=j.no_fazenda.ACOES[acao]
            j.no_fazenda._indice=dados.quadro_impacto
            j.no_fazenda._tempo=0
            j.no_fazenda._impacto_emitido=true
            h._process(0)
            conferir(absf(angle_difference(h._modelo.rotation.y,yaw))<0.001,"Giro da ferramenta")
            var alvo3: Vector3=h._modelo.to_global(h.destino_ferramenta_3d())
            var projetado: Vector2=(h._camera.unproject_position(alvo3)-h._camera.unproject_position(Vector3.ZERO))/2.0
            conferir(projetado.distance_to(dir*j.ALCANCE_ACAO_FAZENDA)<.01,"Efeito e alvo usam a mesma direção")
            await foto(vp,"%s_%d" % [acao,direcao])
        j.cancelar_acao_fazenda()
    conferir(inv.fotografar_mochila()==mochila,"Revisão preserva inventário")
    # Raven conserva o comportamento cardinal anterior quando o 3D é removido.
    j.remove_child(h)
    conferir(not j.usa_oito_direcoes(),"Oito direções restritas ao modelo 3D")
    conferir(is_zero_approx(j.direcao_da_acao(Vector2.ONE).x) or is_zero_approx(j.direcao_da_acao(Vector2.ONE).y),"Raven mantém quatro direções")
    h.free()
    print("OITO DIREÇÕES 3D: ",verificacoes," verificações, ",falhas," falhas; 64 renders, locomoção, combate, defesa, ferramentas e fallback")
    quit(1 if falhas else 0)
