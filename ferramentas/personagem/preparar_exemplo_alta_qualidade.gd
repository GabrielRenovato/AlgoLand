extends SceneTree

const FONTES := "res://arte/fontes/personagens/exemplo_alta_qualidade/"
const DESTINO := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const TELA := Vector2i(1024, 1024)

func _initialize() -> void:
	var andar := Image.load_from_file(FONTES + "revisao_movimento/andar_8_poses.png")
	var correr := Image.load_from_file(FONTES + "revisao_movimento/correr_8_poses.png")
	if andar == null or correr == null:
		push_error("Faltam as fontes do exemplo de personagem.")
		quit(1)
		return
	if not "--somente-corrida" in OS.get_cmdline_user_args():
		_preparar_ciclo(andar, "andar", false)
	_preparar_ciclo(correr, "correr", true)
	print("EXEMPLO: seis poses de caminhada e nove de corrida, incluindo o braço abaixando.")
	quit()

func _preparar_ciclo(fonte: Image, acao: String, corrida: bool) -> void:
	var quadros: Array[Image] = []
	var alturas: Array[int] = []
	var larguras_cabeca: Array[int] = []
	var ordem := [0, 1, 2, 3, 4, 5, 6, 7] if corrida else [0, 1, 2, 4, 5, 6]
	for indice: int in ordem:
		var x := roundi(float(indice % 4) * fonte.get_width() / 4.0)
		var y := roundi(float(indice / 4) * fonte.get_height() / 2.0)
		var fim_x := roundi(float(indice % 4 + 1) * fonte.get_width() / 4.0)
		var fim_y := roundi(float(indice / 4 + 1) * fonte.get_height() / 2.0)
		var quadro := fonte.get_region(Rect2i(x, y, fim_x - x, fim_y - y))
		_limpar_alfa(quadro)
		quadros.append(quadro)
		alturas.append(quadro.get_used_rect().size.y)
		larguras_cabeca.append(_largura_cabeca(quadro))
	alturas.sort()
	larguras_cabeca.sort()
	# Uma escala comum ao ciclo inteiro; não estica individualmente as poses de compressão.
	var fator := 34.0 * 16.0 / float(alturas[alturas.size() / 2])
	var largura_cabeca := larguras_cabeca[larguras_cabeca.size() / 2] * fator
	var registrados: Array[Image] = []
	for pos in ordem.size():
		var indice: int = ordem[pos]
		var chao := 42.0 if corrida and indice in [3, 7] else 44.0
		var quadro := quadros[pos]
		var escala := fator
		if not corrida:
			var pose := FONTES + "revisao_movimento/andar_pose_%d.png" % indice
			if FileAccess.file_exists(pose):
				quadro = Image.load_from_file(pose)
				_limpar_alfa(quadro)
			# As poses individuais vêm em telas maiores. A cabeça é a medida rígida,
			# preservando a compressão das pernas em vez de igualar a altura do corpo.
			escala = largura_cabeca / float(_largura_cabeca(quadro))
		# Correções anatômicas pontuais: o segundo apoio pertence à outra perna.
		var correcao := FONTES + "alternancia_pernas/%s_pose_%d.png" % [acao, indice]
		if FileAccess.file_exists(correcao):
			var largura_original := _largura_cabeca(quadro) * escala
			quadro = Image.load_from_file(correcao)
			_limpar_alfa(quadro)
			escala = largura_original / float(_largura_cabeca(quadro))
		registrados.append(_registrar(quadro, escala, 37.0 if corrida else 34.0, chao))
		if corrida and indice == 6:
			var ponte := Image.load_from_file(FONTES + "revisao_movimento/correr_braco_baixo.png")
			_limpar_alfa(ponte)
			var escala_ponte := _largura_cabeca(quadro) * fator / float(_largura_cabeca(ponte))
			registrados.append(_registrar(ponte, escala_ponte, 37.0, chao))
	_aplicar_balanco_bracos(registrados, acao, corrida)
	_salvar(registrados, acao)

func _aplicar_balanco_bracos(quadros: Array[Image], acao: String, corrida: bool) -> void:
	# Índices do atlas final, incluindo a transição extra da corrida.
	# Registra pela cabeça e pelo apoio do quadro anterior à edição; não iguala
	# a altura das poses nem altera a duração das passadas.
	for indice in quadros.size():
		var caminho := FONTES + "balanco_bracos/%s_pose_%d.png" % [acao, indice]
		if not FileAccess.file_exists(caminho):
			continue
		var original := quadros[indice]
		var pose := Image.load_from_file(caminho)
		_limpar_alfa(pose)
		var escala := float(_largura_cabeca(original)) / _largura_cabeca(pose)
		var chao := original.get_used_rect().end.y / 16.0
		quadros[indice] = _registrar(pose, escala, 37.0 if corrida else 34.0, chao)

func _largura_cabeca(imagem: Image) -> int:
	var limites := imagem.get_used_rect()
	var y := limites.position.y + roundi(limites.size.y * 0.10)
	var esquerda := imagem.get_width()
	var direita := 0
	for x in range(limites.position.x, limites.end.x):
		if imagem.get_pixel(x, y).a > 0:
			esquerda = mini(esquerda, x)
			direita = maxi(direita, x)
	return maxi(1, direita - esquerda + 1)

func _limpar_alfa(recorte: Image) -> void:
	for y in recorte.get_height():
		for x in recorte.get_width():
			var pixel := recorte.get_pixel(x, y)
			if pixel.a < 0.5:
				recorte.set_pixel(x, y, Color.TRANSPARENT)
			else:
				pixel.a = 1.0
				recorte.set_pixel(x, y, pixel)

func _registrar(origem: Image, fator: float, centro_cabeca: float, chao: float) -> Image:
	var recorte := origem.duplicate() as Image
	var limites := recorte.get_used_rect()
	var linha := limites.position.y + roundi(limites.size.y * 0.10)
	var soma := 0.0
	var quantidade := 0
	for x in range(limites.position.x, limites.end.x):
		if recorte.get_pixel(x, linha).a > 0:
			soma += x
			quantidade += 1
	var cabeca_x := soma / maxi(quantidade, 1)
	var posicao := Vector2i(roundi(centro_cabeca * 16 - cabeca_x * fator), roundi(chao * 16 - limites.end.y * fator))
	recorte.resize(roundi(recorte.get_width() * fator), roundi(recorte.get_height() * fator), Image.INTERPOLATE_NEAREST)
	var tela := Image.create(TELA.x, TELA.y, false, Image.FORMAT_RGBA8)
	tela.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), posicao)
	return tela

func _salvar(quadros: Array[Image], acao: String) -> void:
	var folha := Image.create(TELA.x * 2, TELA.y * ceili(quadros.size() / 2.0), false, Image.FORMAT_RGBA8)
	for indice in quadros.size():
		folha.blit_rect(quadros[indice], Rect2i(Vector2i.ZERO, TELA), Vector2i(indice % 2, indice / 2) * TELA)
	folha.save_png(DESTINO + acao + ".png")
