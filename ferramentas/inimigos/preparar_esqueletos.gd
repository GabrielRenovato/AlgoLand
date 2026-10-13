extends SceneTree

# Prepara as folhas geradas para o grid de 64px usado no jogo, sem interpolação de pixels.
# Rodar: godot --headless --path . --script res://ferramentas/inimigos/preparar_esqueletos.gd
const TIPOS := ["guerreiro", "arqueiro", "mago"]
const CELULA := 64
const TAMANHO_DESENHO := 40
const PALETA_BASE := ["1c1821", "342b32", "51423e", "756052", "9c8265", "c0a57c", "ddc69b", "f4e6bd", "493322", "6c482b", "946136", "bc884b", "dfb86b", "666974", "abb0b8"]
const PALETAS := {
	"guerreiro": ["371c29", "592334", "7e2d41", "a73d50", "ce6370", "e39391"],
	"arqueiro": ["1c2c22", "2e422b", "465934", "64733f", "89944f", "b1b96c"],
	"mago": ["172338", "233754", "334e75", "4a6890", "728aa8", "a6b8c7"],
}

func _initialize() -> void:
	for tipo in TIPOS:
		var fonte := Image.load_from_file("res://inimigos/esqueletos/fontes/%s_v1.png" % tipo)
		if fonte == null or fonte.is_empty():
			push_error("Folha não encontrada: " + tipo)
			quit(1)
			return
		var caminhada := Image.load_from_file("res://inimigos/esqueletos/fontes/%s_caminhada_v2.png" % tipo)
		if caminhada == null or caminhada.is_empty():
			push_error("Caminhada revisada não encontrada: " + tipo)
			quit(1)
			return
		var paleta: Array[Color] = []
		for cor in PALETA_BASE + PALETAS[tipo] + ["472860", "9754b8", "e6baf0"]:
			paleta.append(Color.html(cor))
		var regioes := _regioes_caminhada(caminhada)
		var folha := Image.create(CELULA * 6, CELULA * 7, false, Image.FORMAT_RGBA8)
		folha.fill(Color.TRANSPARENT)
		for linha in 7:
			for coluna in 6:
				var imagem := caminhada if linha < 3 else fonte
				var colunas := 6 if linha < 3 else 4
				var linhas := 3 if linha < 3 else 7
				var c := coluna if linha < 3 else mini(coluna, 3)
				var inicio := Vector2i(roundi(c * imagem.get_width() / float(colunas)), roundi(linha * imagem.get_height() / float(linhas)))
				var fim := Vector2i(roundi((c + 1) * imagem.get_width() / float(colunas)), roundi((linha + 1) * imagem.get_height() / float(linhas)))
				var quadro := imagem.get_region(regioes[linha * 6 + coluna] if linha < 3 else Rect2i(inicio, fim - inicio))
				var fator := TAMANHO_DESENHO / float(maxi(quadro.get_width(), quadro.get_height()))
				quadro.resize(maxi(roundi(quadro.get_width() * fator), 1), maxi(roundi(quadro.get_height() * fator), 1), Image.INTERPOLATE_NEAREST)
				_quantizar(quadro, paleta)
				_limpar_residuos(quadro, linha == 6)
				var posicao := Vector2i((CELULA - quadro.get_width()) / 2, (CELULA - quadro.get_height()) / 2)
				if linha < 3:
					quadro = quadro.get_region(quadro.get_used_rect())
					quadro.resize(maxi(roundi(quadro.get_width() * 32.0 / quadro.get_height()), 1), 32, Image.INTERPOLATE_NEAREST)
					# Apoio fixo dos pés e centro do crânio: evita saltos laterais do corpo entre os passos.
					posicao = Vector2i(32 - _centro_cranio(quadro), 16)
				folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i(coluna * CELULA, linha * CELULA) + posicao)
		var erro := folha.save_png("res://inimigos/esqueletos/%s.png" % tipo)
		if erro != OK:
			push_error("Não foi possível preparar " + tipo)
			quit(1)
			return
		print("Folha preparada: ", tipo)
	quit()

