extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_pixel_manual/"
const SAIDA := "res://arte/previas/fenda/caverna_pixel_manual/"

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if DisplayServer.get_name()=="headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("A captura exige execução gráfica com save isolado")
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"bancada.json"))
	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(16,16)
	var fonte := TileSetAtlasSource.new()
	fonte.texture = load(BASE+"atlas.png")
	fonte.texture_region_size = Vector2i(16,16)
	for y in 16:
		for x in 16:
			fonte.create_tile(Vector2i(x,y))
	conjunto.add_source(fonte,0)
	for chave: String in dados.pecas:
		var origem: Array = dados.pecas[chave]
		var padrao := TileMapPattern.new()
		padrao.resource_name = "mascara_"+chave
		for y in 4:
			for x in 4:
				padrao.set_cell(Vector2i(x,y),0,Vector2i(int(origem[0])*4+x,int(origem[1])*4+y),0)
		conjunto.add_pattern(padrao)
	assert(ResourceSaver.save(conjunto,BASE+"caverna.tres")==OK)
	var cena := Node2D.new()
	cena.name = "AmostraManualPixelLab"
	cena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mapa := TileMapLayer.new()
	mapa.name = "Caverna"
	mapa.material = CanvasItemMaterial.new()
	mapa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mapa.tile_set = conjunto
	mapa.collision_enabled = false
	mapa.navigation_enabled = false
	cena.add_child(mapa)
	mapa.owner = cena
	for c: Array in dados.celulas:
		mapa.set_cell(Vector2i(c[0],c[1]),0,Vector2i(c[2],c[3]))
	var packed := PackedScene.new()
	assert(packed.pack(cena)==OK)
	assert(ResourceSaver.save(packed,"res://cenas/fendas/amostra_caverna_pixel_manual.tscn")==OK)
	var vista := SubViewport.new()
	vista.size = Vector2i(dados.tamanho[0],dados.tamanho[1])
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	vista.add_child(cena)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var imagem := vista.get_texture().get_image()
	imagem.save_png(SAIDA+"sala_godot.png")
	var geral := imagem.get_region(Rect2i(0,0,448,320))
	geral.resize(896,640,Image.INTERPOLATE_NEAREST)
	geral.save_png(SAIDA+"sala_ampliada.png")
	var detalhe := imagem.get_region(Rect2i(224,16,192,160))
	detalhe.resize(576,480,Image.INTERPOLATE_NEAREST)
	detalhe.save_png(SAIDA+"detalhe_godot.png")
	print("AMOSTRA PIXELLAB: atlas nativo, grade16, 14 padrões e captura gráfica com save isolado")
	quit()
