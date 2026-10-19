extends "res://testes/teste_rolagem_mural.gd"

## Regressão: carregar a taverna no jantar não pode criar moradores dentro dos bancos.
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	if DisplayServer.get_name() == "headless":
		root.get_node("Controle").usando_toque = true
	root.get_node("Introducao").pular_prologo()
	var festa := "--festa" in OS.get_cmdline_user_args()
	root.get_node("Calendario").dia = 6 if festa else 2
	root.get_node("Transicao").hora_salva = 20.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(4)
	var taverna: Node2D = current_scene
	taverna.set_process(false)
	taverna.get_node("Iluminacao").definir_hora(20.0)
	taverna.get_node("Iluminacao").set_process(false)
	taverna.get_node("RotinaTaverna").set_process(false)
	taverna.get_node("Jogador").position = Vector2(560,280)
	var clientes: Array = []
	for npc in taverna.moradores.values():
		npc.set_physics_process(false)
		npc._espera_balao = INF
		if npc.visible and npc.id in npc.Dados.LUGARES_FESTA:
			clientes.append(npc)
			var forma: CollisionShape2D = npc.get_node("CollisionShape2D")
			var consulta := PhysicsShapeQueryParameters2D.new()
			consulta.shape = forma.shape
			consulta.transform = forma.global_transform
			consulta.collision_mask = 64
			verificar("jantar inicia fora dos moveis: " + npc.id, taverna.get_world_2d().direct_space_state.intersect_shape(consulta).is_empty())
	verificar("jantar inclui o ferreiro da imagem",clientes.has(taverna.moradores["ferreiro"]))
	for passo in 400:
		for npc in clientes:
			npc._physics_process(0.1)
		await physics_frame
		if clientes.all(func(npc): return npc.assento.estado == "sentado"):
			break
	for npc in clientes:
		print("DIAGNOSTICO ",npc.id," pos=",npc.position," assento=",npc.assento.estado," rota=",npc.caminho)
		verificar("alcanca o banco e senta: " + npc.id,npc.assento.estado == "sentado")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-taverna-bancos-festa.png" if festa else "/tmp/algoland-taverna-bancos.png")
	taverna.get_node("Iluminacao").definir_hora(2.0 if festa else 22.0)
	for npc in clientes:
		npc.atualizar_rotina()
	for passo in 700:
		for npc in clientes:
			npc._physics_process(0.1)
		await physics_frame
		if clientes.all(func(npc): return not npc.visible or npc.dormindo):
			break
	for npc in clientes:
		# A Lia mora na pousada: vai para a cama em vez de sair pela porta.
		verificar("levanta e retoma a agenda sem prender nos bancos: " + npc.id,(not npc.visible or npc.dormindo) and npc.assento.estado == "pe")
	current_scene.queue_free()
	await quadros()
	print("Taverna bancos: %d falhas" % falhas)
	quit(1 if falhas else 0)
