extends SceneTree

var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n: await process_frame
	await physics_frame
func bloqueado(cena: Node2D, ponto: Vector2) -> bool:
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.position = ponto
	consulta.collision_mask = 64
	return not cena.get_world_2d().direct_space_state.intersect_point(consulta).is_empty()
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").refeicao = ""
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1408,1152)
	root.content_scale_size = Vector2i(704,576)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/rotas"))
	for mapa in ["cidade","praia"]:
		change_scene_to_file("res://cenas/%s.tscn" % mapa)
		await quadros(30)
		var cena: Node2D = current_scene
		var jogador: Node2D = cena.get_node("Jogador")
		jogador.set_physics_process(false)
		var camera: Camera2D = jogador.get_node("Camera2D")
		camera.set_as_top_level(true)
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE
		camera.global_position = Vector2(352,288)
		cena.get_node("Iluminacao").definir_hora(12)
		cena.get_node("Iluminacao").set_process(false)
		for camada in ["Interface","assets/ui","Vinheta"]:
			var no := cena.get_node_or_null(camada)
			if no is CanvasLayer: no.hide()
			elif no is CanvasItem: no.hide()
		if mapa == "cidade":
			verificar("praia atravessa andando para sul",cena.get_node("TrilhaPraia").direcao_saida == Vector2.DOWN)
			verificar("fazenda atravessa andando para oeste",cena.get_node("TrilhaFazenda").direcao_saida == Vector2.LEFT)
			for x in [8,16,24,40,64]:
				verificar("rua da fazenda livre %d" % x,not bloqueado(cena,Vector2(x,272)))
			for y in range(464,576,8):
				verificar("rua da praia livre %d" % y,not bloqueado(cena,Vector2(336,y)))
			for ponto in [Vector2(48,140),Vector2(16,400),Vector2(200,560),Vector2(500,560),Vector2(240,104)]:
				verificar("cerca bloqueia borda %s" % ponto,bloqueado(cena,ponto-Vector2(0,2)))
		else:
			verificar("retorno da praia automático",cena.get_node("VoltaCidade").direcao_saida == Vector2.UP)
		for estacao in 4:
			root.get_node("Calendario").dia = 1+30*estacao
			root.get_node("Calendario").estacao_mudou.emit(estacao)
			await create_timer(1.8).timeout
			verificar("%s estação visual %d" % [mapa,estacao],cena.estacao_visual()==estacao)
			if mapa == "praia":
				var textura: Texture2D = cena.get_node("Terrains/CalcadaOrla").tile_set.get_source(0).texture
				verificar("orla usa atlas sazonal %d: %s" % [estacao,textura.resource_path],textura.resource_path.ends_with(["primavera","verao","outono","inverno"][estacao]+".png"))
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://arte/previas/rotas/%s_%d.png" % [mapa,estacao])
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
