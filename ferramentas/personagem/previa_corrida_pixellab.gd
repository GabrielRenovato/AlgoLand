extends SceneTree
## Reproduz os quadros originais do PixelLab em projeto/save isolado, sem trocar o jogador.
const RAIZ := "res://arte/fontes/personagens/base_vila_pixellab/"
const SAIDA := "res://arte/previas/personagens/base_vila_pixellab/quatro_direcoes_v4/"
const NOMES := ["frente", "direita", "costas", "esquerda"]
func _initialize() -> void:
	rodar.call_deferred()
func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var vista := SubViewport.new()
	vista.size = Vector2i(1536, 384)
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var fundo := ColorRect.new()
	fundo.size = Vector2(1536, 384)
	fundo.color = Color("29232a")
	vista.add_child(fundo)
	var atores: Array[Sprite2D] = []
	var texturas := []
	var folha := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	for d in 4:
		var quadros := []
		for f in range(1, 9):
			var pasta: String = "v2" if d == 1 else "corrida_" + NOMES[d]
			if d == 0:
				pasta = "corrida_frente_v2"
			elif d == 2:
				pasta = "corrida_costas_v4"
			elif d == 3:
				pasta = "v2"
			var fonte := Image.load_from_file(RAIZ + pasta + "/%d.png" % f)
			assert(fonte.get_width() <= 64 and fonte.get_height() <= 64)
			var tela := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			# Só completa a margem da célula61x64; nenhuma escala/centralização por pose.
			tela.blit_rect(fonte, Rect2i(Vector2i.ZERO, fonte.get_size()), Vector2i.ZERO)
			if d == 3:
				tela.flip_x()
			folha.blit_rect(tela, Rect2i(0, 0, 64, 64), Vector2i((f - 1) * 64, d * 64))
			quadros.append(ImageTexture.create_from_image(tela))
		texturas.append(quadros)
		var ator := Sprite2D.new()
		ator.centered = false
		ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ator.scale = Vector2(6, 6)
		ator.position = Vector2(d * 384, 0)
		vista.add_child(ator)
		atores.append(ator)
	folha.save_png(RAIZ + "corrida-quatro-direcoes-v4-64.png")
	# Duas voltas com a duração real; a segunda é exportada.
	for ciclo in 2:
		for f in 8:
			for d in 4:
				atores[d].texture = texturas[d][f]
			await create_timer(0.1).timeout
			await RenderingServer.frame_post_draw
			if ciclo == 1:
				var imagem := vista.get_texture().get_image()
				imagem.save_png(SAIDA + "quatro_%d.png" % f)
				for d in 4:
					imagem.get_region(Rect2i(d * 384, 0, 384, 384)).save_png(SAIDA + "%s_%d.png" % [NOMES[d], f])
	print("PIXELLAB_PREVIA_OK: 32 poses, 4direções; reprodução100ms; escala6x, célula/pivô preservados, save isolado.")
	quit()
