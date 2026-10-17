extends SceneTree
var falhas := 0
var verificacoes := 0
func _initialize() -> void:
	_executar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error("FALHA: " + mensagem)
func quadros(n := 5) -> void:
	for i in n:
		await physics_frame
		await process_frame
func apertar(dispositivo: int, botao: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = botao
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(2)
func _executar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes carroca"):
		quit(1)
		return
	await process_frame
	var saves := root.get_node("Saves")
	saves.trocar("coop")
	var comercio := root.get_node("Comercio")
	comercio.liberado = true
	var fazenda := root.get_node("Fazenda")
	root.get_node("Introducao").pular_prologo()
	comercio.apagar()
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 6
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var coop := root.get_node("Cooperativo")
	coop.dispositivo_p1 = 41
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	p1.global_position = Vector2(504, 310)
	p2.global_position = Vector2(542, 310)
	await quadros()
	verificar(p2 != null and coop.com_dois(), "coop com dois jogadores reais")
	var i1: Node = root.get_node("EventosJogo").interface_p1()
	var i2: Node = coop.interface_p2()
	await apertar(41, JOY_BUTTON_A)
	verificar(i1._telas_abertas.has("comercio"), "controle P1 abre carroca")
	await apertar(40, JOY_BUTTON_A)
	verificar(i2._telas_abertas.has("comercio"), "controle P2 abre carroca na propria metade")
	fazenda.colheita = {"cenoura": 10}
	fazenda.pocoes = {"cura": 2}
	comercio.reservar("colheita:cenoura", 1)
	comercio.reservar("pocao:cura", 2)
	comercio.confirmar(1)
	verificar(not comercio.em_viagem, "partida exige consentimento dos dois")
	comercio.confirmar(2)
	verificar(comercio.em_viagem, "segunda confirmacao inicia viagem")
	var visual: Node2D = current_scene.get_node("Carroca").visual
	verificar(visual.passageiros.get_child_count() == 2, "dois jogadores sentados na mesma carroca")
	verificar(not p1.get_node("CompositeSprites").visible and not p2.get_node("CompositeSprites").visible, "ambos embarcam sem duplicatas em pe")
	if "--capturar" in OS.get_cmdline_user_args():
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/comercio/coop_sentado.png")
	verificar(fazenda.colheita.cenoura == 9 and fazenda.pocoes.cura == 1, "debita bolsa compartilhada uma vez")
	var luz := current_scene.get_node("Iluminacao")
	var hora: float = luz.hora
	await create_timer(0.2).timeout
	verificar(is_equal_approx(hora, luz.hora), "relogio para durante escolhas")
	comercio.eventos.assign(["roda", "viajante"])
	comercio.etapa = 0
	comercio.escolher(0, 1)
	verificar(comercio.etapa == 0, "evento espera segunda escolha")
	comercio.escolher(1, 2)
	verificar(comercio.etapa == 0 and comercio.votos.is_empty(), "divergencia nao aplica duas consequencias")
	comercio.escolher(0, 1)
	comercio.escolher(0, 2)
	verificar(comercio.etapa == 1 and comercio.atraso == 2, "acordo aplica atraso uma vez")
	comercio.escolher(0, 1)
	comercio.escolher(0, 2)
	verificar(comercio.etapa == 2 and comercio.carona, "carona conduz ao mercado")
	var carteira := root.get_node("DadosJogo")
	carteira.moedas = 100
	carteira.moedas_p2 = 50
	verificar(comercio.vender(1, 1) == 0, "P1 nao vende do parceiro")
	comercio.vender(0, 1)
	comercio.vender(0, 2)
	comercio.pedir_retorno(1)
	verificar(comercio.etapa == 2, "mercado espera os dois terminarem")
	comercio.pedir_retorno(2)
	verificar(comercio.etapa == 3, "ambos encerram mercado")
	if "--capturar" in OS.get_cmdline_user_args():
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/comercio/coop.png")
	comercio.voltar()
	await create_timer(3).timeout
	verificar(carteira.moedas == 104 and carteira.moedas_p2 == 62, "ouro creditado em carteiras separadas")
	verificar(root.get_node("Calendario").dia == 2, "retorno do coop consome so um dia")
	verificar(comercio.carta_estrada.begins_with("misterio_"), "carona agenda carta misteriosa pelo pombo")
	verificar(not comercio.em_viagem and p1.movimento_habilitado and p2.movimento_habilitado, "retorno libera ambos")
	verificar(p1.get_node("CompositeSprites").visible and p2.get_node("CompositeSprites").visible, "retorno restaura aparencia dos dois")
	comercio.voltar()
	verificar(carteira.moedas == 104 and carteira.moedas_p2 == 62, "duplo clique no retorno nao duplica ouro")
	# Combate real: input dos dois segue passando pelo roteador de viewports.
	fazenda.colheita.cenoura = 3
	comercio.reservar("colheita:cenoura", 1)
	comercio.iniciar(1)
	comercio.eventos.assign(["monstros", "roda"])
	comercio.etapa = 0
	comercio.escolher(0, 1)
	comercio.escolher(0, 2)
	await quadros()
	verificar(comercio.em_combate and comercio._inimigos.size() == 3, "luta coop compartilha tres monstros")
	verificar(not p1.modo_fazenda and not p2.modo_fazenda, "ambos usam combate existente")
	for inimigo in comercio._inimigos.duplicate():
		inimigo.receber_dano(999)
	await create_timer(0.4).timeout
	await quadros()
	verificar(not comercio.em_combate and comercio.etapa == 1, "vitoria real dos monstros retoma a estrada")
	verificar(p1.modo_fazenda and p2.modo_fazenda, "restaura ferramentas dos dois")
	verificar(i1._telas_abertas.has("comercio") and i2._telas_abertas.has("comercio"), "retoma escolhas nas duas telas")
	comercio.salvar()
	comercio.carregar()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(25)
	i1 = root.get_node("EventosJogo").interface_p1()
	i2 = coop.interface_p2()
	verificar(i1._telas_abertas.has("comercio") and i2._telas_abertas.has("comercio"), "viagem salva reabre nas duas interfaces")
	verificar(comercio.etapa == 1, "retomada preserva etapa concluida")
	print("COMERCIO COOP: %d verificacoes, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)
