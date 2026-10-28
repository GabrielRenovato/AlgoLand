extends SceneTree
## Cliente de teste da presença na cidade (save isolado), guiado por testar_lobby_local.py.
## --papel=a anda pela praça; --papel=b mede a suavidade do avatar do A na própria tela.
var papel := "a"
func _initialize(): rodar.call_deferred()
func esperar(n: int):
	for i in n: await process_frame
func log_(t: String) -> void: print("LOBBY[%s] %s" % [papel, t])
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--papel="): papel = a.trim_prefix("--papel=")
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(90)
	root.get_node("Transicao").limpar()
	var j = current_scene.get_node("Jogador")
	var lobby = current_scene.get_node("LobbyCidade")
	var sessao = lobby.sessao_de(j)
	sessao.definir_online(true, false)
	var fim := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < fim and not sessao.conectado: await process_frame
	log_("conectado=%s" % sessao.conectado)
	if "--peixe" in OS.get_cmdline_user_args():
		if papel == "a":
			await esperar(240)
			var sessao_pesca = load("res://codigo/pesca/sessao_pesca.gd").new()
			sessao_pesca.iniciar(j, Vector2.DOWN, "rio")
			sessao_pesca.peixe = "tilapia"
			await esperar(20)
			sessao_pesca.qualidade_peixe = 2
			sessao_pesca._pegar(false)
			log_("pesquei tilapia ouro")
			await esperar(240)
		else:
			var limite_p := Time.get_ticks_msec() + 25000
			while Time.get_ticks_msec() < limite_p and lobby.remotos.is_empty(): await process_frame
			if lobby.remotos.is_empty(): log_("FALHA nao viu o outro"); quit(1); return
			# O avatar pode ser recriado pelo lobby: procura o peixe em qualquer avatar remoto a cada quadro.
			var remoto_p: Node2D = null
			while Time.get_ticks_msec() < limite_p + 15000 and remoto_p == null:
				for r in lobby.remotos.values():
					if is_instance_valid(r) and is_instance_valid(r._peixe_mostrado): remoto_p = r
				await process_frame
			if remoto_p == null: log_("FALHA peixe nao apareceu"); quit(1); return
			await esperar(30)
			var rotulo: Label = remoto_p._peixe_mostrado.get_child(1)
			log_("peixe do outro: texto=%s cor=%s" % [rotulo.text, rotulo.get_theme_color("font_color").to_html(false)])
			var camera := Camera2D.new()
			current_scene.add_child(camera)
			camera.global_position = remoto_p.global_position + Vector2(0, -20)
			camera.zoom = Vector2(2, 2)
			camera.make_current()
			await esperar(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-lobby-teste/peixe_do_outro.png")
		quit()
		return
	if papel == "a":
		await esperar(240)
		for volta in 3:
			for passo in [["move_right", 70], ["move_down", 40], ["move_left", 70], ["move_up", 40]]:
				Input.action_press(passo[0])
				await esperar(passo[1])
				Input.action_release(passo[0])
		await esperar(120)
	else:
		var limite := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < limite and lobby.remotos.is_empty(): await process_frame
		if lobby.remotos.is_empty(): log_("FALHA nao viu o outro"); quit(1); return
		var remoto: Node2D = lobby.remotos.values()[0]
		# Espera o A começar a andar e mede 6 s.
		var inicio_pos := remoto.position
		while Time.get_ticks_msec() < limite + 10000 and remoto.position.distance_to(inicio_pos) < 2.0: await process_frame
		var passos: Array[float] = []
		var parados := 0
		var anterior := remoto.position
		var fim_medida := Time.get_ticks_msec() + 6000
		while Time.get_ticks_msec() < fim_medida:
			await process_frame
			var passo: float = remoto.position.distance_to(anterior)
			anterior = remoto.position
			passos.append(passo)
		# Quadros "travados": parado no meio do movimento (antes e depois andando).
		# Quadros parados entre dois trechos andando (inclui paradas de vários quadros).
		var primeiro := passos.find(passos.filter(func(p): return p > 0.3)[0])
		var ultimo := passos.size() - 1
		while ultimo > 0 and passos[ultimo] <= 0.3: ultimo -= 1
		for k in range(primeiro, ultimo):
			if passos[k] < 0.05: parados += 1
		# Variação: quanto o passo foge do passo real (mediana) em média.
		var desvio := 0.0
		var mov := passos.slice(primeiro, ultimo + 1)
		var ord := mov.duplicate(); ord.sort()
		var med: float = ord[ord.size() / 2]
		for p in mov: desvio += absf(p - med)
		log_("irregularidade_media=%.2f px/quadro" % (desvio / maxf(mov.size(), 1)))
		var andando := passos.filter(func(p): return p > 0.05)
		andando.sort()
		log_("suavidade: quadros=%d travadas=%d passo_mediano=%.2f p10=%.2f p90=%.2f maior=%.2f" % [passos.size(), parados, andando[andando.size()/2], andando[andando.size()/10], andando[andando.size()*9/10], andando.back()])
	quit()
