extends "res://testes/teste_rolagem_mural.gd"

func mover(jogador: Node2D, acao: String, quantidade := 65) -> void:
	Input.action_press(jogador.acao(acao))
	await quadros(quantidade)
	Input.action_release(jogador.acao(acao))
	await quadros(12)

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(20)
	var praia: Node2D = current_scene
	praia.get_node("Iluminacao").set_process(false)
	var jogador: CharacterBody2D = praia.get_node("Jogador")
	var efeito: Node2D = praia.get_node("PegadasPraia")
	var grafico := DisplayServer.get_name() != "headless"
	if grafico:
		root.content_scale_size = Vector2i(704,576)
		root.size = Vector2i(1408,1152)
		jogador.camera.set_as_top_level(true)
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.zoom = Vector2.ONE
		jogador.camera.global_position = Vector2(352,288)
	verificar("efeito fica entre a areia e os objetos",efeito.z_index > praia.get_node("Terrains/AreiaMar").z_index and efeito.z_index < -998)
	verificar("areia aceita marcas",efeito.areia_no_ponto(Vector2(230,230)))
	verificar("agua e cais rejeitam marcas",not efeito.areia_no_ponto(Vector2(240,410)) and not efeito.areia_no_ponto(Vector2(352,400)))
	for caminho in ["Terrains/CalcadaOrla","Terrains/VegetacaoOrla"]:
		var piso: TileMapLayer = praia.get_node(caminho)
		var ponto := piso.to_global(piso.map_to_local(piso.get_used_cells()[0]))
		verificar("sem pegadas sobre " + caminho,not efeito.areia_no_ponto(ponto))
	for estacao in 4:
		root.get_node("Calendario").dia = estacao*30+1
		root.get_node("Calendario").estacao_mudou.emit(estacao)
		await quadros(3)
		efeito.marcas.clear()
		jogador.position = Vector2(210,220)
		jogador.velocity = Vector2.ZERO
		await quadros(3)
		await mover(jogador,"move_right")
		verificar("movimento real deixa pegadas na estacao %d" % estacao,efeito.marcas.size() >= 4)
		var quantidade: int = efeito.marcas.size()
		await quadros(12)
		verificar("parado nao cria pegadas na estacao %d" % estacao,efeito.marcas.size() == quantidade)
		var somente_areia := true
		for marca in efeito.marcas:
			for pixel in marca["pixels"]:
				somente_areia = somente_areia and efeito.areia_no_ponto(pixel)
		verificar("solas inteiras ficam na areia na estacao %d" % estacao,somente_areia)
		if grafico:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-pegadas-praia-%d.png" % estacao)
	# Mover no píer e saltar de posição não deixam um rastro atravessando o mapa.
	efeito.marcas.clear()
	jogador.position = Vector2(352,390)
	jogador.velocity = Vector2.ZERO
	await quadros(3)
	await mover(jogador,"move_down",20)
	verificar("corrida no cais nao marca madeira nem mar",efeito.marcas.is_empty())
	jogador.position = Vector2(220,220)
	jogador.velocity = Vector2.ZERO
	await quadros(3)
	verificar("teleporte nao cria trilha",efeito.marcas.is_empty())
	await mover(jogador,"move_right",25)
	efeito._physics_process(efeito.DURACAO+1)
	verificar("pegadas somem depois do tempo de vida",efeito.marcas.is_empty())
	# Os dois jogadores são rastreados na praia compartilhada.
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(20)
	var coop: Node = root.get_node("Cooperativo")
	praia = current_scene
	efeito = praia.get_node("PegadasPraia")
	var p1: CharacterBody2D = coop._jogador1()
	var p2: CharacterBody2D = coop.jogador2()
	p1.position = Vector2(210,220)
	p2.position = Vector2(210,250)
	await quadros(3)
	await mover(p1,"move_right",25)
	var antes: int = efeito.marcas.size()
	await mover(p2,"move_right",25)
	verificar("P1 e P2 deixam rastros independentes",antes > 0 and efeito.marcas.size() > antes)
	await coop.viajar_local(p2,"res://cenas/palafita.tscn","entrada")
	await quadros(3)
	verificar("jogador em outro ambiente sai do rastreamento",not efeito._passos.has(p2.get_instance_id()))
	current_scene.queue_free()
	await quadros()
	print("Pegadas praia: %d falhas" % falhas)
	quit(1 if falhas else 0)
