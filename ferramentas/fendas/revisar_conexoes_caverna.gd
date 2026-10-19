extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_conexoes/"
const SAIDA := "res://arte/previas/fenda/caverna_conexoes/"
const NOMES := {"0":"rocha", "1":"externo_sudeste", "2":"externo_sudoeste", "3":"parede_sul", "4":"externo_nordeste", "5":"parede_leste", "7":"interno_sudeste", "8":"externo_noroeste", "10":"parede_oeste", "11":"interno_sudoeste", "12":"parede_norte", "13":"interno_nordeste", "14":"interno_noroeste", "15":"piso"}

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if DisplayServer.get_name() == "headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Usar execução gráfica e save isolado")
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "bancada.json"))
	var fonte := TileSetAtlasSource.new()
	fonte.texture = load(BASE + "atlas.png")
	fonte.texture_region_size = Vector2i(16,16)
	for y in 16:
		for x in 16:
			fonte.create_tile(Vector2i(x,y))
	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(16,16)
	conjunto.add_source(fonte,0)
	for chave: String in dados.pecas:
		var espelhada: bool = dados.espelhadas.has(chave)
		var origem: Array = dados.pecas[dados.espelhadas[chave] if espelhada else chave]
		var padrao := TileMapPattern.new()
		padrao.resource_name = NOMES[chave]
		for y in 4:
			for x in 4:
				padrao.set_cell(Vector2i(x,y),0,Vector2i(int(origem[0])*4+(3-x if espelhada else x),int(origem[1])*4+y),TileSetAtlasSource.TRANSFORM_FLIP_H if espelhada else 0)
		conjunto.add_pattern(padrao)
	for variante in 2:
		var padrao := TileMapPattern.new()
		padrao.resource_name = "piso_variante_" + str(variante + 1)
		for y in 4:
			for x in 4:
				padrao.set_cell(Vector2i(x,y),0,Vector2i(12+x,variante*4+y),0)
		conjunto.add_pattern(padrao)
	ResourceSaver.save(conjunto, BASE + "caverna.tres")
	var cena := Node2D.new()
	cena.name = "BancadaConexoesCaverna"
	cena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fundo := Polygon2D.new()
	fundo.name = "RochaNaoEscavada"
	fundo.polygon = PackedVector2Array([Vector2.ZERO,Vector2(dados.tamanho[0],0),Vector2(dados.tamanho[0],dados.tamanho[1]),Vector2(0,dados.tamanho[1])])
	fundo.color = Color.BLACK
	fundo.z_index = -1
	cena.add_child(fundo)
	fundo.owner = cena
	var mapa := TileMapLayer.new()
	mapa.name = "Caverna"
	mapa.material = CanvasItemMaterial.new()
	mapa.tile_set = conjunto
	mapa.collision_enabled = false
	mapa.navigation_enabled = false
	cena.add_child(mapa)
	mapa.owner = cena
	for c: Array in dados.celulas:
		mapa.set_cell(Vector2i(c[0],c[1]),0,Vector2i(c[2],c[3]),int(c[4]))
	var packed := PackedScene.new()
	packed.pack(cena)
	ResourceSaver.save(packed,"res://cenas/fendas/previa_conexoes_caverna.tscn")
	var vista := SubViewport.new()
	vista.size = Vector2i(dados.tamanho[0], dados.tamanho[1])
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	vista.add_child(cena)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	vista.get_texture().get_image().save_png(SAIDA + "bancada_godot.png")
	var detalhe := vista.get_texture().get_image().get_region(Rect2i(320,64,256,256))
	detalhe.resize(768,768,Image.INTERPOLATE_NEAREST)
	detalhe.save_png(SAIDA + "detalhe_godot.png")
	print("BANCADA: 14 máscaras, grade16, material explícito; captura salva para avaliação artística")
	quit()
