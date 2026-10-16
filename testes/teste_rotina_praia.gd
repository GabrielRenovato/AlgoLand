extends SceneTree

var Dados: GDScript
const Rotina := preload("res://codigo/pesca/rotina_nilo.gd")
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
	await physics_frame

func carregar(caminho: String, hora: float) -> Node2D:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await quadros()
	root.get_node("Transicao").hora_salva = hora
	var cena: Node2D = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Iluminacao").set_process(false)
	return cena

func caminhar(npc: Node2D) -> void:
	npc.set_physics_process(false)
	for i in 2400:
		if not npc.visible:
			break
		npc._physics_process(1.0 / 30)
		if i % 100 == 0:
			await quadros(1)

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/custom_user_dir_name") != "AlgoLand testes praia 20261016":
		push_error("Use a cópia isolada da praia.")
		quit(1)
		return
	await process_frame
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Calendario").dia = 1
	for faixa in [[6.0, "palafita"], [8.0, "praia"], [12.0, "praia"], [17.0, "praia"], [19.0, "palafita"], [23.0, "palafita"]]:
		verificar("agenda do Nilo às %dh" % faixa[0], Rotina.agenda(faixa[0], 0)["local"] == faixa[1])
	verificar("Nilo dorme à noite", Rotina.agenda(23, 0).get("dormindo", false))
	for clima in [3, 4, 6]:
		verificar("Nilo se abriga no clima %d" % clima, Rotina.agenda(12, clima)["local"] == "palafita")
	for id in Dados.MORADORES:
		var folga: int = Dados.FOLGAS[id]
		verificar("%s visita na folga" % id, Dados.agenda(id, 12, 0, 0, folga)["local"] == "praia")
		verificar("%s evita praia no inverno" % id, Dados.agenda(id, 12, 3, 0, folga)["local"] != "praia")
		verificar("%s evita praia no temporal" % id, Dados.agenda(id, 12, 0, 4, folga)["local"] == Dados.MORADORES[id]["casa"])
		var noite: Dictionary = Dados.agenda(id, 23, 0, 0, folga)
		verificar("%s preserva sono ou festa" % id, noite.get("dormindo", false) or noite.get("festa", false) or id == "bardo")
	verificar("Tomás atende em dia de trabalho", Dados.agenda("mercador", 12, 0, 0, 0)["local"] == "venda")
	verificar("festa continua prioritária", Dados.agenda("mercador", 18.5, 0, 0, 5).get("festa", false))
	var praia := await carregar("res://cenas/praia.tscn", 12)
	verificar("palafita acessível", praia.get_node("PortaPalafita").cena_destino == "res://cenas/palafita.tscn")
	var nilo: Node2D = praia.get_node("Nilo")
	verificar("Nilo começa no píer com a hora restaurada", nilo.visible and nilo.position.distance_to(Vector2(342, 404)) < 2)
	praia.get_node("Jogador").position = Vector2(336, 64)
	praia.get_node("Iluminacao").definir_hora(18)
	nilo.atualizar_rotina()
	verificar("Nilo sai andando para casa", nilo._saindo and not nilo.caminho.is_empty())
	await caminhar(nilo)
	verificar("Nilo alcança a porta sem atravessar o mar", not nilo.visible)
	verificar("trajeto praia/casa é direto", root.get_node("Cidade").trajetos_moradores.get("nilo", {}).get("fase") == "chegou")
	var casa := await carregar("res://cenas/palafita.tscn", 19)
	var morador: Node2D = casa.get_node("Nilo")
	verificar("Nilo janta em casa", morador.visible and not morador.dormindo)
	verificar("saída da casa retorna à praia", casa.get_node("Saida").cena_destino == "res://cenas/praia.tscn")
	verificar("cama e mesa bloqueiam caminho", casa.get_node("Obstaculos/Cama") != null and casa.get_node("Obstaculos/Mesa") != null)
	casa.get_node("Jogador").position = Vector2(80, 170)
	casa.get_node("Iluminacao").definir_hora(21)
	morador.atualizar_rotina()
	morador.set_physics_process(false)
	for i in 600:
		morador._physics_process(1.0 / 30)
		if morador.dormindo:
			break
	await quadros()
	if not morador.dormindo:
		print("Sono: posição=", morador.position, " caminho=", morador.caminho, " agenda=", morador.agenda)
	verificar("Nilo chega à cama e dorme", morador.dormindo and not morador.interacao.monitoring)
	if "--capturar" in OS.get_cmdline_user_args():
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/praia/nilo_dormindo.png")
	casa.get_node("Iluminacao").definir_hora(7)
	morador.atualizar_rotina()
	await caminhar(morador)
	verificar("Nilo acorda e sai de casa", not morador.dormindo and not morador.visible)
	root.get_node("Cidade").trajetos_moradores.clear()
	var vila := await carregar("res://cenas/cidade.tscn", 9)
	var caio: Node2D = vila.moradores["bardo"]
	vila.get_node("Jogador").position = Vector2(50, 272)
	verificar("Caio começa a folga na vila", caio.visible and caio.agenda["local"] == "cidade")
	vila.get_node("Iluminacao").definir_hora(10)
	caio.atualizar_rotina()
	verificar("visita começa caminhando até a saída sul", caio._saindo and caio.agenda["local"] == "praia" and not caio.caminho.is_empty())
	await caminhar(caio)
	verificar("visitante alcança a saída sul", not caio.visible)
	praia = await carregar("res://cenas/praia.tscn", 12)
	var visitante: Node2D = praia.moradores["bardo"]
	verificar("mesmo visitante aparece na praia", visitante.visible and visitante.agenda["local"] == "praia")
	praia.get_node("Jogador").position = Vector2(390, 240)
	praia.get_node("Iluminacao").definir_hora(16)
	visitante.atualizar_rotina()
	verificar("passeio termina com volta à vila", visitante._saindo and visitante.agenda["local"] == "cidade")
	await caminhar(visitante)
	verificar("visitante consegue retornar pela entrada norte", not visitante.visible)
	praia.get_node("Iluminacao").definir_hora(12)
	if "--capturar" in OS.get_cmdline_user_args():
		var jogador: Node2D = praia.get_node("Jogador")
		jogador.position = Vector2(390, 240)
		root.size = Vector2i(1408, 1152)
		root.content_scale_size = Vector2i(704, 576)
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.set_as_top_level(true)
		jogador.camera.global_position = Vector2(352, 288)
		jogador.camera.zoom = Vector2.ONE
		await create_timer(0.7).timeout
		await quadros(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/praia/palafita_praia.png")
	print("Rotina da praia: %d verificações, %d falhas." % [verificacoes, falhas])
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit(1 if falhas else 0)
