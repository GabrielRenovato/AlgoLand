extends SceneTree

const FONTES := "res://arte/fontes/personagens/exemplo_alta_qualidade/ataque_espada/"
const SAIDA := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
var encaixes := {}

const REGISTRO := preload("res://ferramentas/personagem/registro_sprite_gerado.gd")

func _initialize() -> void:
	for direcao: String in (["lado"] if "--somente-lado" in OS.get_cmdline_user_args() else ["lado", "baixo", "cima"]):
		var fonte := Image.load_from_file(FONTES + "espada_" + direcao + "_fonte.png")
		if fonte == null or fonte.get_pixel(0, 0).a > 0.1:
			push_error("Fonte da espada ausente ou sem transparência: " + direcao)
			quit(1)
			return
		if not _preparar(direcao, fonte):
			quit(1)
			return
	_preparar_arma()
	var arquivo := FileAccess.open(SAIDA + "espada_encaixes.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(encaixes, "\t"))
	quit()

func _pele(cor: Color) -> bool:
	return cor.a > 0.5 and cor.r > 0.50 and cor.g > 0.25 and cor.b > 0.08 and cor.r > cor.g * 1.15 and cor.g > cor.b * 1.12

func _medir(imagem: Image) -> Dictionary:
	# A espada pode ficar acima do crânio ou abaixo dos pés. Mede pele, não o
	# limite total da textura, para impedir mudança de escala e apoio no golpe.
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var pele := PackedByteArray()
	pele.resize(largura * altura)
	var pe := 0
	for y in altura:
		for x in largura:
			if _pele(imagem.get_pixel(x, y)):
				pele[y * largura + x] = 1
				pe = maxi(pe, y + 1)
	var regioes: Array[Dictionary] = []
	var maior := 0
	var cabeca := Rect2i()
	for inicio in largura * altura:
		if not pele[inicio]:
			continue
		var fila := PackedInt32Array([inicio])
		pele[inicio] = 0
		var leitura := 0
		var minimo := Vector2i(largura, altura)
		var maximo := Vector2i.ZERO
		while leitura < fila.size():
			var atual := fila[leitura]
			leitura += 1
			var ponto := Vector2i(atual % largura, atual / largura)
			minimo = minimo.min(ponto)
			maximo = maximo.max(ponto)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := ponto.x + dx
					var ny := ponto.y + dy
					if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
						continue
					var vizinho := ny * largura + nx
					if pele[vizinho]:
						pele[vizinho] = 0
						fila.append(vizinho)
		regioes.append({"pixels": fila, "limites": Rect2i(minimo, maximo - minimo + Vector2i.ONE)})
		if fila.size() > maior:
			maior = fila.size()
			cabeca = Rect2i(minimo, maximo - minimo + Vector2i.ONE)
	return {"cabeca": cabeca, "pe": pe, "regioes": regioes}

func _preparar(direcao: String, fonte: Image) -> bool:
	var referencia := Image.load_from_file(FONTES + "referencia_" + direcao + ".png")
	var medida_referencia := _medir(referencia)
	var largura_referencia: int = medida_referencia.cabeca.size.x
	var quadros: Array[Image] = []
	var medidas: Array[Dictionary] = []
	var larguras: Array[int] = []
	var colunas := 3
	var ordem := [0, 1, 2, 3, 4, 5]
	for indice: int in ordem:
		var inicio := Vector2i(roundi(float(indice % colunas) * fonte.get_width() / colunas), roundi(float(indice / colunas) * fonte.get_height() / 2))
		var fim := Vector2i(roundi(float(indice % colunas + 1) * fonte.get_width() / colunas), roundi(float(indice / colunas + 1) * fonte.get_height() / 2))
		var quadro := fonte.get_region(Rect2i(inicio, fim - inicio))
		REGISTRO.limpar(quadro)
		var medida := _medir(quadro)
		quadros.append(quadro)
		medidas.append(medida)
		larguras.append(medida.cabeca.size.x)
	larguras.sort()
	var escala := float(largura_referencia) / maxi(1, larguras[3])
	var maos: Array = []
	var atlas := Image.create(2048, 3072, false, Image.FORMAT_RGBA8)
	for i in 6:
		var quadro := quadros[i]
		var escala_quadro := escala
		var correcao := FONTES + "espada_%s_pose_%d.png" % [direcao, i]
		if FileAccess.file_exists(correcao):
			quadro = Image.load_from_file(correcao)
			REGISTRO.limpar(quadro)
			var medida := _medir(quadro)
			escala_quadro = escala * medidas[i].cabeca.size.x / maxi(1, medida.cabeca.size.x)
			medidas[i] = medida
		var cabeca: Rect2i = medidas[i].cabeca
		var centro := cabeca.get_center().x
		var destino_cabeca := 32.0
		if direcao == "lado":
			destino_cabeca = [32.0, 33.0, 34.0, 34.0, 33.0, 32.0][i]
		var posicao := Vector2i(roundi(destino_cabeca * 16 - centro * escala_quadro), roundi(704.0 - (medidas[i].pe + 2) * escala_quadro))
		var limites := quadro.get_used_rect()
		var inicio := posicao + Vector2i(Vector2(limites.position) * escala_quadro)
		var fim := posicao + Vector2i(Vector2(limites.end) * escala_quadro)
		if inicio.x < 0 or inicio.y < 0 or fim.x > 1024 or fim.y > 1024:
			push_error("Espada sairia do quadro: %s pose %d: %s a %s" % [direcao, i, inicio, fim])
			return false
		var mao := _pegar_mao(quadro, medidas[i], direcao)
		var encaixe := Vector2(posicao) + mao * escala_quadro
		maos.append([encaixe.x, encaixe.y])
		quadro.resize(roundi(quadro.get_width() * escala_quadro), roundi(quadro.get_height() * escala_quadro), Image.INTERPOLATE_NEAREST)
		var tela := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		tela.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), posicao)
		atlas.blit_rect(tela, Rect2i(0, 0, 1024, 1024), Vector2i(i % 2, i / 2) * 1024)
	encaixes[direcao] = maos
	atlas.save_png(SAIDA + "espada_" + direcao + ".png")
	print("ESPADA ", direcao, ": 6 poses, escala ", escala, ", cabeça e pés registrados sem usar a ponta da arma como referência.")
	return true

