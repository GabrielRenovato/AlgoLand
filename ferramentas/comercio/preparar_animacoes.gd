extends SceneTree

const Preparador := preload("res://ferramentas/comercio/preparar_cavalo.gd")
const ESTACOES := ["primavera", "verao", "outono", "inverno"]

func _initialize() -> void:
	var cavalo := Image.load_from_file("res://arte/fontes/comercio/cavalo_corrida_poses.png")
	if cavalo == null or cavalo.get_size() != Vector2i(1774, 887):
		push_error("Animacoes exigem a folha de oito poses completas da corrida.")
		quit(1)
		return
	var quadros := _extrair_quadros(cavalo)
	for estacao in 4:
		var folha_cavalo := Image.create(Preparador.TELA.x * 2, Preparador.TELA.y * 4, false, Image.FORMAT_RGBA8)
		for quadro in 8:
			var passo := _passo(Preparador.variante(quadros[quadro], estacao), quadro)
			folha_cavalo.blit_rect(passo, Rect2i(Vector2i.ZERO, Preparador.TELA), Vector2i(quadro % 2, quadro / 2) * Preparador.TELA)
		folha_cavalo.save_png("res://assets/cenario/comercio/cavalo_andando_%s.png" % ESTACOES[estacao])
	print("Animacoes do cavalo: quatro folhas em 2x4 quadros. Carroca preparada por preparar_carroca.gd.")
	quit()

# Cada quadro é uma pose completa gerada, nunca uma montagem de membros girados.
const REGIOES := [Rect2i(8, 95, 486, 320), Rect2i(465, 102, 456, 318), Rect2i(907, 112, 448, 308), Rect2i(1355, 91, 412, 277), Rect2i(8, 530, 433, 280), Rect2i(446, 502, 427, 316), Rect2i(877, 515, 457, 303), Rect2i(1319, 515, 451, 303)]
const ANCORAS := [Vector2i(245, 200), Vector2i(695, 200), Vector2i(1129, 220), Vector2i(1560, 203), Vector2i(230, 620), Vector2i(674, 626), Vector2i(1114, 625), Vector2i(1550, 630)]
const AMPLIACAO := 2.8
const OSCILACAO := [0, 0, 48, -12, -28, 80, 8, 4]

func _extrair_quadros(folha: Image) -> Array[Image]:
	var quadros: Array[Image] = []
	for quadro in 8:
		var regiao: Rect2i = REGIOES[quadro]
		var recorte := folha.get_region(regiao)
		var visitados := PackedByteArray()
		visitados.resize(regiao.size.x * regiao.size.y)
		var semente: Vector2i = ANCORAS[quadro] - regiao.position
		var fila: Array[Vector2i] = [semente]
		visitados[semente.y * regiao.size.x + semente.x] = 1
		var indice := 0
		# Separar os cavalos pela transparência, pois alguns cascos ultrapassam a coluna.
		while indice < fila.size():
			var ponto := fila[indice]
			indice += 1
			for direcao in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var vizinho: Vector2i = ponto + direcao
				if not Rect2i(Vector2i.ZERO, regiao.size).has_point(vizinho):
					continue
				var lugar: int = vizinho.y * regiao.size.x + vizinho.x
				if visitados[lugar] or recorte.get_pixelv(vizinho).a <= 0.10:
					continue
				visitados[lugar] = 1
				fila.append(vizinho)
		var imagem := Image.create(regiao.size.x, regiao.size.y, false, Image.FORMAT_RGBA8)
		for y in regiao.size.y:
			for x in regiao.size.x:
				var pixel := recorte.get_pixel(x, y)
				if pixel.a == 0:
					continue
				var pertence: bool = visitados[y * regiao.size.x + x] != 0
				# Preservar também a franja alfa da própria silhueta, sem pegar o vizinho.
				if not pertence and pixel.a <= 0.10:
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							var proximo := Vector2i(x + dx, y + dy)
							if Rect2i(Vector2i.ZERO, regiao.size).has_point(proximo) and visitados[proximo.y * regiao.size.x + proximo.x]:
								pertence = true
				if pertence:
					imagem.set_pixel(x, y, pixel)
		quadros.append(imagem)
	return quadros

func _passo(origem: Image, quadro: int) -> Image:
	var imagem := Image.create(Preparador.TELA.x, Preparador.TELA.y, false, Image.FORMAT_RGBA8)
	var pose := origem.duplicate() as Image
	# Somente ampliação uniforme para a tela compartilhada, mantendo a pose inteira.
	pose.resize(roundi(pose.get_width() * AMPLIACAO), roundi(pose.get_height() * AMPLIACAO), Image.INTERPOLATE_NEAREST)
	var ancora_local: Vector2 = Vector2(ANCORAS[quadro] - REGIOES[quadro].position) * AMPLIACAO
	var destino := Vector2i((Vector2(1177, 610 + OSCILACAO[quadro]) - ancora_local).round())
	imagem.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), destino)
	return imagem

