extends SceneTree

## Prévia com os mapas reais. Execute na cópia de testes para preservar todos os saves.
## godot --path <copia> --script res://ferramentas/cidade/render_cidade.gd -- <pasta>
var pasta := ""

func _initialize() -> void:
	_rodar()

func _quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute a previa com saves isolados.")
		quit(1)
		return
	pasta = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1408, 1152)
	root.content_scale_size = Vector2i(704, 576)
	for tomada in [
		["cidade_primavera", "res://cenas/cidade.tscn", 1, 12.0, ""],
		["cidade_noite", "res://cenas/cidade.tscn", 7, 19.0, ""],
		["cidade_inverno", "res://cenas/cidade.tscn", 22, 12.0, ""],
		["pousada_inverno", "res://cenas/cidade/pousada.tscn", 22, 12.0, ""],
		["venda", "res://cenas/cidade/venda.tscn", 1, 12.0, ""],
		["sede", "res://cenas/cidade/sede.tscn", 1, 12.0, ""],
		["enfermaria", "res://cenas/cidade/enfermaria.tscn", 1, 12.0, ""],
		["mistica", "res://cenas/cidade/mistica.tscn", 1, 12.0, ""],
		["casa_bento", "res://cenas/cidade/casa_bento.tscn", 1, 12.0, ""],
		["cidade_jogo", "res://cenas/cidade.tscn", 1, 12.0, ""],
		["escala_npcs", "res://cenas/cidade.tscn", 1, 12.0, ""],
		["fazenda_ligacao", "res://cenas/fazenda.tscn", 1, 12.0, ""],
		["conversa", "res://cenas/cidade.tscn", 1, 12.0, "bento"],
		["conversa_lia", "res://cenas/cidade.tscn", 1, 12.0, "lia"],
		["mural", "res://cenas/cidade.tscn", 1, 12.0, "mural"],
	]:
		root.size = Vector2i(1408, 1152)
		root.content_scale_size = Vector2i(704, 576)
		if current_scene != null:
			current_scene.queue_free()
			await _quadros()
		root.get_node("Calendario").dia = tomada[2]
		root.get_node("Transicao").hora_salva = tomada[3]
		var cena: Node = load(tomada[1]).instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		cena.get_node("Iluminacao").set_process(false)
		cena.get_node("Iluminacao")._aplicar()
		var jogador: Node = cena.get_node("Jogador")
		if cena.get("local") == "cidade":
			jogador.position = Vector2(392, 360)
			jogador.camera.position_smoothing_enabled = false
			jogador.camera.set_as_top_level(true)
			jogador.camera.global_position = Vector2(352, 288)
		var hud: Node = get_nodes_in_group("hud")[0]
		if hud.get_node_or_null("MiniTutorial") != null:
			hud.get_node("MiniTutorial").set_process(false)
			hud.get_node("MiniTutorial").visible = false
		if tomada[4] != "":
			root.content_scale_size = Vector2i(576, 324)
			if tomada[4] == "mural":
				root.get_node("EventosJogo").abrir_tela.emit("mural_cidade")
			else:
				root.get_node("Cidade").conversar(tomada[4])
		if tomada[0] == "cidade_jogo":
			root.size = Vector2i(1152, 648)
			root.content_scale_size = Vector2i(576, 324)
			jogador.camera.global_position = jogador.position
		if tomada[0] == "escala_npcs":
			root.size = Vector2i(1152, 648)
			root.content_scale_size = Vector2i(576, 324)
			jogador.position = Vector2(520, 348)
			jogador.camera.global_position = Vector2(352, 320)
			var i := 0
			for npc in cena.moradores.values():
				npc.set_process(false)
				npc.set_physics_process(false)
				npc.visible = true
				npc.position = Vector2(184 + i * 48, 350)
				npc.sprite.frame = 1
				npc.z_index = 352
				i += 1
		if tomada[0] == "fazenda_ligacao":
			root.size = Vector2i(1152, 648)
			root.content_scale_size = Vector2i(576, 324)
			jogador.position = cena.get_node("Terrains/Chegada_cidade").position
			jogador.camera.position_smoothing_enabled = false
			jogador.camera.reset_smoothing()
		await _quadros(20)
		root.get_texture().get_image().save_png(pasta.path_join(tomada[0] + ".png"))
		print("salvo: ", tomada[0])
	current_scene.queue_free()
	current_scene = null
	await _quadros()
	quit()
