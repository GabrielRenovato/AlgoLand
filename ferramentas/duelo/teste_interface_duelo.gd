extends SceneTree
## Revisão gráfica com save isolado: HUD, slots, toque e largura de meia tela.
var falhas := 0
func _initialize(): rodar.call_deferred()
func esperar(n := 12):
	for i in n: await process_frame
func conferir(ok: bool, mensagem: String):
	print(("OK " if ok else "FALHA ") + mensagem)
	if not ok: falhas += 1
func foto(nome: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/duelo-ui-" + nome + ".png")
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(40)
	root.get_node("Transicao").limpar()
	var duelo = load("res://codigo/duelo/conexao_duelo.gd").obter(self)
	var j = duelo.jogador_local(self)
	var perfil = duelo.perfil_do(j)
	perfil.visual.arma_mais_usada = "montante_astral"
	perfil.visual.equipamentos = {"cabeca":"cabeca_basica", "corpo":"armadura_basica", "luvas":"luvas_basicas", "botas":"botas_basicas"}
	perfil.visual.escudo = true
	perfil.equipamentos = {"arma":{"nivel":12,"raridade":"epico"}}
	# Sem conexão externa na revisão: o retrato usa o mesmo envelope enviado pelo servidor.
	j.remove_from_group("character")
	duelo.ping_ms = 24
	duelo.eu = "a"
	duelo.sala = {"id":12,"titulo":"Duelo dos aventureiros", "senha":false,"dono":"a", "jogadores":[{"id":"a","apelido":"AVENTUREIRO","pronto":true,"perfil":perfil},{"id":"b","apelido":"GUARDIA DO BOSQUE","pronto":true,"perfil":perfil}]}
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	for modo in ["pc", "celular", "metade"]:
		root.get_node("Controle").usando_toque = modo == "celular"
		root.content_scale_size = Vector2i(320,324) if modo == "metade" else Vector2i(576,324)
		root.size = Vector2i(640,648) if modo == "metade" else Vector2i(1152,648)
		await esperar()
		await foto(modo + "-hud")
		duelo.abrir_tela()
		await esperar(30)
		var tela = root.get_node("TelaSalasDuelo")
		var slots = tela.find_children("Equipamento_*", "Button", true, false)
		conferir(slots.size() == 12, modo + ": seis slots por jogador")
		for slot in slots:
			conferir(slot.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE, modo + ": slot somente de inspeção")
		var arma = slots.filter(func(s): return s.name == "Equipamento_arma")[0]
		arma.pressed.emit()
		await esperar()
		conferir(arma.tooltip_text.contains("12"), "nível real da arma")
		for botao in tela._acoes.find_children("*", "Button", true, false):
			conferir(root.get_visible_rect().encloses(botao.get_global_rect()), modo + ": ação visível " + botao.text)
		await foto(modo + "-sala")
		tela._mostrar(tela.Vista.LISTA)
		await esperar()
		await foto(modo + "-lista")
		tela.queue_free()
		await esperar()
	current_scene.queue_free()
	await esperar(8)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
