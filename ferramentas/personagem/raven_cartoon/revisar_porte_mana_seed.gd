extends SceneTree
## Compara as trilhas originais Mana Seed com o visual jogável, quadro a quadro.
const SAIDA := "res://arte/previas/personagens/raven_cartoon/porte_mana_seed/"
var origem: Node
var visual: Node
var mana: Node2D
var animador: AnimationPlayer
var vp: SubViewport
func _initialize():
    rodar.call_deferred()
func aplicar_mana(acao: String, direcao: String, q: int):
    var dados = visual.PORTE_PERFIS.data
    var pose = dados.direcoes[direcao][acao][q]
    for nome in ["Corpo","Braco"]:
        var sprite = mana.get_node(nome)
        sprite.region_rect = Rect2(pose.coluna*64,pose.linha*64,64,64)
func texto(valor: String, ponto: Vector2):
    var l = Label.new()
    l.text = valor
    l.position = ponto
    l.add_theme_font_size_override("font_size",22)
    vp.add_child(l)
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name() != "headless")
    root.get_node("Introducao").pular_prologo()
    root.get_node("Fazenda").apagar()
    root.get_node("Transicao").hora_salva = 12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_cartoon(true)
    visual = current_scene.get_node("Jogador/HeroiCartoon")
    current_scene.process_mode = Node.PROCESS_MODE_DISABLED
    vp = SubViewport.new()
    vp.size = Vector2i(1000,440)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var fundo = ColorRect.new()
    fundo.size = vp.size
    fundo.color = Color("515e47")
    vp.add_child(fundo)
    mana = Node2D.new()
    vp.add_child(mana)
    mana.scale = Vector2.ONE*8
    mana.z_index = 3
    var dados = visual.PORTE_PERFIS.data
    for nome in ["Corpo","Braco"]:
        var s = Sprite2D.new()
        s.name = nome
        s.texture = load("res://"+str(dados.referencia_corpo if nome == "Corpo" else dados.referencia_espada))
        s.centered = false
        s.offset = Vector2(-32,-44)
        s.region_enabled = true
        s.region_filter_clip_enabled = true
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.z_index = 0 if nome == "Corpo" else -1
        mana.add_child(s)
    visual.reparent(vp)
    visual.process_mode = Node.PROCESS_MODE_DISABLED
    visual.scale = Vector2.ONE*8
    texto("MANA SEED / trilhas originais",Vector2(45,16))
    texto("CARTOON / camada do jogo",Vector2(540,16))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    var instantes = [0.0,100.0,160.0,300.0,400.0,460.0]
    for direcao in ["direita","esquerda"]:
        for estado in 7:
            var acao = "parado" if estado == 0 else "correr"
            var q = maxi(0,estado-1)
            aplicar_mana(acao,direcao,q)
            mana.position = Vector2(250,390)
            visual.position = Vector2(750,390)
            visual.acao_atual = acao
            visual.direcao_atual = direcao
            visual._definir_recurso("parado_quatro_direcoes" if estado == 0 else "corrida_quatro_direcoes",acao+"_"+direcao)
            visual.corpo.offset = Vector2(-320 if estado == 0 else -256,-850)
            visual.corpo.scale = Vector2.ONE*visual.ESCALA
            var fase: float = 0.0 if estado == 0 else (instantes[q]+0.001)/600.0
            visual._distancia_corrida = fase*visual.distancia_ciclo_corrida()
            visual.corpo.frame = int(fase*4.0)
            visual._arma_costas.visible = true
            visual._atualizar_arma_costas()
            visual.armadura.atualizar()
            assert(estado == 0 or visual.quadro_porte_corrida() == q)
            var pose = dados.direcoes[direcao][acao][q]
            assert(visual._arma_costas.position.is_equal_approx(Vector2(pose.posicao[0],pose.posicao[1])))
            assert(is_equal_approx(visual._arma_costas.rotation,pose.angulo))
            assert(visual._arma_costas.z_index == -1)
            await RenderingServer.frame_post_draw
            vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%s.png" % [acao,q,direcao])
            # Reprodução no motor com as durações relativas reais da corrida.
            await create_timer(0.3 if estado == 0 else float(dados.duracoes_ms[q])*0.000758).timeout
    print("PORTE MANA SEED: 14 poses; corrida real de seis quadros por perfil, posições/ângulos/camadas conferidos.")
    vp.queue_free()
    await process_frame
    quit()
