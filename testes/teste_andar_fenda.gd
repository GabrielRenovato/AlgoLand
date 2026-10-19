extends SceneTree

## Combate completo e viagem real, com mochila e saves exclusivos de testes.
var falhas := 0
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/fenda/jornada/"+nome+".png")
func aguardar_inicio_sem_recuo() -> void:
	# Simula o deslocamento durante o respiro da chegada e isola o início do combate.
	await quadros(4) # A montagem do segundo jogador acompanha a troca de cena.
	var posicoes := {}
	for parte in get_nodes_in_group("jogadores"):
		posicoes[parte] = {"processando": parte.is_physics_processing(), "posicao": parte.global_position + Vector2(24, 0)}
		parte.set_physics_process(false)
		parte.global_position = posicoes[parte]["posicao"]
		parte.velocity = Vector2(32, 0)
	verificar("chegada acompanha todos os jogadores", posicoes.size() == (2 if root.get_node("Cooperativo").com_dois() else 1))
	await create_timer(1.6).timeout
	for parte in posicoes:
		verificar("inicio do andar preserva deslocamento de " + parte.name, parte.global_position.is_equal_approx(posicoes[parte]["posicao"]))
		verificar("inicio do andar preserva velocidade de " + parte.name, parte.velocity.is_equal_approx(Vector2(32, 0)))
		parte.velocity = Vector2.ZERO
		parte.set_physics_process(posicoes[parte]["processando"])
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1152,648)
	root.content_scale_size=Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Transicao").limpar()
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(15)
	root.get_node("Transicao").entrar_na_arena()
	await root.get_node("Transicao").troca_concluida
	await aguardar_inicio_sem_recuo()
	var gerente: Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
	var gerador: Node=current_scene.get_node("enemySpawner")
	var jogador: Node2D=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.invulneravel=true
	jogador.temporizador_invul=10000
	verificar("portal inicia primeiro andar curto",current_scene.get_meta("planta_andar")==1 and gerente.etapa==1 and gerador._populacao.size()==16)
	verificar("entrada protegida de perseguicao global",gerente._adormecidos.size()==16)
	var alvo: Node2D=gerador._populacao[0]
	jogador.global_position=alvo.global_position+Vector2(40,0)
	await create_timer(.25).timeout
	verificar("aproximacao ativa grupo local",alvo.is_physics_processing() and not gerente._adormecidos.is_empty())
	gerente.set_physics_process(false)
	for inimigo in gerador._populacao:
		inimigo.set_physics_process(false)
		if inimigo.has_node("PatrulhaAndar"): inimigo.get_node("PatrulhaAndar").set_physics_process(false)
	await foto("primeiro_andar")
	var concluidas: int=root.get_node("Progresso").ondas_concluidas
	for inimigo in gerador._populacao.duplicate():
		if gerente.etapa!=1: break
		if not is_instance_valid(inimigo): continue
		inimigo.receber_dano(99999)
		await inimigo.tree_exited
	verificar("barra cheia antecede boss e nao conclui andar",gerente.pontos==gerente.META_PROGRESSO and gerente.etapa==2 and gerente.onda_em_andamento and root.get_node("Progresso").ondas_concluidas==concluidas)
	await create_timer(1.9).timeout
	var boss: Node2D=gerente.guardiao
	verificar("guardiao unico e excedentes sem premios",is_instance_valid(boss) and get_nodes_in_group("enemy").size()==1)
	jogador.global_position=current_scene.get_node("Terrains/Chegada_portal").global_position
	gerente.set_physics_process(true)
	await create_timer(.25).timeout
	verificar("guardiao espera na area final",boss.get_meta("guardiao_aguardando",false) and not boss.is_physics_processing())
	jogador.global_position=boss.global_position+Vector2(64,40)
	await create_timer(.25).timeout
	verificar("guardiao comeca a lutar ao se aproximar",boss.is_physics_processing())
	gerente.set_physics_process(false)
	boss.set_physics_process(false)
	boss.receber_dano(99999)
	await boss.tree_exited
	verificar("morte do boss confirma uma conclusao",gerente.etapa==4 and gerente.onda_atual==2 and root.get_node("Progresso").ondas_concluidas==concluidas+1)
	await create_timer(2).timeout
	var ui: Node=get_first_node_in_group("interface")
	var loja: Node=ui._telas["mercante"]
	verificar("vitoria chama guia e aguarda conversa",not loja.visible and is_instance_valid(gerente.guia))
	gerente.guia.interacao.abrir_tela()
	await quadros(5)
	verificar("conversa abre melhorias com botao do proximo andar",loja.visible and loja._botao_proxima.text=="ANDAR 2 >" and loja._conversa_guia.visible)
	await foto("melhorias_andar")
	# Coop viaja junto e permanece na mesma partida.
	root.get_node("Cooperativo").entrar(99)
	await quadros(20)
	var p2: Node=root.get_node("Cooperativo").jogador2()
	verificar("segundo jogador presente",p2!=null)
	loja=get_first_node_in_group("interface")._telas["mercante"]
	loja._ao_proxima_onda()
	await root.get_node("Transicao").troca_concluida
	await aguardar_inicio_sem_recuo()
	gerente=current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerador=current_scene.get_node("enemySpawner")
	verificar("continuar muda terreno e mantem cooperativo",current_scene.get_meta("planta_andar")==2 and gerente.etapa==1 and root.get_node("Cooperativo").jogador2()!=null)
	var hud2: Node=get_first_node_in_group("hud_p2")
	verificar("HUD do parceiro acompanha andar",hud2!=null and hud2.rotulo_onda.text=="ANDAR 2")
	await foto("segundo_andar_coop")
	gerente.pontos=gerente.META_PROGRESSO
	gerente._invocar_guardiao(gerente._geracao)
	gerente.parar_ondas()
	await create_timer(2).timeout
	verificar("cancelar invalida boss pendente",get_nodes_in_group("enemy").is_empty() and gerente.etapa==5)
	ui=get_first_node_in_group("interface")
	loja=ui._telas["mercante"]
	ui._abrir_tela("mercante")
	loja._ao_voltar_para_cidade()
	loja._confirmar_volta_para_cidade()
	await root.get_node("Transicao").troca_concluida
	await quadros(20)
	verificar("volta real para a vila",current_scene.scene_file_path=="res://cenas/cidade.tscn")
	for parte in get_nodes_in_group("jogadores"): parte.set_physics_process(false)
	root.get_node("Cooperativo").sair()
	await quadros()
	root.get_node("Transicao").limpar()
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(15)
	verificar("arena anterior preservada e carregavel",current_scene.has_node("CirculoProximaOnda") and not current_scene.get_meta("andar_fenda",false))
	current_scene.queue_free()
	await quadros()
	print("Andar fenda: %d falhas" % falhas)
	quit(1 if falhas else 0)
