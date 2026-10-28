extends SceneTree
## Cliente de teste do duelo online (save isolado), guiado por testar_duelo_local.py.
## -- --papel=a cria a sala e começa; --papel=b entra e marca pronto. Cada round, A derruba B
## com golpes diretos (o mesmo caminho do acerto real: adversário golpeado → evento → receber_dano).
var papel := "a"
var saida := "/tmp"
var j: Node
func _initialize(): rodar.call_deferred()
func esperar(n: int):
	for i in n: await process_frame
func log_(texto: String) -> void: print("DUELO[%s] %s" % [papel, texto])
func esperar_ate(cond: Callable, segundos := 20.0) -> bool:
	var fim := Time.get_ticks_msec() + int(segundos * 1000)
	while Time.get_ticks_msec() < fim:
		if cond.call(): return true
		await process_frame
	return false
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/duelo_%s_%s.png" % [saida, papel, nome])
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--papel="): papel = a.trim_prefix("--papel=")
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(40)
	root.get_node("Transicao").limpar()
	var duelo = load("res://codigo/duelo/conexao_duelo.gd").obter(self)
	j = duelo.jogador_local(self)
	log_("endereco=" + duelo.endereco())
	duelo.erro.connect(func(c): log_("erro " + c))
	duelo.abrir_tela()
	await esperar(10)
	if not await esperar_ate(func(): return duelo.conectado()): log_("FALHA sem conexao"); quit(1); return
	if papel == "a":
		duelo.criar("Sala de teste", "")
		await esperar_ate(func(): return not duelo.sala.is_empty())
		log_("sala criada id=%s" % duelo.sala.id)
		await foto("sala_sozinho")
		if not await esperar_ate(func(): return not duelo.adversario().is_empty() and bool(duelo.adversario().pronto), 40.0): log_("FALHA adversario nao veio"); quit(1); return
		await esperar(10)
		await foto("sala_cheia")
		duelo.iniciar()
	else:
		if not await esperar_ate(func():
			duelo.listar()
			return root.get_node_or_null("TelaSalasDuelo") != null and not root.get_node("TelaSalasDuelo")._salas.is_empty(), 30.0): log_("FALHA nenhuma sala"); quit(1); return
		await esperar(5)
		await foto("lista")
		var sala: Dictionary = root.get_node("TelaSalasDuelo")._salas[0]
		duelo.entrar(int(sala.id))
		await esperar_ate(func(): return not duelo.sala.is_empty())
		duelo.marcar_pronto(true)
		log_("entrou e pronto")
	if not await esperar_ate(func(): return current_scene != null and current_scene.scene_file_path == duelo.CENA_ARENA, 20.0): log_("FALHA nao foi para a arena"); quit(1); return
	log_("na arena, lado=%d" % duelo.meu_lado)
	var arena = current_scene
	await esperar(60)
	await foto("arena_inicio")
	var rounds_vistos := 0
	var fim := false
	duelo.partida_terminou.connect(func(d):
		fim = true
		log_("fim vencedor_sou_eu=%s motivo=%s placar=%s" % [str(d.get("vencedor","")) == duelo.eu, d.get("motivo",""), d.get("placar",{})]))
	duelo.ponto_marcado.connect(func(d): log_("ponto vencedor_sou_eu=%s placar=%s" % [str(d.vencedor) == duelo.eu, d.placar]))
	# Movimento real: A anda e ataca pelos mesmos comandos do teclado; B fotografa como vê o A.
	if "--movimento" in OS.get_cmdline_user_args():
		await esperar_ate(func(): return arena._contagem <= 0.0, 10.0)
		if papel == "a":
			# 1) Limite: correr para a esquerda por 2 s não pode sair da terra.
			Input.action_press("move_left")
			await esperar(120)
			Input.action_release("move_left")
			log_("limite: dentro_da_arena=%s" % arena.dentro_da_arena(arena.jogador.global_position))
			# 2) Ir até o adversário pelos comandos e golpear: área de ataque -> boneco remoto -> evento -> dano no outro jogo.
			for passo in 300:
				var diferenca: Vector2 = arena.adversario.global_position - arena.jogador.global_position
				if diferenca.length() < 18.0: break
				for acao in ["move_left","move_right","move_up","move_down"]: Input.action_release(acao)
				if absf(diferenca.x) > 6.0: Input.action_press("move_right" if diferenca.x > 0 else "move_left")
				if absf(diferenca.y) > 6.0: Input.action_press("move_down" if diferenca.y > 0 else "move_up")
				await esperar(1)
			for acao in ["move_left","move_right","move_up","move_down"]: Input.action_release(acao)
			var antes: int = arena.adversario.hp
			# O ataque nasce de evento de entrada (jogador._unhandled_input), como uma tecla de verdade.
			for golpe in 4:
				var aperto := InputEventAction.new()
				aperto.action = "attack"
				aperto.pressed = true
				Input.parse_input_event(aperto)
				await esperar(4)
				var soltura := InputEventAction.new()
				soltura.action = "attack"
				soltura.pressed = false
				Input.parse_input_event(soltura)
				await esperar(22)
			await esperar(30)
			log_("golpe real: distancia=%.0f hp_adversario %d -> %d" % [arena.jogador.global_position.distance_to(arena.adversario.global_position), antes, arena.adversario.hp])
			if "--aparo" in OS.get_cmdline_user_args():
				# 3) Aparo: o B fica em guarda recém-erguida; o golpe do A vira aparo perfeito no B,
				# que atordoa o A (evento "efeito" de volta).
				await esperar(90)
				var para_b: Vector2 = (arena.adversario.global_position - arena.jogador.global_position).normalized()
				arena._ao_golpear_adversario(20, para_b * 120.0)
				var atordoado := await esperar_ate(func(): return arena._atordoado_ate_ms > 0, 3.0)
				log_("aparo: fui_atordoado=%s pode_agir=%s" % [atordoado, arena.jogador.movimento_habilitado])
				await esperar_ate(func(): return arena._atordoado_ate_ms == 0, 3.0)
				log_("aparo: recuperou pode_agir=%s" % arena.jogador.movimento_habilitado)
		elif "--aparo" in OS.get_cmdline_user_args():
			# B: guarda sempre "recém-erguida" e virada para o A até o fim do teste do aparo.
			var fim_guarda := Time.get_ticks_msec() + 9000
			while Time.get_ticks_msec() < fim_guarda:
				var d = arena.jogador.defesa
				d.estado = d.Estado.GUARDA
				d._inicio_guarda_ms = Time.get_ticks_msec()
				d.direcao_guarda = (arena.adversario.global_position - arena.jogador.global_position).normalized()
				await esperar(1)
			log_("aparo: hp_depois_do_golpe=%d de %d" % [arena.jogador.hp_atual, arena.jogador.estatisticas.hp_maximo])
			arena.jogador.defesa.cancelar()
		else:
			# Suavidade: passo por quadro do adversário enquanto ele corre (liso = passos parecidos).
			var passos: Array[float] = []
			var anterior: Vector2 = arena.adversario.global_position
			var fim_medida := Time.get_ticks_msec() + 2500
			while Time.get_ticks_msec() < fim_medida:
				await process_frame
				var atual: Vector2 = arena.adversario.global_position
				var passo := atual.distance_to(anterior)
				if passo > 0.05: passos.append(passo)
				anterior = atual
			if passos.size() > 10:
				passos.sort()
				log_("suavidade: quadros=%d passo_mediano=%.2f p10=%.2f p90=%.2f maior=%.2f" % [passos.size(), passos[passos.size()/2], passos[passos.size()/10], passos[passos.size()*9/10], passos.back()])
			for quadro in 12:
				await esperar(12)
				await foto("movimento_%02d" % quadro)
		await esperar(20)
	while not fim and is_instance_valid(arena):
		if papel == "a" and arena._contagem <= 0.0 and not arena._caiu and arena.adversario.hp > 0 and not arena.adversario.estaMorto:
			arena._ao_golpear_adversario(40, Vector2.ZERO)
			await esperar(30)
			if rounds_vistos == 0:
				rounds_vistos = 1
				await foto("arena_golpe")
		await esperar(2)
		if Time.get_ticks_msec() > 120000: log_("FALHA tempo esgotado"); break
	if is_instance_valid(arena):
		await foto("arena_fim")
		log_("hp_local=%d hp_adversario_visto=%d" % [arena.jogador.hp_atual, arena.adversario.hp])
	await esperar_ate(func(): return current_scene != null and current_scene.scene_file_path != duelo.CENA_ARENA, 15.0)
	await esperar_ate(func(): return root.get_node_or_null("TelaSalasDuelo") != null, 8.0)
	log_("voltou para " + str(current_scene.scene_file_path) + " sala_reaberta=" + str(root.get_node_or_null("TelaSalasDuelo") != null))
	await foto("volta")
	quit()
