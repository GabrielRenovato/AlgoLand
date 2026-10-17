extends SceneTree

## Registra as poses inteiras, sem redesenhar nem girar partes do personagem.
const FONTES := "res://arte/fontes/personagens/exemplo_alta_qualidade/corrida_vertical/"
const SAIDA := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const TELA := Vector2i(1024, 1024)

func _initialize() -> void:
	var direcoes := ["baixo"] if "--somente-baixo" in OS.get_cmdline_user_args() else ["cima", "baixo"]
	for direcao in direcoes:
		if not FileAccess.file_exists(FONTES + "correr_" + direcao + "_fonte.png"):
			push_error("Falta a fonte da corrida: " + direcao)
			quit(1)
			return
	for direcao in direcoes:
		_preparar(direcao)
	quit()

func _preparar(direcao: String) -> void:
	var fonte := Image.load_from_file(FONTES + "correr_" + direcao + "_fonte.png")
	var quadros: Array[Image] = []
	var alturas: Array[int] = []
	# A pose 4 da folha frontal inverte os braços no meio da mesma passada.
	# A passagem neutra (7) liga os dois sentidos do balanço em ambas as metades.
	var ordem := [0, 1, 7, 2, 3, 5, 6, 7, 8] if direcao == "baixo" else [0, 1, 2, 3, 4, 5, 6, 7, 8]
	for i in 9:
		var indice: int = ordem[i]
		var x := roundi(float(indice % 3) * fonte.get_width() / 3.0)
		var y := roundi(float(indice / 3) * fonte.get_height() / 3.0)
		var fim_x := roundi(float(indice % 3 + 1) * fonte.get_width() / 3.0)
		var fim_y := roundi(float(indice / 3 + 1) * fonte.get_height() / 3.0)
		var quadro := fonte.get_region(Rect2i(x, y, fim_x - x, fim_y - y))
		for py in quadro.get_height():
			for px in quadro.get_width():
				var cor := quadro.get_pixel(px, py)
				cor = Color.TRANSPARENT if cor.a < 0.5 else Color(cor.r, cor.g, cor.b, 1.0)
				quadro.set_pixel(px, py, cor)
		_manter_corpo(quadro)
		quadros.append(quadro)
		alturas.append(quadro.get_used_rect().size.y)
	alturas.sort()
	# Escala única por direção. Preserva a compressão natural de cada pose.
	var escala := 34.0 * 16.0 / float(alturas[4])
	var folha := Image.create(2048, 5120, false, Image.FORMAT_RGBA8)
	for i in 9:
		var quadro := quadros[i]
		var limites := quadro.get_used_rect()
		var linha := limites.position.y + roundi(limites.size.y * 0.1)
		var soma := 0.0
		var quantidade := 0
		for x in range(limites.position.x, limites.end.x):
			if quadro.get_pixel(x, linha).a > 0:
				soma += x
				quantidade += 1
		var cabeca_x := soma / maxi(quantidade, 1)
		# De frente/costas, os pés avançam em profundidade na própria imagem.
		# Prender o pixel mais baixo ao chão faria a cabeça saltar quando a perna recolhe.
		# Mantém o pivô físico e registra o crânio, com oscilação curta do ciclo.
		var oscilacao: float = [0.0, 0.75, 0.0, -0.75, 0.0, 0.75, 0.0, -0.35, -0.75][i]
		var topo_cabeca := (10.0 + oscilacao) * 16.0
		var posicao := Vector2i(roundi(512.0 - cabeca_x * escala), roundi(topo_cabeca - limites.position.y * escala))
		quadro.resize(roundi(quadro.get_width() * escala), roundi(quadro.get_height() * escala), Image.INTERPOLATE_NEAREST)
		var tela := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		tela.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), posicao)
		folha.blit_rect(tela, Rect2i(Vector2i.ZERO, TELA), Vector2i(i % 2, i / 2) * TELA)
	folha.save_png(SAIDA + "correr_" + direcao + ".png")
	print("CORRIDA ", direcao, ": 9 poses completas, atlas 2x5, crânio registrado e pivô físico preservado.")

func _manter_corpo(imagem: Image) -> void:
	# Remove apenas resíduos desconectados de quadros vizinhos na folha de origem.
	imagem.convert(Image.FORMAT_RGBA8)
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var dados := imagem.get_data()
	var visitados := PackedByteArray()
	visitados.resize(largura * altura)
	var maior := PackedInt32Array()
	for inicio in largura * altura:
		if visitados[inicio] or dados[inicio * 4 + 3] == 0:
			continue
		var fila := PackedInt32Array([inicio])
		visitados[inicio] = 1
		var leitura := 0
		while leitura < fila.size():
			var atual := fila[leitura]
			leitura += 1
			var x := atual % largura
			var y := atual / largura
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
						continue
					var vizinho := ny * largura + nx
					if not visitados[vizinho] and dados[vizinho * 4 + 3] > 0:
						visitados[vizinho] = 1
						fila.append(vizinho)
		if fila.size() > maior.size():
			maior = fila
	visitados.fill(0)
	for indice in maior:
		visitados[indice] = 1
	for i in largura * altura:
		if not visitados[i] and dados[i * 4 + 3] > 0:
			imagem.set_pixel(i % largura, i / largura, Color.TRANSPARENT)
