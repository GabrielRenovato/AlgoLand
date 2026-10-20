extends SceneTree
## Monta as animações aprovadas com proporções da base NPC gerada.
## Nenhuma pose é reordenada: a mesma transformação corporal vale para todo o ciclo.
const NOMES := ["frente", "direita", "costas", "esquerda"]
const CABECAS_CORRIDA := [
	[[25,14,39],[25,17,38],[25,14,39],[25,13,38],[25,14,39],[25,17,39],[25,14,39],[25,13,39]],
	[[25,14,38],[25,19,38],[25,14,38],[25,13,38],[25,14,38],[25,19,38],[25,14,38],[26,13,39]],
	[[25,14,39],[26,14,39],[25,14,38],[25,14,38],[26,13,39],[25,14,38],[25,14,39],[25,14,38]],
	[[26,14,39],[26,19,39],[26,13,39],[25,12,38],[25,14,38],[26,19,39],[26,13,38],[25,13,38]]
]
const CABECAS_ESPADA := [
	[[26,14,39],[26,14,39],[26,13,39],[29,16,42],[29,14,42],[28,14,41],[26,14,39],[26,14,39]],
	[[26,14,39],[26,14,40],[27,12,40],[29,16,42],[31,14,44],[29,13,45],[28,13,41],[26,14,39]],
	[[24,14,40],[24,14,39],[23,14,39],[24,17,40],[20,16,35],[18,15,34],[22,16,38],[23,16,39]],
	[[22,14,36],[22,14,35],[22,13,35],[21,16,34],[19,14,35],[25,14,40],[21,15,34],[22,15,35]]
]
const PALETA := ["302327", "49332b", "674731", "87613f", "a27a51", "926c54", "bc8b60", "dda574", "f2bc86", "ffd29b", "ffdfb0", "747362", "9f9c83", "c8c4a8", "e5dfc3", "fff4d7"]

func tom_proximo(cor: Color) -> Color:
	var escolhido := Color(PALETA[0])
	var distancia := INF
	for hexadecimal in PALETA:
		var candidato := Color(hexadecimal)
		var atual := Vector3(cor.r, cor.g, cor.b).distance_squared_to(Vector3(candidato.r, candidato.g, candidato.b))
		if atual < distancia:
			distancia = atual
			escolhido = candidato
	return escolhido

func limpar_contornos_soltos(imagem: Image) -> void:
	var vistos := PackedByteArray()
	vistos.resize(6400)
	for y in 80:
		for x in 80:
			if vistos[y * 80 + x] or imagem.get_pixel(x, y).a < 0.5:
				continue
			var componente: Array[Vector2i] = [Vector2i(x, y)]
			vistos[y * 80 + x] = 1
			var cursor := 0
			var somente_escuro := true
			while cursor < componente.size():
				var ponto := componente[cursor]
				cursor += 1
				var cor := imagem.get_pixelv(ponto)
				somente_escuro = somente_escuro and maxf(cor.r, maxf(cor.g, cor.b)) < 0.40
				for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var vizinho: Vector2i = ponto + delta
					if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= 80 or vizinho.y >= 80:
						continue
					if not vistos[vizinho.y * 80 + vizinho.x] and imagem.get_pixelv(vizinho).a >= 0.5:
						vistos[vizinho.y * 80 + vizinho.x] = 1
						componente.append(vizinho)
			if componente.size() <= 12 and somente_escuro:
				for ponto in componente:
					imagem.set_pixelv(ponto, Color.TRANSPARENT)

