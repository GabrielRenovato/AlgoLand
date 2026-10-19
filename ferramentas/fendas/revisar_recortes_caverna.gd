extends SceneTree

const BASE := "res://assets/cenario/fendas/caverna_recortada/"
const SAIDA := "res://arte/previas/fenda/caverna_recortada/"

func _initialize() -> void:
	rodar.call_deferred()

func aguardar() -> void:
	for i in 5:
		await process_frame
		await physics_frame

func rodar() -> void:
	if DisplayServer.get_name()=="headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		push_error("Renderização exige save isolado e execução gráfica")
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"mapa.json"))
	var vista := SubViewport.new()
	vista.size = Vector2i(dados.tamanho[0],dados.tamanho[1])
	vista.disable_3d = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	var cena := load("res://cenas/fendas/caverna_recortada.tscn").instantiate() as Node2D
	vista.add_child(cena)
	var mapa := cena.get_node("Caverna") as TileMapLayer
	assert(mapa.get_used_cells().size()==int(dados.celulas.size()))
	assert(mapa.tile_set.tile_size==Vector2i(16,16))
	assert(mapa.tile_set.get_patterns_count()==20)
	await aguardar()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	await RenderingServer.frame_post_draw
	var imagem := vista.get_texture().get_image()
	imagem.get_region(Rect2i(0,0,dados.origem[0],dados.origem[1])).save_png(SAIDA+"caverna_godot.png")
	cena.queue_free()
	await aguardar()
	vista.size = Vector2i(1008,768)
	var fundo := ColorRect.new()
	fundo.color = Color(0.035,0.035,0.035)
	fundo.size = Vector2(vista.size)
	vista.add_child(fundo)
	var pecas := TileMapLayer.new()
	pecas.material = CanvasItemMaterial.new()
	pecas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pecas.tile_set = mapa.tile_set if is_instance_valid(mapa) else load(BASE+"caverna.tres")
	pecas.collision_enabled = false
	pecas.navigation_enabled = false
	vista.add_child(pecas)
	var nomes := ["parede_norte","parede_oeste","canto_externo_noroeste","curva_interna_oeste",
		"margem_norte","margem_sul","margem_oeste","margem_leste",
		"escada","entrada","piso","agua"]
	for i in nomes.size():
		var nome: String = nomes[i]
		var padrao: TileMapPattern = load(BASE+"padroes/"+nome+".tres")
		for celula in padrao.get_used_cells():
			assert(padrao.get_cell_alternative_tile(celula)==0)
		var origem := Vector2i((i%4)*16+1,(i/4)*16+3)
		pecas.set_pattern(origem,padrao)
		var legenda := Label.new()
		legenda.text = nome.replace("_"," ")
		legenda.position = Vector2(origem.x*16,(i/4)*256+12)
		legenda.add_theme_font_size_override("font_size",14)
		vista.add_child(legenda)
	await aguardar()
	await RenderingServer.frame_post_draw
	vista.get_texture().get_image().save_png(SAIDA+"pecas_godot.png")
	print("RECORTES OK: cena remontada no Godot e bancada de padrões renderizadas")
	quit()
