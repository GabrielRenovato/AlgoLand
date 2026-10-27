extends SceneTree
## Executa o comando de ataque na fazenda e no combate, com save isolado.
const SAIDA := "/tmp/algoland-ataque-base3d/"
var lanca := "--lanca" in OS.get_cmdline_user_args()
var montante := "--montante" in OS.get_cmdline_user_args()
var direcoes: Array=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
var falhas := 0
var verificacoes := 0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, mensagem: String):
    verificacoes += 1
    if not ok:
        falhas += 1
        push_error(mensagem)
func esperar(n: int):
    for i in n: await process_frame
func atacar(jogador: Node):
    var evento := InputEventAction.new()
    evento.action = jogador.acao("attack")
    evento.pressed = true
    root.push_input(evento)
    for i in 3: await physics_frame
    await esperar(2)
    evento = InputEventAction.new()
    evento.action = jogador.acao("attack")
    evento.pressed = false
    root.push_input(evento)
func rodar():
    if "--oito" in OS.get_cmdline_user_args():
        direcoes.clear()
        for i in 8: direcoes.append(Vector2.from_angle(PI/2-i*PI/4))
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name() != "headless")
    DirAccess.make_dir_recursive_absolute(SAIDA)
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva = 12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var jogador = current_scene.get_node("Jogador")
    var mochila = jogador.inventario.fotografar_mochila()
    root.get_node("PainelDebug")._ativar_base_3d(true,true,lanca)
    await esperar(6)
    var heroi = jogador.get_node("HeroiBase3D")
    if montante:
        var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
        jogador.inventario.mochila[23]=item
        conferir(jogador.inventario.equipar(item),"Espada de duas mãos equipa pelo inventário")
        await esperar(5)
        mochila=jogador.inventario.fotografar_mochila()
    heroi.demonstrar_combate_na_fazenda=true
    var combo = heroi.COMBO_MONTANTE if montante else (heroi.COMBO_LANCA if lanca else heroi.COMBO)
    var arma = heroi._lanca if lanca else heroi._espada
    var acao := "lanca" if lanca else "espada"
    if montante:
        for nome in combo.NOMES:
            conferir(heroi._player.get_animation(nome).get_meta("familia","")=="duas_maos","Montante usa os clipes 2H do pacote")
    conferir(heroi._nome_animacao("parado")=="mixamo/Idle" and heroi._nome_animacao("correr")=="mixamo/Running","Repouso e corrida Mixamo selecionados")
    conferir(heroi._nome_animacao("ferido")=="Hit_Chest" and heroi._nome_animacao("morrer")=="Death01" and heroi._nome_animacao("avanco")=="Jog_Fwd_Loop","Ferido e morte preservados, avanço sem rolamento")
    if not lanca:
        for nome in heroi.COMBO.NOMES:
            conferir(heroi._player.get_animation(nome).get_meta("familia","")=="um_mao" and heroi._player.get_animation(nome).get_meta("tipo_golpe","")=="corte","Combo de uma mão usa os cortes Mixamo escolhidos")
    var pedidos := [0]
    jogador.ferramenta_pedida.connect(func(): pedidos[0] += 1)
    jogador._sem_acao_ate_ms = 0
    for direcao in direcoes:
        jogador._direcao_ataque = direcao
        await atacar(jogador)
        conferir(heroi._demonstracao and heroi._acao == acao, "Botão de ataque inicia demonstração 3D na fazenda")
        conferir(absf(angle_difference(heroi._modelo.rotation.y,atan2(direcao.x,direcao.y)))<0.001,"Modelo olha na direção do ataque, incluindo diagonais")
        conferir(not jogador._esta_atacando and not jogador.get_node("AreaAtaque").monitoring, "Demonstração não ativa dano")
        conferir(arma.visible and arma.get_parent() == (heroi._modelo if lanca or montante else heroi._mao), "Arma visível nas mãos")
        for golpe in combo.NOMES.size():
            conferir(heroi._golpe_demonstracao == golpe+1,"Demonstração encadeia cada fase na ordem")
            conferir(heroi._player.assigned_animation == combo.NOMES[golpe],"Cada golpe tem uma animação distinta")
            if golpe < combo.NOMES.size()-1: await atacar(jogador)
            var viu_rastro := false
            var q := 0
            var limite := Time.get_ticks_msec()+5000
            while heroi._demonstracao and heroi._golpe_demonstracao == golpe+1 and Time.get_ticks_msec()<limite:
                viu_rastro = viu_rastro or heroi._rastro.visible
                if q<5 and heroi._tempo_demonstracao/combo.DURACOES[golpe] >= q*0.15:
                    await RenderingServer.frame_post_draw
                    if lanca:
                        var ponta: Vector3=arma.global_transform*Vector3(0,1,0)
                        var base: Vector3=arma.global_transform.origin
                        var eixo: Vector3=(ponta-base).normalized()
                        for encaixe in [heroi._mao,heroi._mao_esquerda]:
                            var pega: Vector3=encaixe.global_transform*Vector3(0,0.08,0)
                            var projecao: float=(pega-base).dot(eixo)
                            conferir((pega-base-eixo*projecao).length()<0.055 and projecao>-0.08 and projecao<0.80,"As duas mãos permanecem na haste renderizada")
                        conferir(not heroi._escudo.visible,"Escudo oculto durante a estocada")
                    elif montante:
                        conferir(heroi._espada==heroi._montante and not heroi._espada_uma_mao.visible,"Arma grande substitui a espada de uma mão")
                        conferir(not heroi._escudo.visible,"Montante mantém o escudo oculto")
                        conferir(heroi._empunhadura_lanca.erro_montante<0.055,"Duas mãos permanecem no cabo do montante")
                    heroi._vp.get_texture().get_image().save_png(SAIDA+"combo_%d_%d_%d.png" % [direcoes.find(direcao),golpe,q])
                    q += 1
                await process_frame
            conferir(viu_rastro,"Rastro visível durante cada golpe")
            await esperar(2)
        await esperar(3)
        conferir(not heroi._demonstracao and heroi._acao == "parado", "Demonstração termina e volta ao repouso")
        await create_timer(0.15).timeout
        conferir(not heroi._rastro.visible,"Rastro desaparece depois do golpe")
    conferir(pedidos[0] == 0,"Teste não aciona ferramentas da fazenda")
    conferir(jogador.inventario.fotografar_mochila() == mochila,"Demonstração preserva inventário")
    # O mesmo controlador usa o temporizador e a área originais no combate.
    jogador.modo_fazenda = false
    if lanca:
        if not jogador.usando_lanca: jogador.equipar_lanca()
    elif not jogador.usando_espada: jogador.equipar_espada()
    await create_timer(0.9).timeout
    mochila = jogador.inventario.fotografar_mochila()
    jogador._sem_acao_ate_ms = 0
    await atacar(jogador)
    conferir(jogador._esta_atacando and jogador.get_node("AreaAtaque").monitoring,"Ataque real ativa combate e área de dano")
    conferir(heroi._acao == acao and arma.get_parent() == (heroi._modelo if lanca or montante else heroi._mao),"Ataque real reproduz o golpe 3D")
    var inicio: float = heroi._player.current_animation_position
    var osso: int = heroi._esqueleto.find_bone("DEF-hand.R")
    var pose: Transform3D = heroi._esqueleto.get_bone_global_pose(osso)
    await create_timer(0.10).timeout
    conferir(heroi._player.current_animation_position > inicio,"Animação acompanha o tempo do golpe")
    conferir(not heroi._esqueleto.get_bone_global_pose(osso).is_equal_approx(pose),"Mão se move durante o ataque")
    await atacar(jogador)
    conferir(jogador.ataque_enfileirado,"Segundo toque enfileira combo")
    await create_timer(jogador._temporizador.time_left+0.04).timeout
    conferir(jogador._esta_atacando and jogador._fase_combo == 2,"Segundo golpe encadeia no combate")
    conferir(heroi._player.assigned_animation == combo.NOMES[1],"Combate reproduz o segundo golpe")
    if combo.NOMES.size()==3:
        await atacar(jogador)
        await create_timer(jogador._temporizador.time_left+0.04).timeout
        conferir(jogador._esta_atacando and jogador._fase_combo == 3,"Terceiro toque inicia o finalizador")
        conferir(heroi._player.assigned_animation == combo.NOMES[2],"Finalizador mantém a arma e a animação do combo")
    else:
        conferir(jogador._limite_combo_espada()==2,"Espadão encerra no segundo golpe com salto")
    await create_timer(1.5).timeout
    conferir(not jogador._esta_atacando and arma.get_parent() == heroi._costas,"Espada retorna às costas ao terminar")
    heroi.acabamento_pixel_art = false
    await atacar(jogador)
    conferir(jogador._fase_combo == 1 and heroi._acao == acao,"Modo suave também inicia no primeiro golpe")
    await create_timer(0.9).timeout
    conferir(not jogador._esta_atacando and jogador._fase_combo == 0,"Sem novo toque, combo encerra e reinicia a sequência")
    if not lanca and not montante:
        if not jogador.usando_escudo: jogador.equipar_escudo()
        await create_timer(0.5).timeout
        mochila = jogador.inventario.fotografar_mochila()
        jogador.defesa._iniciar_escudada()
        await esperar(4)
        conferir(heroi._acao=="escudada" and heroi._player.assigned_animation=="melee/HumanM_AttackShield01","Escudada usa o ataque novo")
        conferir(heroi._escudo.visible,"Escudo aparece na escudada")
        await create_timer(0.65).timeout
        await esperar(3)
        conferir(not jogador._esta_atacando and heroi._acao=="parado","Escudada termina e devolve o controle")
    jogador.modo_fazenda = true
    await atacar(jogador)
    await create_timer(0.20).timeout
    jogador.esta_sentado = true
    await esperar(4)
    conferir(heroi.visible and heroi._acao in ["sentar","sentado"] and not heroi._demonstracao and not heroi._rastro.visible,"Interrupção limpa a demonstração e o rastro")
    jogador.esta_sentado = false
    conferir(jogador.inventario.fotografar_mochila() == mochila,"Inventário preservado")
    print("ATAQUE BASE 3D %s: %d verificações, %d falhas" % [acao,verificacoes,falhas])
    quit(1 if falhas else 0)
