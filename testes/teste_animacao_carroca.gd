extends SceneTree

var falhas := 0
var verificacoes := 0
func _initialize() -> void:
	_rodar.call_deferred()
func verificar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error("FALHA: " + texto)
func quadros(n := 5) -> void:
	for i in n:
		await process_frame
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes carroca"):
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	var comercio := root.get_node("Comercio")
	comercio.liberado = true
	comercio.apagar()
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var carroca := current_scene.get_node("Carroca")
	var conjunto: Node2D = carroca.visual
	verificar(not conjunto.andando and conjunto.cavalo.hframes == 1, "na fazenda o cavalo esta parado")
	# Regressão visual: a imagem escolhida não pode virar outro desenho na importação.
	var original := Image.load_from_file("res://arte/fontes/comercio/cavalo_estudo_v2.png")
	var textura_original: Image = load("res://assets/cenario/comercio/cavalo_primavera.png").get_image()
	var integrado := textura_original.get_region(Rect2i(462, 160, 1484, 1060))
	verificar(_mesma_arte(original, integrado), "repouso preserva cores e transparencia da segunda imagem")
	var base: Vector2 = carroca.position
	var calendario := root.get_node("Calendario")
	for estacao in 4:
		calendario.dia = estacao * 7 + 1
		calendario.estacao_mudou.emit(estacao)
		current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		for pelagem in 3:
			comercio.definir_pelagem(pelagem)
			conjunto.definir_movimento(true)
			conjunto.set_process(false)
			verificar(conjunto.sprite.texture.get_size() == Vector2(3648, 4864) and conjunto.cavalo.texture.get_size() == Vector2(4224, 5632), "folhas sazonais %d pelagem %d" % [estacao, pelagem])
			verificar(conjunto.sprite.hframes == 2 and conjunto.sprite.vframes == 4 and conjunto.cavalo.hframes == 2 and conjunto.cavalo.vframes == 4, "oito quadros sem exceder limite de textura")
			verificar((conjunto.cavalo.texture.get_size() / Vector2(2, 4) * conjunto.cavalo.scale).is_equal_approx(Vector2(124.8, 83.2)), "cavalo ampliado em trinta por cento")
			var estrutura: Image = conjunto.sprite.texture.get_image().get_region(Rect2i(0, 0, 1824, 816))
			var cavalo_vistos := {}
			var roda_vistos := {}
			for quadro in 8:
				conjunto.definir_quadro(quadro)
				verificar(conjunto.sprite.frame == quadro and conjunto.cavalo.frame == quadro, "sincronismo quadro %d" % quadro)
				var origem_quadro := Vector2i(quadro % 2, quadro / 2) * Vector2i(1824, 1216)
				var atual: Image = conjunto.sprite.texture.get_image().get_region(Rect2i(origem_quadro, Vector2i(1824, 816)))
				verificar(atual.get_data() == estrutura.get_data(), "caixa e chassi conectados em todos os quadros")
				var cavalo: Image = conjunto.cavalo.texture.get_image().get_region(Rect2i(Vector2i(quadro % 2, quadro / 2) * Vector2i(2112, 1408), Vector2i(2112, 1408)))
				var roda: Image = conjunto.sprite.texture.get_image().get_region(Rect2i(origem_quadro + Vector2i(296, 816), Vector2i(245, 245)))
				cavalo_vistos[hash(cavalo.get_data())] = true
				roda_vistos[hash(roda.get_data())] = true
			verificar(cavalo_vistos.size() == 8 and roda_vistos.size() >= 6, "passada e giro mudam de verdade")
			conjunto.definir_movimento(false)
			verificar(conjunto.cavalo.hframes == 1 and conjunto.cavalo.frame == 0, "parar restaura exatamente o sprite de repouso")
		verificar(carroca.position == base, "animacao nao arrasta a colisao da fazenda")
	calendario.dia = 1
	comercio.em_viagem = true
	comercio.eventos.assign(["roda", "monstros"])
	comercio.etapa = 0
	comercio.alterado.emit()
	var jogador := current_scene.get_node("Jogador")
	verificar(conjunto.passageiros.get_child_count() == 1 and conjunto.redeas.visible, "condutor embarcado com redeas")
	var condutor: Node2D = conjunto.passageiros.get_child(0)
	verificar(condutor.corpo.frame == 51 and condutor.cabelo.modulate == jogador.cor_cabelo, "pose sentada conserva cabelo do jogador")
	verificar(not jogador.get_node("CompositeSprites").visible, "jogador nao fica duplicado em pe na fazenda")
	verificar(conjunto.lateral_frente.get_index() > conjunto.passageiros.get_index(), "lateral dianteira cobre pernas e colo")
	await create_timer(0.3).timeout
	verificar(conjunto.andando and conjunto.position.x > 0, "a partida move a carroca pela fazenda")
	verificar(conjunto.quadro > 0, "relogio da animacao avanca em execucao")
	comercio.em_combate = true
	comercio.alterado.emit()
	verificar(not conjunto.andando and conjunto.position == Vector2.ZERO and conjunto.visible, "encontro estaciona o conjunto")
	verificar(jogador.get_node("CompositeSprites").visible and conjunto.passageiros.get_child_count() == 0, "desembarque para combate restaura jogador")
	comercio.em_combate = false
	comercio.etapa = 2
	comercio.alterado.emit()
	verificar(not conjunto.andando, "mercado mantem rodas e cavalo parados")
	comercio.em_viagem = false
	comercio.alterado.emit()
	verificar(conjunto.visible and conjunto.position == Vector2.ZERO, "retorno deixa a carroca no estacionamento")
	verificar(jogador.get_node("CompositeSprites").visible and conjunto.passageiros.get_child_count() == 0, "retorno remove copia sentada e restaura jogador")
	if "--capturar" in OS.get_cmdline_user_args():
		await _capturar()
	print("ANIMACAO CARROCA: %d verificacoes, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)

func _mesma_arte(original: Image, integrado: Image) -> bool:
	original.convert(Image.FORMAT_RGBA8)
	integrado.convert(Image.FORMAT_RGBA8)
	var esperado := original.get_data()
	var obtido := integrado.get_data()
	if esperado.size() != obtido.size():
		return false
	for i in range(0, esperado.size(), 4):
		if esperado[i + 3] != obtido[i + 3]:
			return false
		# O importador dilata RGB em pixels totalmente transparentes para evitar halos.
		if esperado[i + 3] > 0 and (esperado[i] != obtido[i] or esperado[i + 1] != obtido[i + 1] or esperado[i + 2] != obtido[i + 2]):
			return false
	return true

func _capturar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(320, 180)
	var comercio := root.get_node("Comercio")
	comercio.liberado = true
	var calendario := root.get_node("Calendario")
	var camera := Camera2D.new()
	camera.position = Vector2(568, 274)
	current_scene.add_child(camera)
	camera.make_current()
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	var luz := current_scene.get_node("Iluminacao")
	luz.definir_hora(12)
	luz.set_process(false)
	var camada := CanvasLayer.new()
	camada.layer = 30
	current_scene.add_child(camada)
	var roteiro := load("res://codigo/comercio/vista_viagem.gd") as GDScript
	var vista: Control = roteiro.new()
	vista.position = Vector2(40, 40)
	vista.size = Vector2(240, 80)
	camada.add_child(vista)
	vista.set_process(false)
	vista.conjunto.set_process(false)
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-carroca-video")
	for estacao in 4:
		calendario.dia = estacao * 7 + 1
		calendario.estacao_mudou.emit(estacao)
		current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		vista._estacao = estacao
		vista.conjunto.atualizar_estacao(estacao)
		for pelagem in 3:
			comercio.definir_pelagem(pelagem)
			vista.conjunto.atualizar_pelagem()
			for quadro in 8:
				vista._tempo = quadro * 0.1
				vista.conjunto.definir_quadro(quadro)
				vista.queue_redraw()
				await quadros(2)
				await RenderingServer.frame_post_draw
				var tela := root.get_texture().get_image()
				if quadro == 0:
					var frente: Image = vista.conjunto.sprite.texture.get_image()
					var oclusao_correta := true
					for y in range(34, 41):
						for x in range(59, 72):
							# Centro do pixel de tela, convertido para a textura em alta resolução.
							var esperado := frente.get_pixel(x * 19 + 9, y * 19 + 9)
							if esperado.a < 0.99:
								continue
							var ponto: Vector2 = (vista.position + vista.conjunto.position + vista.conjunto.sprite.offset * vista.conjunto.sprite.scale + Vector2(x, y)) * 3 + Vector2.ONE
							var obtido := tela.get_pixelv(Vector2i(ponto))
							if absf(esperado.r - obtido.r) + absf(esperado.g - obtido.g) + absf(esperado.b - obtido.b) > 0.025:
								oclusao_correta = false
					verificar(oclusao_correta, "renderizacao preserva lateral diante do jogador, estacao %d pelagem %d" % [estacao, pelagem])
				var imagem := tela.get_region(Rect2i(120, 120, 720, 240))
				imagem.save_png("/tmp/algoland-carroca-video/e%d_p%d_q%d.png" % [estacao, pelagem, quadro])
	# Cinco ciclos de passada e quatro ciclos do piso: o vídeo fecha sem pulo no chão.
	calendario.dia = 1
	vista._estacao = 0
	vista.conjunto.atualizar_estacao(0)
	comercio.definir_pelagem(1)
	vista.conjunto.atualizar_pelagem()
	for quadro in 40:
		vista._tempo = quadro * 0.1
		vista.conjunto.definir_quadro(quadro)
		vista.queue_redraw()
		await quadros(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(120, 120, 720, 240)).save_png("/tmp/algoland-carroca-video/quadro_%02d.png" % quadro)
