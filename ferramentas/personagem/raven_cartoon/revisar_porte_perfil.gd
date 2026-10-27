extends SceneTree
## Renderiza o porte da espada nas costas: repouso e quatro quadros de corrida por direção.
const SAIDA := "res://arte/previas/personagens/raven_cartoon/porte_perfil/"
var visual: Node
var vp: SubViewport
func _initialize():
    rodar.call_deferred()
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
    vp.size = Vector2i(1000,360)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var fundo = ColorRect.new()
    fundo.size = vp.size
    fundo.color = Color("515e47")
    vp.add_child(fundo)
    visual.reparent(vp)
    visual.process_mode = Node.PROCESS_MODE_DISABLED
    # Argumentos opcionais: --escala=12 --direcoes=direita,esquerda
    var escala := 6.0
    var direcoes := ["direita","esquerda","frente","costas"]
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--escala="): escala = float(arg.get_slice("=",1))
        if arg.begins_with("--direcoes="): direcoes = Array(arg.get_slice("=",1).split(","))
        # --perfil=apoio_x,apoio_y,angulo,parado_x,parado_y
        if arg.begins_with("--perfil="):
            var v = arg.get_slice("=",1).split_floats(",")
            visual.apoio_perfil = Vector2(v[0],v[1])
            visual.angulo_perfil = v[2]
            visual.encaixe_perfil_parado = Vector2(v[3],v[4])
    var k := escala/6.0
    vp.size = Vector2i(int(1000*k),int(360*k))
    fundo.size = vp.size
    visual.scale = Vector2.ONE*escala
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    var folha := Image.create(int(5*260*k),int(direcoes.size()*340*k),false,Image.FORMAT_RGBA8)
    var linha := 0
    for direcao in direcoes:
        for estado in 5:
            var acao = "parado" if estado == 0 else "correr"
            visual.position = Vector2(500,330)*k
            visual.acao_atual = acao
            visual.direcao_atual = direcao
            visual._definir_recurso("parado_quatro_direcoes" if estado == 0 else "corrida_quatro_direcoes",acao+"_"+direcao)
            visual.corpo.offset = Vector2(-320 if estado == 0 else -256,-850)
            visual.corpo.scale = Vector2.ONE*visual.ESCALA
            visual.corpo.frame = maxi(0,estado-1)
            visual._arma_costas.visible = true
            visual._atualizar_arma_costas()
            visual.armadura.atualizar()
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            var quadro := vp.get_texture().get_image()
            quadro.convert(Image.FORMAT_RGBA8)
            folha.blit_rect(quadro,Rect2i(Vector2i(Vector2(370,0)*k),Vector2i(Vector2(260,340)*k)),Vector2i(Vector2(estado*260,linha*340)*k))
        linha += 1
    folha.save_png(SAIDA+"quatro_direcoes.png")
    print("PORTE PERFIL: folha com 20 poses exportada.")
    vp.queue_free()
    await process_frame
    quit()