func adaptar(fonte: Image, guia: Array) -> Image:
	var area := Rect2i(int(guia[0]) - 2, int(guia[1]) - 1, int(guia[2]) - int(guia[0]) + 4, 14)
	var corpo := fonte.duplicate()
	var cabeca := Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for y in area.size.y:
		for x in area.size.x:
			var posicao := area.position + Vector2i(x, y)
			var cor := fonte.get_pixelv(posicao)
			# Aço azul/branco permanece no corpo/arma; não recortar a lâmina com o crânio.
			var metal := cor.b > cor.r * 1.08 and cor.b > 0.35
			if not metal:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var vizinho := fonte.get_pixel(clampi(posicao.x + dx, 0, 63), clampi(posicao.y + dy, 0, 63))
						if vizinho.a > 0.5 and vizinho.b > vizinho.r * 1.08 and vizinho.b > 0.35:
							metal = true
			if cor.a >= 0.5 and not metal:
				cabeca.set_pixel(x, y, cor)
				corpo.set_pixelv(posicao, Color.TRANSPARENT)
	# Chão/pivô comuns. Não usar o pé mais baixo de cada quadro.
	corpo.resize(60, 78, Image.INTERPOLATE_NEAREST)
	var saida := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	saida.blit_rect(corpo, Rect2i(0, 2, 60, 76), Vector2i(10, 0))
	cabeca.resize(maxi(1, roundi(area.size.x * 0.65)), 10, Image.INTERPOLATE_NEAREST)
	var centro_x := 10.0 + (area.position.x + area.size.x / 2.0) * 60.0 / 64.0
	var base_y := -2.0 + area.end.y * 78.0 / 64.0
	saida.blend_rect(cabeca, Rect2i(Vector2i.ZERO, cabeca.get_size()), Vector2i(roundi(centro_x - cabeca.get_width() / 2.0), roundi(base_y - cabeca.get_height())))
	for y in 80:
		for x in 80:
			var cor := saida.get_pixel(x, y)
			if cor.a < 0.5:
				saida.set_pixel(x, y, Color.TRANSPARENT)
			elif cor.b <= cor.r * 1.08:
				saida.set_pixel(x, y, tom_proximo(cor))
			else:
				cor.a = 1.0
				saida.set_pixel(x, y, cor)
	limpar_contornos_soltos(saida)
	return saida

func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var destino := raiz.path_join("arte/fontes/personagens/base_vila_npc")
	var previa := raiz.path_join("arte/previas/personagens/base_vila_npc")
	DirAccess.make_dir_recursive_absolute(destino)
	DirAccess.make_dir_recursive_absolute(previa)
	var corrida := Image.load_from_file(raiz.path_join("arte/fontes/personagens/base_vila_estudo/corrida-v1-64.png"))
	var modelo_anterior := Image.load_from_file(raiz.path_join("arte/fontes/personagens/base_vila_estudo/parado-v1-64.png"))
	var modelo := Image.create(320, 80, false, Image.FORMAT_RGBA8)
	for d in 4:
		var quadro := adaptar(modelo_anterior.get_region(Rect2i(d * 64, 0, 64, 64)), [26, 14, 39])
		modelo.blit_rect(quadro, Rect2i(0, 0, 80, 80), Vector2i(d * 80, 0))
	modelo.save_png(destino.path_join("parado-v1-80.png"))
	for acao in ["corrida", "espada"]:
		var folha := Image.create(640, 320, false, Image.FORMAT_RGBA8)
		var contato := Image.create(1920, 960, false, Image.FORMAT_RGBA8)
		var conjuntos: Array[Image] = []
		for i in 8:
			conjuntos.append(Image.create(960, 240, false, Image.FORMAT_RGBA8))
		for d in 4:
			for i in 8:
				var origem: Image
				var guia: Array
				if acao == "corrida":
					origem = corrida.get_region(Rect2i(i * 64, d * 64, 64, 64))
					guia = CABECAS_CORRIDA[d][i]
				else:
					origem = Image.load_from_file(raiz.path_join("arte/previas/personagens/base_vila_estudo/espada_quatro_direcoes/%s_%d.png" % [NOMES[d], i]))
					origem = origem.get_region(Rect2i(32, 58, 192, 192))
					origem.resize(64, 64, Image.INTERPOLATE_NEAREST)
					guia = CABECAS_ESPADA[d][i]
				var quadro := adaptar(origem, guia)
				folha.blit_rect(quadro, Rect2i(0, 0, 80, 80), Vector2i(i * 80, d * 80))
				quadro.resize(240, 240, Image.INTERPOLATE_NEAREST)
				quadro.save_png(previa.path_join("%s_%s_%d.png" % [acao, NOMES[d], i]))
				conjuntos[i].blit_rect(quadro, Rect2i(0, 0, 240, 240), Vector2i(d * 240, 0))
				contato.blit_rect(quadro, Rect2i(0, 0, 240, 240), Vector2i(i * 240, d * 240))
		folha.save_png(destino.path_join("%s-v1-80.png" % acao))
		contato.save_png(previa.path_join("%s_contato.png" % acao))
		for i in 8:
			conjuntos[i].save_png(previa.path_join("%s_conjunto_%d.png" % [acao, i]))
	print("Adaptação NPC: 64 quadros; ordem e duração aprovadas preservadas.")
	quit()
