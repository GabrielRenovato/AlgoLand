extends "res://testes/teste_rolagem_mural.gd"

const Perfis := preload("res://codigo/cidade/perfis_rotina.gd")

func atores(cena: Node) -> Array:
	return get_nodes_in_group("moradores_cidade").filter(func(npc): return npc.vila == cena)

func preparar(cena: Node) -> void:
	cena.set_process(false)
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Jogador").position = Vector2(40,100)
	for npc in atores(cena):
		npc.set_physics_process(false)
		npc._saindo = false
		npc.dormindo = false
		npc.visible = true
		npc.agenda = {"local":cena.local,"livre":true,"atividade":"Tempo livre"}
		npc.passeio.rng.seed = 4321
		npc.position = Vector2(336,240)
		if "_rotina_em" in npc: npc._rotina_em = INF
		if "_espera_balao" in npc: npc._espera_balao = INF
		npc._atualizar_colisao()

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	for local in ["cidade","praia"]:
		change_scene_to_file("res://cenas/%s.tscn" % local)
		await quadros(20)
		var cena: Node2D = current_scene
		preparar(cena)
		var interesses := {}
		for npc in atores(cena):
			var memoria: Array[String] = []
			var variado := true
			for i in 7:
				npc.caminho.clear()
				npc.passeio.espera = 0
				npc.passeio.atualizar(npc,0.1)
				variado = variado and not npc.caminho.is_empty() and npc.passeio.atual not in memoria
				memoria.append(npc.passeio.atual)
				if memoria.size() > 3: memoria.pop_front()
				if not npc.caminho.is_empty(): npc.position = npc.caminho[-1]
				interesses[npc.agenda["atividade"]] = true
			verificar("afazeres individuais sem repetir os tres ultimos: %s/%s" % [local,npc.id],variado)
		verificar("ocupacoes de todos os moradores sao diferentes: " + local,interesses.size() >= 8*4)
		var rota_a := cena.caminho_morador(Vector2(336,240),Vector2(336,64),"mercador")
		var rota_b := cena.caminho_morador(Vector2(336,240),Vector2(336,64),"curandeira")
		verificar("mesma origem e destino permitem percursos pessoais: " + local,not rota_a.is_empty() and not rota_b.is_empty() and rota_a != rota_b)
		if local == "praia":
			var vistos := {}
			for npc in atores(cena):
				npc.position = cena.navegacao.get_point_position(cena._celula_livre(Perfis.PERFIS[npc.id]["orla"]))
				npc.caminho.clear()
				npc.passeio.espera = 0
				vistos[npc.id] = {}
			for passo in 720:
				for npc in atores(cena):
					npc._physics_process(0.5)
					vistos[npc.id][npc.agenda["atividade"]] = true
				await physics_frame
			for npc in atores(cena):
				print("ROTINA ",npc.id,": ",vistos[npc.id].keys())
				verificar("vida continua em movimento real: " + npc.id,vistos[npc.id].size() >= 3)
			if DisplayServer.get_name() != "headless":
				root.content_scale_size = Vector2i(704,576)
				root.size = Vector2i(1408,1152)
				var camera: Camera2D = cena.get_node("Jogador").camera
				camera.set_as_top_level(true)
				camera.position_smoothing_enabled = false
				camera.global_position = Vector2(352,240)
				camera.zoom = Vector2(1.5,1.5)
				await quadros(4)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-vida-moradores-praia.png")
	current_scene.queue_free()
	await quadros()
	print("Vida moradores: %d falhas" % falhas)
	quit(1 if falhas else 0)
