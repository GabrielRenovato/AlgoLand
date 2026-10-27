extends SceneTree
## Regressão focada na defesa do espadão; não percorre o catálogo de armas.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/bloqueio_montante/"
func _initialize(): rodar.call_deferred()
func esperar(n: int):
    for i in n: await process_frame
func botao(j: Node,pressionado: bool):
    var evento:=InputEventAction.new()
    evento.action=j.acao("aparar")
    evento.pressed=pressionado
    root.push_input(evento)
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    await esperar(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    var d=j.defesa
    var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
    j.inventario.mochila[23]=item
    assert(j.inventario.equipar(item))
    j.modo_fazenda=false
    await esperar(50)
    j._sem_acao_ate_ms=0
    assert(j.pode_aparar())
    botao(j,true)
    await esperar(5)
    assert(d.em_guarda() and h._acao=="guarda")
    assert(not j.usando_escudo and not h._escudo.visible)
    assert(h._player.assigned_animation=="mixamo/GreatSwordBlocking")
    await esperar(75) # Mantém a defesa para além do primeiro ciclo.
    assert(d.em_guarda() and h._acao=="guarda")
    botao(j,false)
    await esperar(5)
    assert(not d.em_guarda() and h._acao=="parado")
    j.set_physics_process(false)
    h.set_process(false)
    var duracao: float=h._player.get_animation("mixamo/GreatSwordBlocking").length
    var erro:=0.0
    for direcao in 4:
        var dir: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        j._direcao_ataque=dir
        d.estado=d.Estado.GUARDA
        d.direcao_guarda=dir
        h._process(0)
        for q in 24:
            h._tempo=h._inicio_acao+duracao*q/24.0
            h._process(0)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            assert(h._espada==h._montante and h._espada.get_parent()==h._modelo)
            assert(h._montante.visible and not h._escudo.visible)
            erro=maxf(erro,h._empunhadura_lanca.erro_montante)
            assert(h._empunhadura_lanca.erro_montante<.055,"Segunda mão fora do cabo")
            var im: Image=h._vp.get_texture().get_image()
            var limites:=im.get_used_rect()
            assert(limites.position.x>0 and limites.position.y>0 and limites.end.x<im.get_width() and limites.end.y<im.get_height())
            im.save_png(SAIDA+"guarda_%d_%02d.png" % [direcao,q])
    # Mantém as regras de aparo/bloqueio, sem tentar escudada com o espadão.
    j.stamina=j.stamina_maxima
    d._inicio_guarda_ms=Time.get_ticks_msec()-1000
    var resultado: Dictionary=d.resolver(10,-d.direcao_guarda*10)
    assert(resultado.get("tipo")=="bloqueio")
    d._inicio_guarda_ms=Time.get_ticks_msec()
    resultado=d.resolver(10,-d.direcao_guarda*10)
    assert(resultado.get("tipo")=="perfeito" and d.estado==d.Estado.GUARDA)
    d.cancelar()
    h._process(0)
    await RenderingServer.frame_post_draw
    assert(h._acao=="parado" and h._montante.get_parent()==h._costas)
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"duracao":duracao,"quadros":24,"direcoes":4}))
    print("BLOQUEIO ESPADÃO: entrada/soltura, 96 poses, quatro direções, duas mãos, bloqueio/aparo e retorno OK; erro do cabo=",erro)
    current_scene.queue_free()
    await esperar(3)
    quit()
