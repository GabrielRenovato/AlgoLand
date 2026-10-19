extends SceneTree
var falhas := 0
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena = false
	var prog = root.get_node("Progresso")
	prog.iniciar_partida()
	var transicao = root.get_node("Transicao")
	transicao.retornando = true
	transicao.estado = {"onda_atual":2}
	change_scene_to_file("res://cenas/fendas/andar_02.tscn")
	await quadros(25)
	transicao.retornando = false
	var gerente = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.iniciar_onda(true)
	await quadros()
	var encontro = gerente.encontro
	var jogador = current_scene.get_node("Jogador")
	jogador.invulneravel = true
	jogador.global_position = encontro.global_position + Vector2(0,25)
	await quadros()
	verificar("eco pode ser acionado pela zona real",encontro._zona.jogador_perto and encontro._zona.disponivel_para_interacao())
	var meta: int = gerente.META_PROGRESSO
	var ouro: float = gerente.mult_evento("ouro")
	encontro.abrir(jogador)
	verificar("escolha pausa combate",paused and is_instance_valid(encontro._painel))
	for estacao in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
		verificar("marca acompanha estacao %d" % estacao,encontro._estacao == estacao)
		if capturar:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-jornada-encontro-%d.png" % estacao)
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	for i in 10: await process_frame
	var moldura: Control = encontro._painel._painel
	verificar("escolha cabe no celular",Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(moldura.get_global_rect()))
	if capturar:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-jornada-encontro-mobile.png")
	encontro._painel._escolher("atalho")
	verificar("atalho altera meta e ouro e retoma combate",not paused and gerente.META_PROGRESSO == ceili(meta*0.85) and is_equal_approx(gerente.mult_evento("ouro"),ouro*0.8))
	var nova_meta: int = gerente.META_PROGRESSO
	encontro.aplicar("cacada")
	verificar("escolha não pode ser trocada ou premiada duas vezes",gerente.META_PROGRESSO == nova_meta and prog.encontros_andares["2"] == "atalho")
	gerente.parar_ondas()
	await quadros()
	gerente.onda_atual = 2
	gerente.iniciar_onda(true)
	await quadros()
	verificar("reentrar preserva escolha sem repetir recompensa",gerente.encontro.usado and gerente.META_PROGRESSO == nova_meta)
	print("FALHAS: ",falhas)
	quit(falhas)
