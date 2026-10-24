extends SceneTree
var falhas := 0
var papel := "A"

func _initialize() -> void: rodar.call_deferred()

func conferir(ok: bool, descricao: String) -> void:
	print("OK " if ok else "FALHA ", papel, " ", descricao)
	if not ok: falhas += 1

func esperar(condicao: Callable) -> void:
	var limite := Time.get_ticks_msec()+15000
	while not condicao.call() and Time.get_ticks_msec()<limite:
		await create_timer(0.05).timeout

func preparar_jogador() -> void:
	for i in 35: await process_frame
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.invulneravel = true
	jogador.temporizador_invul = 999
	for ondas in get_nodes_in_group("gerenciador_ondas"): ondas.set_physics_process(false)

func rodar() -> void:
	assert(OS.get_user_data_dir().contains("AlgoLand testes lobby rede"))
	papel = "B" if "--papel=B" in OS.get_cmdline_user_args() else "A"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/fendas/andar_01.tscn" if papel == "A" else "res://cenas/cidade.tscn")
	await preparar_jogador()
	var cooperativo: Node = root.get_node("Cooperativo")
	var sessao: Node = cooperativo.sessao_chat_de(current_scene.get_node("Jogador"))
	conferir(current_scene.get_node("Interface")._telas.lobby._sessao == sessao, "interface encontra o canal em qualquer mapa")
	sessao.definir_online(true)
	await esperar(func(): return sessao.conectado)
	conferir(sessao.conectado, "canal conectado")
	conferir(sessao.enviar_mensagem("GLOBAL NA FENDA" if papel == "A" else "GLOBAL DA CIDADE").is_empty(), "envio aceito")
	await esperar(func(): return sessao.mensagens.size() >= 2)
	conferir(sessao.mensagens.size() >= 2, "cidade e fenda compartilham as mensagens")
	if papel == "A":
		var identidade: String = sessao.eu
		var geracao: String = sessao.geracao
		change_scene_to_file("res://cenas/floresta.tscn")
		await preparar_jogador()
		var nova: Node = cooperativo.sessao_chat_de(current_scene.get_node("Jogador"))
		conferir(nova == sessao and nova.eu == identidade and nova.geracao == geracao, "viagem preserva sessão e identidade")
		conferir(nova.mensagens.size() >= 2 and nova.online and nova.conectado, "viagem preserva histórico e conexão")
		conferir(nova.participantes.is_empty(), "jogadores da cidade não aparecem na floresta")
		conferir(nova.enviar_mensagem("VIAJEI E CONTINUEI").is_empty(), "continua enviando depois de trocar de mapa")
		await esperar(func(): return nova.mensagens.size() >= 3)
	else:
		await esperar(func(): return sessao.mensagens.size() >= 3)
		conferir(sessao.mensagens.any(func(m: Dictionary) -> bool: return m.texto == "VIAJEI E CONTINUEI"), "recebe mensagem de outro mapa após viagem")
		conferir(current_scene.get_node("LobbyCidade").remotos.is_empty(), "não cria avatar fantasma de quem está fora da cidade")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-chat-global-"+papel+".png")
	if papel == "A":
		root.get_node("Controle").usando_toque = true
		root.content_scale_size = Vector2i(288,216)
		root.size = Vector2i(864,648)
		for i in 20: await process_frame
		var interface: Node = current_scene.get_node("Interface")
		var tela: Control = interface._telas.lobby
		conferir(tela._botao_hud.is_visible_in_tree(), "ícone global disponível na floresta no celular")
		tela._botao_hud.pressed.emit()
		for i in 15: await process_frame
		conferir(interface._telas_abertas.has("lobby") and tela._sessao == sessao, "celular abre o mesmo canal fora da cidade")
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()), "painel global cabe na tela pequena")
		conferir(tela._campo.get_theme_stylebox("normal").get_margin(SIDE_LEFT)>=12, "texto mantém folga da moldura no painel global")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-global-mobile.png")
		interface._fechar_tela("lobby")
	sessao.definir_online(false)
	await create_timer(0.7).timeout
	print("LOBBY ",papel,": ",falhas," falhas")
	quit(1 if falhas else 0)
