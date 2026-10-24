extends SceneTree
## Verifica a renderização real; o teste lógico não compila o shader OpenGL.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, certo: bool) -> void:
	print("OK " if certo else "FALHA ", nome)
	if not certo:
		falhas += 1

func renderizar(vp: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func rodar() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains("AlgoLand testes"):
		push_error("Use renderização gráfica e save isolado.")
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(80, 80)
	sprite.hframes = 6
	sprite.vframes = 4
	vp.add_child(sprite)
	var animacao := preload("res://codigo/inimigos/animacao_fluida_medusa.gd").new()
	var chaves_iguais := true
	var fechamento_igual := true
	var intermediarios_distintos := true
	var sem_halo := true
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/inimigos/medusa/fluidez/campos/manifesto.json"))
	var dados_atuais := true
	for pagina in ["movimento", "garras", "cauda", "bote", "olhar"]:
		var caminho: String = "res://assets/inimigos/medusa/" + pagina + ".png"
		dados_atuais = dados_atuais and FileAccess.get_sha256(caminho) == manifesto.fontes_sha256[pagina]
		sprite.texture = load(caminho)
		for direcao in 4:
			for quadro in 6:
				sprite.material = null
				sprite.frame = direcao * 6 + quadro
				var original := await renderizar(vp)
				animacao.aplicar(sprite, pagina, 0.0)
				var inicial := await renderizar(vp)
				chaves_iguais = chaves_iguais and inicial.get_data() == original.get_data()
				animacao.aplicar(sprite, pagina, 0.35)
				var entre := await renderizar(vp)
				# Há deslocamento real em cada direção/ação, não cópias extras.
				if quadro == 1:
					intermediarios_distintos = intermediarios_distintos and entre.get_data() != original.get_data()
				var pixels := entre.get_data()
				for i in range(3, pixels.size(), 4):
					sem_halo = sem_halo and pixels[i] in [0, 255]
				if quadro == 5:
					animacao.aplicar(sprite, pagina, 1.0)
					var fim := await renderizar(vp)
					sprite.material = null
					sprite.frame = direcao * 6
					var primeiro := await renderizar(vp)
					fechamento_igual = fechamento_igual and fim.get_data() == primeiro.get_data()
	verificar("Campos correspondem aos cinco sprites atuais", dados_atuais)
	verificar("120 poses-chave idênticas à renderização original", chaves_iguais)
	verificar("20 ciclos fecham exatamente na primeira pose", fechamento_igual)
	verificar("Todas as ações e direções possuem transição com movimento", intermediarios_distintos)
	verificar("Intermediários preservam alfa binário, sem halo/crossfade", sem_halo)
	vp.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
