extends "res://testes/teste_praia.gd"

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("InventarioJogador").criar_itens_iniciais()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(704,576)
	root.size = Vector2i(1408,1152)
	var praia := await carregar("res://cenas/praia.tscn")
	var camera: Camera2D = praia.get_node("Jogador").camera
	camera.position_smoothing_enabled = false
	camera.set_as_top_level(true)
	camera.global_position = Vector2(352,288)
	camera.zoom = Vector2.ONE
	for hud in get_nodes_in_group("hud"): hud.hide()
	var pasta := "res://arte/previas/praia/enseada"
	DirAccess.make_dir_recursive_absolute(pasta)
	var nomes := ["primavera","verao","outono","inverno"]
	verificar("mata reutiliza a vegetacao sazonal da vila",praia.has_node("VegetacaoOrla") and praia.get_node("VegetacaoOrla").get_child_count()>=19)
	for i in 4:
		root.get_node("Calendario").dia = 1+i*30
		root.get_node("Calendario").estacao_mudou.emit(i)
		await quadros(24)
		var estrela: Sprite2D = praia.get_node("DecoracaoPraia/estrela_mar_186_302/Imagem")
		verificar("estrela recebe estacao: "+nomes[i],estrela.texture.resource_path.ends_with(nomes[i]+".png"))
		verificar("estrela mantem quadro de 16px: "+nomes[i],(estrela.texture.get_size()*estrela.scale).is_equal_approx(Vector2(16,16)))
		var grama: TileMapLayer = praia.get_node("Terrains/VegetacaoOrla")
		verificar("grama e transicoes integradas: "+nomes[i], (grama.tile_set.get_source(0) as TileSetAtlasSource).texture.resource_path.ends_with(nomes[i]+".png"))
		var arvore := praia.get_node("VegetacaoOrla/arvore_16_80/Imagem") as Sprite2D
		verificar("mata acompanha estacao: "+nomes[i],arvore.texture.resource_path.ends_with(nomes[i]+".png"))
		verificar("tablado recebe estacao: "+nomes[i],praia.get_node("Terrains/Pier").material.get_shader_parameter("estacao")==i)
		verificar("cais sem cercas da fazenda",not praia.has_node("Corrimaos"))
		verificar("mar recebe estacao: "+nomes[i],praia.material_mar.get_shader_parameter("estacao")==i)
		verificar("entrada, areia e cais livres: "+nomes[i],not corpo_bloqueado(praia.get_node("Jogador"),Vector2(336,100)) and not corpo_bloqueado(praia.get_node("Jogador"),Vector2(336,240)) and not corpo_bloqueado(praia.get_node("Jogador"),Vector2(360,450)))
		await RenderingServer.frame_post_draw
		verificar("captura geral: "+nomes[i],root.get_texture().get_image().save_png(pasta+"/"+nomes[i]+"_geral.png")==OK)
		camera.zoom = Vector2.ONE*2
		camera.global_position = Vector2(128,248)
		await quadros(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"/"+nomes[i]+"_margem.png")
		camera.zoom = Vector2.ONE*2
		camera.global_position = Vector2(304,432)
		await quadros(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"/"+nomes[i]+"_cais.png")
		camera.zoom = Vector2.ONE*4
		camera.global_position = Vector2(186,296)
		await quadros(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"/"+nomes[i]+"_estrela.png")
		camera.zoom = Vector2.ONE
		camera.global_position = Vector2(352,288)
	current_scene.queue_free()
	await quadros()
	print("Enseada visual: %d falhas" % falhas)
	quit(1 if falhas else 0)
