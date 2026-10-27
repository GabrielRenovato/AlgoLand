extends SceneTree
## Exercita plantio, água, colheita, árvore, avanço e cadeira reais no save isolado.
const SAIDA := "/tmp/algoland-mecanicas-3d/"
const CELULA := Vector2i(20,24)
var falhas := 0
var verificacoes := 0
var impactos: Array[String]=[]
var j: Node
var h: Node
func _initialize(): rodar.call_deferred()
func conferir(ok: bool,texto: String):
    verificacoes+=1
    if not ok: falhas+=1; push_error(texto)
func esperar(n: int):
    for i in n: await process_frame
func apertar(nome: String):
    var evento:=InputEventAction.new()
    evento.action=j.acao(nome)
    evento.pressed=true
    root.push_input(evento)
    await esperar(3)
    evento=InputEventAction.new()
    evento.action=j.acao(nome)
    evento.pressed=false
    root.push_input(evento)
func foto(nome: String):
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(SAIDA+nome+".png")
func posicionar(celula: Vector2i):
    j.global_position=Vector2(celula.x*16+8,celula.y*16-14)
    j._direcao_ataque=Vector2.DOWN
    j.velocity=Vector2.ZERO
    j._sem_acao_ate_ms=0
func conferir_acao(acao: String):
    conferir(j.esta_em_acao_fazenda and h.visible and h._acao=="fazenda_"+acao,"Ação 3D real: "+acao)
    conferir(not j.get_node("HeroiRaven").visible and not h._demonstracao,"Sem troca para Raven nem demonstração de combate")
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(SAIDA)
    root.get_node("Introducao").pular_prologo()
    var f=root.get_node("Fazenda")
    var inv=root.get_node("InventarioJogador")
    inv.limpar()
    inv.criar_itens_iniciais()
    f.apagar()
    root.get_node("Calendario").apagar()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    await esperar(6)
    j=current_scene.get_node("Jogador")
    h=j.get_node("HeroiBase3D")
    conferir(not h.demonstrar_combate_na_fazenda,"Modo normal usa as ferramentas da mochila")
    j.acao_fazenda_impacto.connect(func(acao: String,_ponto: Vector2): impactos.append(acao))
    f.aplicar("enxada",CELULA)
    posicionar(CELULA)
    await esperar(8)
    var plantio=current_scene.get_node("Terrains/Plantio")
    conferir(plantio._cursor_visivel and plantio._celula_cursor==CELULA,"Cursor da ferramenta continua no terreno")
    # O mesmo botão que antes demonstrava a espada agora usa o regador.
    f.definir_ferramenta("regador")
    var agua: int=f.agua_regador
    impactos.clear()
    await apertar("attack")
    conferir_acao("regar")
    conferir(h._ferramentas._regador.visible,"Regador acompanha a mão")
    conferir(not f.esta_molhado(CELULA),"Água não é aplicada antes do impacto")
    await create_timer(0.24).timeout
    conferir(f.esta_molhado(CELULA) and f.agua_regador==agua-1 and impactos==["regar"],"Regar molha o tile e gasta uma carga uma única vez")
    conferir(h._ferramentas._gotas.any(func(gota): return gota.visible),"Jato visível durante a rega")
    var destino: Vector3=h._modelo.to_global(h.destino_ferramenta_3d())
    var projetado: Vector2=h._camera.unproject_position(destino)-h._camera.unproject_position(Vector3.ZERO)
    conferir(projetado.distance_to(Vector2.DOWN*j.ALCANCE_ACAO_FAZENDA*2.0)<0.05,"Água aponta para o mesmo alvo do Plantio")
    await foto("regar")
    await create_timer(0.55).timeout
    conferir(not j.esta_em_acao_fazenda and not h._ferramentas.visible,"Regador desaparece ao terminar")
    # Plantar usa sementes reais, só no impacto.
    f.dar_sementes("cenoura",3)
    f.definir_ferramenta("semente:cenoura")
    impactos.clear()
    await apertar("attack")
    conferir_acao("plantar")
    conferir(f.quantidade_sementes("cenoura")==3 and f.planta_em(CELULA)=="","Semente preservada durante a preparação")
    await create_timer(0.34).timeout
    conferir(f.planta_em(CELULA)=="cenoura" and f.quantidade_sementes("cenoura")==2 and impactos==["plantar"],"Plantar consome uma semente e cria a planta no impacto")
    await foto("plantar")
    await create_timer(0.4).timeout
    for i in 3:
        f.aplicar("regar",CELULA)
        f.avancar_dia(0)
        await esperar(2)
    conferir(f.esta_madura(CELULA),"Planta real amadurecida")
    var antes: int=f.quantidade_colhida("cenoura")
    impactos.clear()
    await apertar("colher")
    conferir_acao("colher")
    await create_timer(0.5).timeout
    conferir(f.quantidade_colhida("cenoura")==antes+1 and f.planta_em(CELULA)=="" and impactos==["colher"],"Colher remove a planta e entrega uma colheita")
    await foto("colher")
    await create_timer(0.4).timeout
    # Corte ligado à árvore real e ao mesmo temporizador de extração.
    var extracao=current_scene.find_child("Extracao",true,false)
    var arvore: Dictionary={}
    for recurso in extracao.recursos:
        if recurso.tipo=="arvore": arvore=recurso; break
    conferir(not arvore.is_empty(),"Árvore real disponível")
    if not arvore.is_empty():
        f.definir_ferramenta("machadinha")
        j.global_position=extracao.to_global(arvore.pos)-Vector2(0,11+j.ALCANCE_ACAO_FAZENDA)
        j._direcao_ataque=Vector2.DOWN
        await esperar(6)
        impactos.clear()
        var vida: int=extracao._vida.get(arvore.chave,4)
        await apertar("attack")
        conferir_acao("machado")
        conferir(h._ferramentas._machado.visible,"Machado aparece no corte")
        await create_timer(0.35).timeout
        conferir(extracao._vida.get(arvore.chave,4)==vida-1 and impactos==["machado"],"Corte acerta a árvore uma vez")
        await foto("cortar_arvore")
        await create_timer(0.4).timeout
    # Deslocamento e estamina originais, sem reproduzir Roll.
    j.position=Vector2(640,520)
    j._direcao_ataque=Vector2.RIGHT
    j._sem_acao_ate_ms=0
    j.stamina=j.stamina_maxima
    var partida: Vector2=j.global_position
    var stamina: float=j.stamina
    Input.action_press(j.acao("rolar"))
    await esperar(3)
    Input.action_release(j.acao("rolar"))
    conferir(j.esta_em_dash and h._acao=="avanco" and h._player.assigned_animation=="Jog_Fwd_Loop","Esquiva avança sem animação de rolamento")
    conferir(j.stamina<stamina and j.invulneravel,"Avanço preserva custo e invulnerabilidade")
    conferir(get_nodes_in_group("rastros_dash").size()>0,"Avanço cria rastro do modelo")
    await foto("avanco")
    await create_timer(0.25).timeout
    conferir(j.global_position.distance_to(partida)>25 and not j.esta_em_dash,"Avanço mantém o deslocamento e termina")
    # A cadeira real mantém ocupação, orientação e saída.
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/casa.tscn")
    await esperar(30)
    root.get_node("Transicao").limpar()
    j=current_scene.get_node("Jogador")
    h=j.get_node("HeroiBase3D")
    var cadeiras=get_nodes_in_group("assentos").filter(func(no): return no.get_world_2d()==j.get_world_2d())
    conferir(not cadeiras.is_empty(),"Cadeira real disponível")
    if not cadeiras.is_empty():
        var cadeira=cadeiras[0]
        j.position=cadeira.position+Vector2(0,-8)
        j._sem_acao_ate_ms=0
        cadeira.abrir_tela()
        await esperar(4)
        conferir(j.esta_sentado and cadeira.ocupada and h._acao=="sentar","Sentar usa a cadeira e anima a entrada")
        conferir(not h._espada.visible and not h._lanca.visible,"Armas ocultas durante a pose sentada")
        await create_timer(0.40).timeout
        conferir(h.visible and h._acao=="sentado" and h._player.assigned_animation=="Sitting_Idle_Loop","Modelo mantém a pose sentado")
        conferir(not j.movimento_habilitado and j.ataques_bloqueados,"Cadeira mantém os bloqueios do jogo")
        await foto("sentado_na_cadeira")
        j.pediu_levantar.emit()
        await esperar(4)
        conferir(not j.esta_sentado and not cadeira.ocupada and h._acao=="levantar","Levantar libera a cadeira e usa a saída")
        await create_timer(0.3).timeout
        conferir(j.movimento_habilitado and h._acao=="parado","Levantar devolve o controle")
    print("MECÂNICAS BASE 3D: %d verificações, %d falhas" % [verificacoes,falhas])
    quit(1 if falhas else 0)
