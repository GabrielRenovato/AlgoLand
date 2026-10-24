extends SceneTree
## Área reservada ao ranking: piso, circulação e capturas das quatro estações, em save isolado.
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n: await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/custom_user_dir_name") != "AlgoLand testes praca ranking 20261023":
		push_error("Use a cópia isolada da praça do ranking.")
		quit(1)
		return
	await process_frame
	root.size = Vector2i(1408,1152)
	root.content_scale_size = Vector2i(704,576)
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 12.0
	var vila: Node2D = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros(20)
	var jogador: Node2D = vila.get_node("Jogador")
	jogador.position = Vector2(392,384)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(368,288)
	var luz: Node = vila.get_node("Iluminacao")
	luz.set_process(false)
	var hud: Node = get_nodes_in_group("hud")[0]
	if hud.get_node_or_null("MiniTutorial") != null: hud.get_node("MiniTutorial").hide()
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	var area: Array = dados._layout.area_ranking
	var reserva := Rect2(area[0],area[1],area[2],area[3])
	var terreno: TileMapLayer = vila.get_node("Terrains/Terreno")
	var pedra := true
	var livre := true
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.collision_mask = 64
	consulta.exclude = [vila.get_node("PodioRanking/BaseFisica").get_rid()]
	for y in range(int(reserva.position.y),int(reserva.end.y),8):
		for x in range(int(reserva.position.x),int(reserva.end.x),8):
			var ponto := Vector2(x+4,y+4)
			pedra = pedra and terreno.get_cell_source_id(terreno.local_to_map(ponto)) == 1
			consulta.position = ponto
			livre = livre and vila.get_world_2d().direct_space_state.intersect_point(consulta).is_empty()
	verificar("reserva do pódio inteiramente pavimentada",pedra)
	verificar("reserva do pódio sem obstáculos alheios à construção",livre)
	for destino in [Vector2(48,272),Vector2(636,272),Vector2(336,210),Vector2(336,392),dados.ponto("mural"),dados.ponto("podio_ranking")]:
		verificar("circulação até %s" % destino,not vila.caminho_entre(Vector2(392,384),destino).is_empty())
	for estacao in 4:
		root.get_node("Calendario").dia = 1+estacao*30
		root.get_node("Calendario").estacao_mudou.emit(estacao)
		await quadros(100)
		vila._ao_estacao(estacao)
		luz._aplicar()
		await quadros(25)
		verificar("piso sazonal %d" % estacao,vila._estacao_visual == estacao)
		if "--capturar" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-praca-ranking-%d.png" % estacao)
	current_scene = null
	vila.queue_free()
	await quadros(8)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
