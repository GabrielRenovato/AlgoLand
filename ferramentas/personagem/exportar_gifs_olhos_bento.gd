extends SceneTree
## Exporta os mesmos quadros, encaixes e shader usados pelo personagem jogável.
const ACABAMENTO := preload("res://codigo/jogador/olhos_contorno_base_vila.gdshader")
const NOMES := ["frente", "direita", "costas", "esquerda"]

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var destino := "res://arte/previas/personagens/base_vila_npc/olhos_bento/gifs/"
	DirAccess.make_dir_recursive_absolute(destino)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/base_vila_npc/olhos_bento.json"))
	var vista := SubViewport.new()
	vista.size = Vector2i(960, 240)
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var fundo := ColorRect.new()
	fundo.color = Color("29232a")
	fundo.size = Vector2(960, 240)
	vista.add_child(fundo)
	var atores: Array[Sprite2D] = []
	for d in 4:
		var ator := Sprite2D.new()
		ator.hframes = 8
		ator.vframes = 4
		ator.centered = false
		ator.scale = Vector2(3, 3)
		ator.position.x = d * 240
		ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var acabamento := ShaderMaterial.new()
		acabamento.shader = ACABAMENTO
		acabamento.set_shader_parameter("modelo", load("res://assets/personagens/base_vila_npc/parado.png"))
		acabamento.set_shader_parameter("acabamento_modelo", load("res://assets/personagens/base_vila_npc/parado_acabamento.png"))
		ator.material = acabamento
		vista.add_child(ator)
		atores.append(ator)
	for acao in ["corrida", "espada"]:
		for i in 8:
			for d in 4:
				var ator := atores[d]
				ator.texture = load("res://assets/personagens/base_vila_npc/" + acao + ".png")
				ator.material.set_shader_parameter("acabamento", load("res://assets/personagens/base_vila_npc/" + acao + "_acabamento.png"))
				ator.frame = d * 8 + i
				var guia: Array = dados.cabecas[acao][d][i]
				ator.material.set_shader_parameter("cabeca_original", Vector4(guia[0], guia[1], guia[2], guia[3]))
				ator.material.set_shader_parameter("cabeca_destino", Vector2(roundf(float(guia[0]) + float(guia[2]) / 2.0 - 6.5), guia[1]))
				ator.material.set_shader_parameter("direcao", float(d))
			await process_frame
			await RenderingServer.frame_post_draw
			var imagem := vista.get_texture().get_image()
			imagem.save_png(destino + "%s_quatro_%d.png" % [acao, i])
			for d in 4:
				imagem.get_region(Rect2i(d * 240, 0, 240, 240)).save_png(destino + "%s_%s_%d.png" % [acao, NOMES[d], i])
	print("GIFS_BENTO: 64 poses renderizadas com os olhos e contorno atuais do jogo.")
	quit()