func _pegar_mao(imagem: Image, medida: Dictionary, direcao: String) -> Vector2:
	var cabeca: Rect2i = medida.cabeca
	var escolhido: Dictionary = {}
	var melhor := -INF
	for regiao: Dictionary in medida.regioes:
		var limites: Rect2i = regiao.limites
		if regiao.pixels.size() < cabeca.get_area() * 0.035 or limites.position.y < cabeca.position.y + cabeca.size.y * 0.6:
			continue
		if limites.end.y > medida.pe - (medida.pe - cabeca.position.y) * 0.17:
			continue
		var centro := limites.get_center().x
		var valor := -float(centro) if direcao == "baixo" else float(centro)
		if direcao == "lado":
			valor = float(regiao.pixels.size())
		if valor > melhor:
			melhor = valor
			escolhido = regiao
	assert(not escolhido.is_empty(), "Não foi possível localizar o braço da espada: " + direcao)
	var largura := imagem.get_width()
	var mascara := PackedInt32Array()
	mascara.resize(largura * imagem.get_height())
	mascara.fill(-2)
	for pixel: int in escolhido.pixels:
		mascara[pixel] = -1
	var limites: Rect2i = escolhido.limites
	var fila := PackedInt32Array()
	for pixel: int in escolhido.pixels:
		if pixel / largura < limites.position.y + maxi(2, roundi(limites.size.y * 0.08)):
			mascara[pixel] = 0
			fila.append(pixel)
	var leitura := 0
	var maior_distancia := 0
	while leitura < fila.size():
		var pixel := fila[leitura]
		leitura += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := pixel % largura + dx
				var ny := pixel / largura + dy
				if nx < 0 or ny < 0 or nx >= largura or ny >= imagem.get_height():
					continue
				var vizinho := ny * largura + nx
				if mascara[vizinho] == -1:
					mascara[vizinho] = mascara[pixel] + 1
					maior_distancia = maxi(maior_distancia, mascara[vizinho])
					fila.append(vizinho)
	var soma := Vector2.ZERO
	var quantidade := 0
	for pixel: int in escolhido.pixels:
		if mascara[pixel] >= maior_distancia - cabeca.size.x * 0.25:
			soma += Vector2(pixel % largura, pixel / largura)
			quantidade += 1
	return soma / maxi(quantidade, 1)

func _preparar_arma() -> void:
	var arma := Image.load_from_file(FONTES + "arma_fonte.png")
	REGISTRO.limpar(arma)
	arma = arma.get_region(arma.get_used_rect())
	var altura := roundi(arma.get_height() * 352.0 / arma.get_width())
	arma.resize(352, altura, Image.INTERPOLATE_NEAREST)
	var coluna_guarda := 0
	var maior := 0
	for x in range(0, roundi(arma.get_width() * 0.4)):
		var quantidade := 0
		for y in arma.get_height():
			var cor := arma.get_pixel(x, y)
			if cor.a > 0 and cor.r > 0.45 and cor.g > 0.25 and cor.b < cor.g * 0.65:
				quantidade += 1
		if quantidade > maior:
			maior = quantidade
			coluna_guarda = x
	encaixes["arma_pivo"] = [coluna_guarda - 352 * 0.085, altura / 2.0]
	arma.save_png(SAIDA + "espada_arma.png")
