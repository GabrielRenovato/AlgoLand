extends SceneTree

## Capturas reais da biblioteca de interiores. Exige projeto e saves isolados.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use projeto e saves isolados para revisar interiores.")
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	var antes := OS.get_cmdline_user_args().has("--antes")
	var pasta := "/tmp/algoland-interiores-antes/" if antes else "res://arte/previas/cidade/interiores_detalhados/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var casas: Dictionary = load("res://codigo/cidade/interior_casa.gd").dados()["casas"].duplicate(true)
	casas["palafita"] = {"geometria": {"recorte": [0, 0, 320, 224]}}
	var filtros := Array(OS.get_cmdline_user_args()).filter(func(arg): return arg.begins_with("--casa="))
	for id: String in casas:
		if not filtros.is_empty() and not filtros.has("--casa=" + id):
			continue
		var caminho := "res://cenas/casa.tscn" if id == "casa_jogador" else "res://cenas/cidade/" + id + ".tscn"
		if id == "palafita":
			caminho = "res://cenas/palafita.tscn"
		root.get_node("Calendario").dia = 1
		root.get_node("Transicao").hora_salva = 12.0
		change_scene_to_file(caminho)
		await quadros(18)
		var sala: Node2D = current_scene.get_node("Interior/Sala")
		var jogador: Node2D = current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.hide()
		if current_scene.has_node("Iluminacao"):
			current_scene.get_node("Iluminacao").set_process(false)
			current_scene.get_node("Iluminacao").definir_hora(12)
		for morador in current_scene.get("moradores").values() if current_scene.get("moradores") is Dictionary else []:
			morador.set_physics_process(false)
			morador.hide()
		if id == "forja" and "--forja-fraca-forte" in OS.get_cmdline_user_args():
			var trabalho: Node = current_scene.get_node("Bigorna/TrabalhoFerreiro")
			if trabalho.ocupado(): trabalho._concluir("")
			trabalho.set_physics_process(false)
		var tamanho := Vector2(casas[id]["geometria"]["recorte"][2], casas[id]["geometria"]["recorte"][3])
		var vp := SubViewport.new()
		vp.size = Vector2i(tamanho * 2)
		vp.world_2d = current_scene.get_world_2d()
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var camera := Camera2D.new()
		camera.position = tamanho * 0.5
		camera.zoom = Vector2(2, 2)
		vp.add_child(camera)
		camera.make_current()
		for estacao in (1 if antes else 4):
			root.get_node("Calendario").dia = 1 + estacao * root.get_node("Calendario").DIAS_POR_ESTACAO
			await quadros(8)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta + id + "_%d.png" % estacao)
			if id == "forja" and "--forja-fraca-forte" in OS.get_cmdline_user_args():
				var combustao: Node = current_scene.get_node("Interior/Fornalha/DetalheAmbiente")
				for forte in [false,true]:
					combustao.vigor = 1.0 if forte else 0.06
					combustao.impulso = 1.0 if forte else 0.0
					await quadros(12)
					await RenderingServer.frame_post_draw
					vp.get_texture().get_image().save_png(pasta+"forja_%d_%s.png" % [estacao,"forte" if forte else "fraca"])

		if OS.get_cmdline_user_args().has("--fogo"):
			root.get_node("Calendario").dia = 1
			await quadros(8)
			for detalhe in current_scene.get_node("Interior").find_children("DetalheAmbiente", "Node", true, false):
				var sprite: Sprite2D = detalhe.imagem
				if not "/lareira/" in sprite.texture.resource_path:
					continue
				detalhe.set_process(false)
				for q in sprite.hframes:
					sprite.frame = q
					await quadros(2)
					await RenderingServer.frame_post_draw
					var area := Rect2i(Vector2i(sprite.to_global(sprite.get_rect().position) * 2), Vector2i(sprite.get_rect().size * sprite.scale * 2))
					vp.get_texture().get_image().get_region(area).save_png(pasta + id + "_fogo_%d.png" % q)
				detalhe.set_process(true)
				break
		if not antes and id == "casa_jogador":
			root.get_node("Calendario").dia = 1
			var cama := current_scene.get_node("Objetos3D/CamaDormindo")
			cama.deitar()
			await quadros(8)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta + "casa_jogador_sono.png")
			cama.levantar()
			var cadeira := current_scene.get_node("ZonaCadeiraE")
			jogador.show()
			cadeira.abrir_tela()
			await quadros(8)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta + "casa_jogador_assento.png")
			cadeira._levantar()
		if not antes and id == "casa_bento":
			root.get_node("Calendario").dia = 1
			var bento: Node2D = current_scene.moradores["bento"]
			bento.agenda = load("res://codigo/cidade/dados_cidade.gd").agenda("bento", 23, 0, 0, 0)
			bento.show()
			bento._deitar()
			await quadros(8)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(pasta + "casa_bento_sono.png")
			bento._acordar()
			bento.hide()
		print("INTERIOR CAPTURADO: ", id)
		vp.queue_free()
		current_scene.queue_free()
		current_scene = null
		await quadros(4)
	quit(falhas)
