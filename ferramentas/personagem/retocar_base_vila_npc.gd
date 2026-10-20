extends SceneTree
## Aplica o acabamento do modelo gerado às máscaras dos quadros aprovados.
## Não altera alfa, geometria, pivôs, ordem, durações ou pixels do aço/rastro.
const NOMES := ["frente", "direita", "costas", "esquerda"]
const CORES_ANTES := ["302327", "49332b", "674731", "87613f", "a27a51", "926c54", "bc8b60", "dda574", "f2bc86", "ffd29b", "ffdfb0", "747362", "9f9c83", "c8c4a8", "e5dfc3", "fff4d7"]
const PELE := ["805847", "c2845a", "dd9f6e", "f1bc89", "ffd29c", "ffdfb3"]
const CAMISA := ["887f6f", "beb2a1", "d8cdbb", "e5dbcb", "fbfafa"]
const CALCA := ["2e4445", "415f5e", "517774", "658985"]
const BOTAS := ["433027", "624530", "896043", "ac7b4d"]
var _modelo: Image
var _indices := {}

func indice(cor: Color) -> int:
	return int(_indices.get(cor.to_html(false), -1)) if cor.a >= 0.5 else -1

func componentes(fonte: Image, aceitos: Array) -> Array:
	var vistos := PackedByteArray()
	vistos.resize(6400)
	var resultado := []
	for y in 80:
		for x in 80:
			if vistos[y * 80 + x] or not indice(fonte.get_pixel(x, y)) in aceitos:
				continue
			var pontos: Array[Vector2i] = [Vector2i(x, y)]
			vistos[y * 80 + x] = 1
			var cursor := 0
			while cursor < pontos.size():
				var ponto := pontos[cursor]
				cursor += 1
				for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var vizinho: Vector2i = ponto + delta
					if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= 80 or vizinho.y >= 80:
						continue
					if not vistos[vizinho.y * 80 + vizinho.x] and indice(fonte.get_pixelv(vizinho)) in aceitos:
						vistos[vizinho.y * 80 + vizinho.x] = 1
						pontos.append(vizinho)
			resultado.append(pontos)
	return resultado

func limites(pontos: Array) -> Rect2i:
	var minimo: Vector2i = pontos[0]
	var maximo: Vector2i = pontos[0]
	for ponto in pontos:
		minimo = Vector2i(mini(minimo.x, ponto.x), mini(minimo.y, ponto.y))
		maximo = Vector2i(maxi(maximo.x, ponto.x), maxi(maximo.y, ponto.y))
	return Rect2i(minimo, maximo - minimo + Vector2i.ONE)

func mascara_metal(fonte: Image) -> PackedByteArray:
	var mascara := PackedByteArray()
	mascara.resize(6400)
	for y in 80:
		for x in 80:
			var cor := fonte.get_pixel(x, y)
			if cor.a < 0.5 or indice(cor) >= 0:
				continue
			# O preparador aprovado conserva o aço e efeitos fora da paleta corporal.
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var px := clampi(x + dx, 0, 79)
					var py := clampi(y + dy, 0, 79)
					mascara[py * 80 + px] = 1
	return mascara

func area_cabeca(guia: Array) -> Rect2i:
	var largura := roundi((int(guia[2]) - int(guia[0]) + 4) * 0.65)
	var eixo := 10.0 + ((int(guia[0]) - 2) + (int(guia[2]) - int(guia[0]) + 4) / 2.0) * 60.0 / 64.0
	var base := -2.0 + (int(guia[1]) + 13) * 78.0 / 64.0
	return Rect2i(roundi(eixo - largura / 2.0), roundi(base - 10), largura, 10)

