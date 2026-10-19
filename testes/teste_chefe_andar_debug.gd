extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	var progresso := root.get_node("Progresso")
	progresso.iniciar_partida()
	root.get_node("Transicao").limpar()
	change_scene_to_file("res://cenas/fendas/andar_01.tscn")
	await quadros(20)
	var gerente: Node = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.iniciar_onda()
	await quadros()
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.invulneravel = true
	jogador.temporizador_invul = 10000
	var ouro: int = root.get_node("DadosJogo").moedas
	var abates: int = progresso.abates
	var vitorias: int = progresso.ondas_concluidas
	var painel: Node = root.get_node("PainelDebug")
	verificar("F3 oferece ir direto ao chefe",painel._opcoes["ANDARES"].any(func(opcao): return opcao[0]=="IR DIRETO AO CHEFE"))
	painel._ao_chefe_andar()
	painel._ao_chefe_andar()
	await create_timer(2).timeout
	verificar("clique duplicado deixa somente um chefe",gerente.etapa==gerente.Etapa.GUARDIAO and get_nodes_in_group("enemy").size()==1)
	verificar("jogador chega perto do chefe pronto para lutar",jogador.global_position.distance_to(gerente.guardiao.global_position)<150 and not gerente.guardiao.get_meta("guardiao_aguardando",true))
	verificar("pulo preserva andar e nao premia encontros",gerente.onda_atual==1 and progresso.abates==abates and progresso.ondas_concluidas==vitorias and root.get_node("DadosJogo").moedas==ouro and get_nodes_in_group("equipamento_drop").is_empty())
	var chefe: Node2D = gerente.guardiao
	root.get_node("Cooperativo").entrar(99)
	await quadros(20)
	for parte in get_nodes_in_group("jogadores"):
		parte.set_physics_process(false)
		parte.invulneravel = true
		parte.temporizador_invul = 10000
		parte.global_position = current_scene.get_node("Terrains/Chegada_portal").global_position
	painel._ao_chefe_andar()
	verificar("reusar atalho mantem o mesmo chefe",gerente.guardiao==chefe and get_nodes_in_group("enemy").size()==1)
	for parte in get_nodes_in_group("jogadores"):
		verificar("atalho leva o parceiro presente " + parte.name,parte.global_position.distance_to(chefe.global_position)<150)
	chefe.set_physics_process(false)
	chefe.receber_dano(99999)
	await chefe.tree_exited
	verificar("vitoria ainda exige derrotar chefe",gerente.etapa==gerente.Etapa.CONCLUIDO and progresso.ondas_concluidas==vitorias+1)
	gerente.parar_ondas()
	root.get_node("Cooperativo").sair()
	current_scene.queue_free()
	await quadros()
	print("Chefe andar debug: %d falhas" % falhas)
	quit(1 if falhas else 0)
