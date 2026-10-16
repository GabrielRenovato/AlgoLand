extends SceneTree
const SAIDA := "res://arte/previas/personagens/refinado/ferramentas.png"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var jogador: Node = arena.get_node("Jogador")
	jogador.cor_cabelo = Color("995e36")
	jogador.definir_aparencia(0,2)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var fundo := ColorRect.new()
	fundo.color = Color("303039")
	fundo.size = viewport.size
	viewport.add_child(fundo)
	jogador.reparent(viewport)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.camera.enabled = false
	jogador.position = Vector2(64,64)
	jogador.scale = Vector2(2,2)
	jogador._arvore_animacao.active = false
	var acoes := ["enxada","machado","picareta","regar","plantar","colher","forja"]
	var folha := Image.create(acoes.size()*128,512,false,Image.FORMAT_RGBA8)
	for coluna in acoes.size():
		for direcao in 4:
			for filho in jogador.get_node("CompositeSprites").get_children():
				if filho is CanvasItem: filho.visible = false
			if acoes[coluna] == "forja":
				jogador.no_forja.visible = true
				for camada in jogador.no_forja.get_children():
					if camada is Sprite2D:
						camada.visible = true
						camada.frame = direcao*8+1
			else:
				jogador.no_fazenda.tocar(acoes[coluna],[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT][direcao])
				jogador.no_fazenda._indice = 2
				jogador.no_fazenda._aplicar_quadro()
			await process_frame
			await RenderingServer.frame_post_draw
			folha.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,128,128),Vector2i(coluna*128,direcao*128))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA.get_base_dir()))
	folha.save_png(SAIDA)
	viewport.queue_free()
	arena.queue_free()
	current_scene = null
	await process_frame
	quit()