## As fontes geradas podem ter margens desiguais; separa pelas faixas transparentes reais.
func _regioes_caminhada(imagem: Image) -> Array[Rect2i]:
	var regioes: Array[Rect2i] = []
	var linhas := _faixas(imagem, false, 3)
	for faixa in linhas:
		var tira := imagem.get_region(Rect2i(0, faixa.x, imagem.get_width(), faixa.y - faixa.x))
		for coluna in _faixas(tira, true, 6):
			regioes.append(Rect2i(coluna.x, faixa.x, coluna.y - coluna.x, faixa.y - faixa.x))
	return regioes

func _faixas(imagem: Image, horizontal: bool, quantidade: int) -> Array[Vector2i]:
	var faixas: Array[Vector2i] = []
	var tamanho := imagem.get_width() if horizontal else imagem.get_height()
	var transversal := imagem.get_height() if horizontal else imagem.get_width()
	var inicio := -1
	for i in tamanho:
		var pixels := 0
		for j in transversal:
			var cor := imagem.get_pixel(i, j) if horizontal else imagem.get_pixel(j, i)
			if cor.a >= 0.5:
				pixels += 1
		var ocupado := pixels >= maxi(transversal / 120, 3)
		if ocupado and inicio < 0:
			inicio = i
		elif not ocupado and inicio >= 0:
			faixas.append(Vector2i(maxi(inicio - 2, 0), mini(i + 2, tamanho)))
			inicio = -1
	if inicio >= 0:
		faixas.append(Vector2i(maxi(inicio - 2, 0), tamanho))
	while faixas.size() > quantidade:
		var menor := 0
		for i in range(1, faixas.size() - 1):
			if faixas[i + 1].x - faixas[i].y < faixas[menor + 1].x - faixas[menor].y:
				menor = i
		faixas[menor].y = faixas[menor + 1].y
		faixas.remove_at(menor + 1)
	if faixas.size() != quantidade:
		push_error("Não foi possível separar %d quadros da fonte" % quantidade)
		quit(1)
	return faixas

func _quantizar(quadro: Image, paleta: Array[Color]) -> void:
	for y in quadro.get_height():
		for x in quadro.get_width():
			var pixel := quadro.get_pixel(x, y)
			if pixel.a < 0.5:
				quadro.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var melhor := paleta[0]
			var distancia := INF
			for cor in paleta:
				var delta := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
				if delta < distancia:
					distancia = delta
					melhor = cor
			quadro.set_pixel(x, y, melhor)

func _centro_cranio(quadro: Image) -> int:
	var soma := 0.0
	var n := 0
	for y in mini(11, quadro.get_height()):
		for x in quadro.get_width():
			var cor := quadro.get_pixel(x, y)
			if cor.a == 1.0 and cor.r > 0.6 and cor.g > 0.5 and cor.g > cor.b * 1.05:
				soma += x
				n += 1
	return roundi(soma / n) if n > 0 else quadro.get_width() / 2

## Descarta pequenos fragmentos da célula vizinha que aparecem nas bordas da folha gerada.
## Equipamentos e ossos próximos do corpo são preservados, inclusive na queda.
func _limpar_residuos(quadro: Image, preservar_partes_da_queda: bool) -> void:
	var visitados := {}
	var partes: Array[Array] = []
	var caixas: Array[Rect2i] = []
	var maior := 0
	for y in quadro.get_height():
		for x in quadro.get_width():
			var inicio := Vector2i(x, y)
			if visitados.has(inicio) or quadro.get_pixelv(inicio).a < 0.05:
				continue
			var parte: Array[Vector2i] = [inicio]
			visitados[inicio] = true
			var caixa := Rect2i(inicio, Vector2i.ONE)
			var indice := 0
			while indice < parte.size():
				var ponto := parte[indice]
				indice += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var vizinho := ponto + Vector2i(dx, dy)
						if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= quadro.get_width() or vizinho.y >= quadro.get_height():
							continue
						if visitados.has(vizinho) or quadro.get_pixelv(vizinho).a < 0.05:
							continue
						visitados[vizinho] = true
						parte.append(vizinho)
						caixa = caixa.expand(vizinho)
			partes.append(parte)
			caixas.append(caixa)
			if parte.size() > partes[maior].size():
				maior = partes.size() - 1
	if partes.is_empty():
		return
	var corpo := caixas[maior].grow(2)
	for i in partes.size():
		if i == maior or (preservar_partes_da_queda and partes[i].size() >= 2 and corpo.intersects(caixas[i])):
			continue
		for ponto in partes[i]:
			quadro.set_pixelv(ponto, Color.TRANSPARENT)