func pintar(fonte: Image, direcao: int, cabeca: Rect2i, compressao: bool) -> Image:
	var saida := fonte.duplicate()
	var metal := mascara_metal(fonte)
	var camisas := componentes(fonte, [11, 12, 13, 14, 15])
	var torso: Array = []
	for parte in camisas:
		if parte.size() > torso.size():
			torso = parte
	assert(not torso.is_empty())
	var area_torso := limites(torso)
	var barra := area_torso.end.y - 1
	var tecido := {}
	for ponto in torso:
		tecido[ponto] = true
	var botas := {}
	for parte in componentes(fonte, [1, 2, 3, 4]):
		var area := limites(parte)
		if area.position.y >= barra + 2 and area.size.y <= 7:
			for ponto in parte:
				botas[ponto] = true
	var pernas := {}
	var centro := cabeca.position + Vector2i(cabeca.size.x / 2, 5)
	for parte in componentes(fonte, [5, 6, 7, 8, 9, 10]):
		var area := limites(parte)
		if area.position.y >= barra + 1 and area.end.y >= barra + 4:
			for ponto in parte:
				pernas[ponto] = true
		elif compressao and direcao in [1, 3] and area.end.y >= barra + 5:
			# Na compressão, mão e joelho se tocam na máscara de pele.
			# Preservar a mão diante do joelho e vestir só a canela/parte avançada.
			for ponto in parte:
				var avancado: bool = ponto.x >= centro.x if direcao == 1 else ponto.x <= centro.x
				if ponto.y >= barra + 4 or (ponto.y >= barra + 2 and avancado):
					pernas[ponto] = true
	var origem_doador := Vector2i((direcao % 2) * 64, (direcao / 2) * 64)
	for y in 80:
		for x in 80:
			var posicao := Vector2i(x, y)
			var original := fonte.get_pixel(x, y)
			var tom := indice(original)
			if tom < 0 or metal[y * 80 + x]:
				continue
			var cor := original
			if tom >= 5 and tom <= 10:
				cor = Color(PELE[tom - 5])
			if tecido.has(posicao):
				cor = Color(CAMISA[tom - 11])
				if y == barra and tom >= 12:
					cor = Color(CAMISA[1])
			elif y > barra and tom >= 1 and tom <= 4:
				cor = Color(BOTAS[tom - 1]) if botas.has(posicao) else Color(CALCA[tom - 1])
			elif pernas.has(posicao):
				cor = Color(CALCA[clampi(tom - 6, 0, 3)])
			# O modelo fornece pixels do rosto, sem redimensionar o crânio de nenhuma pose.
			if cabeca.has_point(posicao):
				var ponto_doador := origem_doador + Vector2i(32, 18) + posicao - centro
				var doador := _modelo.get_pixelv(ponto_doador)
				if doador.a >= 0.5:
					cor = doador
			cor.a = original.a
			saida.set_pixelv(posicao, cor)
	# Gola e pequenos pontos de costura seguem o centro do tronco em cada pose.
	if direcao == 0:
		var eixo := roundi(area_torso.get_center().x)
		for ponto in [Vector2i(eixo - 1, area_torso.position.y + 1), Vector2i(eixo + 1, area_torso.position.y + 1), Vector2i(eixo, area_torso.position.y + 3)]:
			if tecido.has(ponto) and not metal[ponto.y * 80 + ponto.x]:
				var cor := Color(CAMISA[1])
				cor.a = fonte.get_pixelv(ponto).a
				saida.set_pixelv(ponto, cor)
	# Olhos de um pixel: o lado de costas permanece sem rosto.
	var olhos := [-2, 1] if direcao == 0 else ([2] if direcao == 1 else ([-2] if direcao == 3 else []))
	for delta in olhos:
		var ponto := centro + Vector2i(delta, 1)
		if fonte.get_pixelv(ponto).a >= 0.5 and not metal[ponto.y * 80 + ponto.x]:
			saida.set_pixelv(ponto, Color("432f2c"))
	# Contrato: nenhum pixel do contorno/transparência ou arma pode mudar de posição.
	for y in 80:
		for x in 80:
			assert(saida.get_pixel(x, y).a == fonte.get_pixel(x, y).a)
			if metal[y * 80 + x]:
				assert(saida.get_pixel(x, y) == fonte.get_pixel(x, y))
	return saida

func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var fontes := raiz.path_join("arte/fontes/personagens/base_vila_npc")
	var destino := fontes.path_join("v2_acabamento")
	var previa := raiz.path_join("arte/previas/personagens/base_vila_npc/v2_acabamento")
	DirAccess.make_dir_recursive_absolute(previa)
	_modelo = Image.load_from_file(destino.path_join("modelo-nativo.png"))
	for i in CORES_ANTES.size():
		_indices[CORES_ANTES[i]] = i
	var referencia = load(raiz.path_join("ferramentas/personagem/adaptar_base_vila_npc.gd"))
	for acao in ["parado", "corrida", "espada"]:
		var entrada := Image.load_from_file(fontes.path_join("%s-v1-80.png" % acao))
		var saida := entrada.duplicate()
		var grade := Vector2i(4, 1) if acao == "parado" else Vector2i(8, 4)
		var contato := Image.create(grade.x * 240, grade.y * 240, false, Image.FORMAT_RGBA8)
		for d in 4:
			for i in (1 if acao == "parado" else 8):
				var origem := Vector2i(d * 80, 0) if acao == "parado" else Vector2i(i * 80, d * 80)
				var guia: Array = [26, 14, 39] if acao == "parado" else (referencia.CABECAS_CORRIDA[d][i] if acao == "corrida" else referencia.CABECAS_ESPADA[d][i])
				var celula := pintar(entrada.get_region(Rect2i(origem, Vector2i(80, 80))), d, area_cabeca(guia), acao == "corrida" and i % 4 == 1)
				saida.blit_rect(celula, Rect2i(0, 0, 80, 80), origem)
				celula.resize(240, 240, Image.INTERPOLATE_NEAREST)
				celula.save_png(previa.path_join("%s_%s_%d.png" % [acao, NOMES[d], i]))
				contato.blit_rect(celula, Rect2i(0, 0, 240, 240), origem * 3)
		saida.save_png(destino.path_join("%s-v2-80.png" % acao))
		contato.save_png(previa.path_join("%s_contato.png" % acao))
	print("ACABAMENTO_NPC: 68 quadros; máscaras alfa, aço e efeitos idênticos aos aprovados.")
	quit()
