extends SceneTree

## Revisão de árvores e enseada, sempre em saves isolados.
func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use saves isolados para revisar a praia.")
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	var antes := OS.get_cmdline_user_args().has("--antes")
	var pasta := "/tmp/algoland-praia-antes/" if antes else "res://arte/previas/praia/padrao_novo/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for local in ["cidade", "praia"]:
		root.get_node("Transicao").hora_salva = 12.0
		change_scene_to_file("res://cenas/" + local + ".tscn")
		await quadros(24)
		var jogador: Node2D=current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.hide()
		current_scene.set_process(false)
		for morador in current_scene.get("moradores").values() if current_scene.get("moradores") is Dictionary else []:
			morador.set_physics_process(false)
			morador.hide()
		current_scene.get_node("Iluminacao").set_process(false)
		current_scene.get_node("Iluminacao").definir_hora(12.0)
		root.get_node("Fazenda").definir_clima_hoje(0)
		var tamanho := Vector2i(960, 576) if local == "cidade" else Vector2i(704, 576)
		var vp := SubViewport.new()
		vp.size = tamanho * 2
		vp.world_2d = current_scene.get_world_2d()
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var camera := Camera2D.new()
		camera.position = Vector2(tamanho) * 0.5
		camera.zoom = Vector2(2, 2)
		vp.add_child(camera)
		camera.make_current()
		for e in (1 if antes else 4):
			root.get_node("Calendario").dia = 1 + e * 30
			var estacoes := current_scene.get_node_or_null("Terrains/Estacoes")
			if estacoes != null: estacoes.definir_estacao(e,true)
			root.get_node("Calendario").estacao_mudou.emit(e)
			current_scene._atualizar_ambiente()
			await quadros(20)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta + "%s_%d.png" % [local, e])
		if local=="praia" and not antes:
			root.get_node("Calendario").dia=1
			current_scene._atualizar_ambiente()
			jogador.show()
			jogador.position=Vector2(208,184)
			var assento:=current_scene.get_node("MobiliarioCais/banco_208_176/Assento")
			await quadros(6)
			assento.abrir_tela()
			camera.position=Vector2(208,166)
			camera.zoom=Vector2(4,4)
			await quadros(8)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta+"banco_ocupado.png")
			assento._levantar()
		print("CAPTURA: ", local)
		vp.queue_free()
		current_scene.queue_free()
		current_scene = null
		await quadros(4)
	quit()
