extends SceneTree
var falhas := 0
var papel := "A"

func _initialize() -> void: rodar.call_deferred()

func conferir(ok: bool, descricao: String) -> void:
	print("OK " if ok else "FALHA ", papel, " ", descricao)
	if not ok: falhas += 1

func esperar(condicao: Callable, limite_ms := 15000) -> void:
	var limite := Time.get_ticks_msec()+limite_ms
	while not condicao.call() and Time.get_ticks_msec()<limite:
		await create_timer(0.05).timeout

## Avatares remotos do mapa atual (sem o próprio jogador)
func remotos_de_agora() -> Dictionary:
	var lobby := current_scene.get_node_or_null("LobbyCidade")
	return lobby.remotos if lobby != null else {}

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
		var nao_lidas: int = sessao.mensagens_nao_lidas
		change_scene_to_file("res://cenas/floresta.tscn")
		await preparar_jogador()
		var nova: Node = cooperativo.sessao_chat_de(current_scene.get_node("Jogador"))
		conferir(nova == sessao and nova.eu == identidade and nova.geracao == geracao, "viagem preserva sessão e identidade")
		conferir(nova.mensagens.size() >= 2 and nova.online and nova.conectado, "viagem preserva histórico e conexão")
		conferir(nova.participantes.keys().all(func(id: String) -> bool: return id == nova.eu), "jogadores da cidade não aparecem na floresta")
		conferir(nova.enviar_mensagem("VIAJEI E CONTINUEI").is_empty(), "continua enviando depois de trocar de mapa")
		await esperar(func(): return nova.mensagens.size() >= 3)
		conferir(nova.mensagens_nao_lidas==nao_lidas, "viagem preserva contador e mensagem própria não acrescenta notificação")
		conferir(current_scene.has_node("LobbyCidade"), "floresta tem presença visual")
		await esperar(func(): return not remotos_de_agora().is_empty(), 40000)
		conferir(remotos_de_agora().size() == 1, "floresta mostra quem entra no mesmo mapa")
		for remoto in remotos_de_agora().values():
			conferir(Rect2(Vector2.ZERO, Vector2(1408, 864)).has_point(remoto.position), "avatar da floresta usa as coordenadas do mapa")
		if sessao.usa_ws():
			# Com o servidor próprio, golpe, esquiva, disparo e pesca do outro jogador chegam ao avatar dele
			var vistas := {}
			var ligacao := func(_id: String, dados: Dictionary) -> void: vistas[dados.acao] = true
			sessao.acao_remota.connect(ligacao)
			await esperar(func(): return vistas.size() >= 3, 60000)
			conferir(vistas.has("ataque") and vistas.has("dash") and vistas.has("arco"), "floresta mostra golpe, esquiva e disparo do outro jogador " + str(vistas.keys()))
			sessao.acao_remota.disconnect(ligacao)
			await esperar(func(): return remotos_de_agora().values().any(func(r): return r._pesca == 3), 30000)
			conferir(remotos_de_agora().values().any(func(r): return r._pesca == 3), "floresta mostra o outro jogador pescando")
	else:
		await esperar(func(): return sessao.mensagens.size() >= 3)
		conferir(sessao.mensagens.any(func(m: Dictionary) -> bool: return m.texto == "VIAJEI E CONTINUEI"), "recebe mensagem de outro mapa após viagem")
		conferir(sessao.mensagens_nao_lidas>=1, "nova mensagem de outro jogador gera notificação")
		conferir(current_scene.get_node("LobbyCidade").remotos.is_empty(), "não cria avatar fantasma de quem está fora da cidade")
		# Mesmo mapa: encontra quem está na floresta; quando ele segue para a praia, sai da floresta e se reencontram lá
		change_scene_to_file("res://cenas/floresta.tscn")
		await preparar_jogador()
		await esperar(func(): return not remotos_de_agora().is_empty(), 40000)
		conferir(remotos_de_agora().size() == 1, "floresta mostra o jogador que já estava lá")
		if sessao.usa_ws():
			var jogador_b: Node2D = current_scene.get_node("Jogador")
			for i in 12:
				for acao in ["ataque", "dash", "arco"]:
					jogador_b.acao_visual.emit(acao, 0.3, 1)
					await create_timer(0.35).timeout
			var pesca := Node2D.new()
			pesca.set_script(preload("res://codigo/pesca/animacao_pesca.gd"))
			pesca.name = "AnimacaoPesca"
			jogador_b.add_child(pesca)
			pesca.pose(3, false)
			await create_timer(5.0).timeout
			pesca.queue_free()
		await esperar(func(): return remotos_de_agora().is_empty(), 90000)
		conferir(remotos_de_agora().is_empty(), "quem vai para a praia sai da floresta")
		change_scene_to_file("res://cenas/praia.tscn")
		await preparar_jogador()
		await esperar(func(): return not remotos_de_agora().is_empty(), 60000)
		conferir(remotos_de_agora().size() == 1, "praia mostra o reencontro")
		for remoto in remotos_de_agora().values():
			conferir(Rect2(Vector2.ZERO, Vector2(704, 576)).has_point(remoto.position), "avatar da praia usa as coordenadas do mapa")
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
		sessao.mensagens_nao_lidas = 12
		tela._atualizar()
		for i in 5: await process_frame
		conferir(tela._contador_novas.is_visible_in_tree() and tela._contador_novas.text=="12", "balão mostra quantidade sem abrir prévia na tela")
		conferir(not tela._historico.visible, "celular mantém somente o botão de chat")
		conferir(tela._contador_novas.size.x>=tela._contador_novas.get_combined_minimum_size().x, "contador reserva margens para dois dígitos")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-contador-mobile-12.png")
		sessao.mensagens_nao_lidas = 120
		tela._atualizar()
		for i in 5: await process_frame
		conferir(tela._contador_novas.text=="99+", "contador limita o tamanho em muitas mensagens")
		for no in get_nodes_in_group("toque_hud"):
			if no.name=="BotaoMapaMundi" and no.get_viewport()==root:
				var area_selo: Rect2 = tela._contador_novas.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,tela._contador_novas.size)
				var area_mapa: Rect2 = no.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,no.size)
				conferir(not area_selo.grow(1).intersects(area_mapa), "contador tem folga do botão de mapa")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-contador-mobile-99.png")
		root.content_scale_size = Vector2i(576,324)
		root.size = Vector2i(1152,648)
		sessao.mensagens_nao_lidas = 1
		tela._atualizar()
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-contador-mobile-1.png")
		root.content_scale_size = Vector2i(288,216)
		root.size = Vector2i(864,648)
		for i in 10: await process_frame
		tela._botao_hud.pressed.emit()
		for i in 15: await process_frame
		conferir(interface._telas_abertas.has("lobby") and tela._sessao == sessao, "celular abre o mesmo canal fora da cidade")
		conferir(sessao.mensagens_nao_lidas==0 and not tela._contador_novas.visible, "abrir a conversa zera o contador")
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()), "painel global cabe na tela pequena")
		conferir(tela._campo.get_theme_stylebox("normal").get_margin(SIDE_LEFT)>=12, "texto mantém folga da moldura no painel global")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-chat-global-mobile.png")
		interface._fechar_tela("lobby")
		# Uma queda temporária não transforma mensagens novas em histórico inicial.
		sessao.conectado = false
		var resposta := {"eu":sessao.eu,"jogadores":[],"mensagens":[{"id":sessao._depois+1,"jogador":"outro_jogador","apelido":"Teste","texto":"Depois de reconectar"}]}
		sessao._receber(0,200,PackedStringArray(),JSON.stringify(resposta).to_utf8_buffer())
		conferir(sessao.mensagens_nao_lidas==1, "reconexão mantém a notificação de mensagens novas")
	if papel == "A":
		change_scene_to_file("res://cenas/praia.tscn")
		await preparar_jogador()
		await esperar(func(): return not remotos_de_agora().is_empty(), 60000)
		conferir(remotos_de_agora().size() == 1, "praia mostra quem chega depois")
		await create_timer(1.5).timeout
	sessao.definir_online(false)
	await create_timer(0.7).timeout
	print("LOBBY ",papel,": ",falhas," falhas")
	quit(1 if falhas else 0)
