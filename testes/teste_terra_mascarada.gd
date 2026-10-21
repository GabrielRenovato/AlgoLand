extends SceneTree

## Renderiza os dois pares Wang: nenhum pixel de grama, pedra ou guia pode mudar.
const Terra := preload("res://codigo/cenario/terra_mascarada.gd")
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func quadros() -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var vista := SubViewport.new()
	vista.size = Vector2i(128,96)
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var camada := TileMapLayer.new()
	camada.tile_set = load("res://recursos/cidade/tileset_terreno.tres").duplicate(true)
	vista.add_child(camada)
	for y in 6:
		for x in 4:
			camada.set_cell(Vector2i(x,y),0,Vector2i(x,y))
			camada.set_cell(Vector2i(x+4,y),2,Vector2i(x,y))
	var terra := Terra.new()
	terra.configurar(camada,{0:"cidade/%s_grama_terra",2:"cidade/%s_terra_pedra"})
	for estacao in 4:
		var nome: String = Terra.NOMES[estacao]
		var pasta: String = ["primavera","verao","outono","inverno"][estacao]
		for par in [[0,"grama_terra"],[2,"terra_pedra"]]:
			(camada.tile_set.get_source(par[0]) as TileSetAtlasSource).texture = load("res://assets/cenario/algoland_original/%s/%s.png" % [pasta,par[1]])
		terra.aplicar(estacao,false)
		await quadros()
		var antes := vista.get_texture().get_image()
		terra.aplicar(estacao,true)
		await quadros()
		var depois := vista.get_texture().get_image()
		antes.save_png("/tmp/terra-mascara-antes-"+nome+".png")
		depois.save_png("/tmp/terra-mascara-depois-"+nome+".png")
		var preservados := 0
		var alterados := 0
		for par in [[0,"grama_terra"],[64,"terra_pedra"]]:
			var mascara: Image = load("res://assets/cenario/substitutos/terra_mascarada/cidade/%s_%s.png" % [nome,par[1]]).get_image()
			if mascara.is_compressed(): mascara.decompress()
			for y in 96:
				for x in 64:
					var mudou := antes.get_pixel(x+par[0],y).to_rgba32() != depois.get_pixel(x+par[0],y).to_rgba32()
					if mascara.get_pixel(x,y).r < 0.5:
						if mudou: falhas += 1
						else: preservados += 1
					elif mudou: alterados += 1
		if alterados < 100: falhas += 1
		print("TERRA ",nome,": ",preservados," pixels externos preservados; ",alterados," de terra alterados")
		DirAccess.make_dir_recursive_absolute("/tmp/algoland-terra-mascarada")
		depois.resize(512,384,Image.INTERPOLATE_NEAREST)
		depois.save_png("/tmp/algoland-terra-mascarada/"+nome+".png")
	for ativo in [false,true]:
		root.get_node("TilesRefinados").ativo = ativo
		for dados in terra._fontes:
			if not is_equal_approx(float(dados.material.get_shader_parameter("intensidade_acabamento")),1.0 if ativo else 0.0): falhas += 1
	print("RESULTADO TERRA MASCARADA: ",falhas," falhas")
	vista.queue_free()
	await process_frame
	quit(1 if falhas else 0)
