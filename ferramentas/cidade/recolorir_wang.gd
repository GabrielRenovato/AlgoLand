extends SceneTree

## Terreno da vila a partir dos tilesets de transição do PixelLab (modo pro, encaixam sem emenda), recoloridos com a paleta
## do padrão Mana Seed de cada estação. Entradas: arte/fontes/cenario/terreno_wang/<par>.png e .json (folha 4x4 de tiles
## 16x16 e os cantos de cada tile) e os tiles-base de cada estação (arte/fontes/cenario/terreno_mana/<estacao>/frame_N.png),
## que dão as rampas de cor de grama, terra, pedra e água.
## Recolorir: as cores de cada terreno (tiradas dos tiles puros) são ordenadas por brilho e trocadas pela rampa da estação na
## mesma posição; as cores da borda (sombra, espuma) seguem a cor de terreno mais próxima, com o mesmo brilho relativo.
## Saída: assets/cenario/cidade/terreno/<estacao>/<par>.png no formato que cidade.gd usa (4 colunas x 6 linhas: as 16
## combinações de cantos pelo índice NO*8 + NE*4 + SO*2 + SE, depois o terreno de baixo puro e o de cima puro). A água sai em
## 8 quadros (<par>_0..7.png): os pixels de água giram na rampa em ondas diagonais, como o ciclo de cores do Secret of Mana.
## Uso: godot --headless --path . --script ferramentas/cidade/recolorir_wang.gd -- <estacao> [aconchego]
## Com "aconchego", usa os tilesets do estilo aconchegante (arte/fontes/cenario/terreno_aconchego/) e as cores de PALETA_ACONCHEGO,
## tiradas da imagem de referência do estilo (arte/fontes/cenario/estilo_ref/referencia.png)
const FONTES := "res://arte/fontes/cenario/terreno_wang/"
const BASES := "res://arte/fontes/cenario/terreno_mana/"
const SAIDA := "res://assets/cenario/cidade/terreno/"
const T := 16
const PARES := [["grama_terra", "grama", "terra"], ["grama_pedra", "grama", "pedra"], ["terra_pedra", "terra", "pedra"], ["grama_agua", "grama", "agua"]]
const IDX := {"grama": 0, "terra": 1, "pedra": 2, "agua": 3}
const QUADROS_AGUA := 8
## Cores médias fixas onde a média do tile-base confunde os terrenos (folhas no chão do outono, neve na terra do inverno):
## a pedra fica cinza em todas as estações e a terra fica marrom no outono e no inverno
const MEDIAS := {
	"pedra": Color("7d7972"),
	"terra_outono": Color("74502f"),
	"terra_inverno": Color("6a5245"),
	"pedra_inverno": Color("9aa1a6"),
}

## Cor média de cada terreno por estação no estilo aconchegante
const PALETA_ACONCHEGO := {
	"primavera": {"grama": "7fa24a", "terra": "a07850", "pedra": "b49c80", "agua": "4fa3b4"},
	"verao": {"grama": "5e8f3c", "terra": "b08a5c", "pedra": "b49c80", "agua": "3f95a8"},
	"outono": {"grama": "a9953f", "terra": "9a6a42", "pedra": "ad9478", "agua": "4a8e9c"},
	"inverno": {"grama": "e6eef0", "terra": "8a6e5a", "pedra": "a9a8a4", "agua": "b9dde6"},
}
var _fontes := FONTES
var _aconchego := false
var _estacao := ""
var _agrupado := false

func _init() -> void:
	_estacao = OS.get_cmdline_user_args()[0]
	_aconchego = OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "aconchego"
	if _aconchego:
		_fontes = "res://arte/fontes/cenario/terreno_aconchego/"
	_agrupado = _estacao in ["outono", "inverno"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA + _estacao))
	for par in PARES:
		_processar(par)
	quit()

func _carregar(caminho: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	img.convert(Image.FORMAT_RGBA8)
	return img

## Rampa de cores (ordenada do escuro ao claro) do tile-base da estação
func _rampa(terreno: String) -> Array:
	var i: int = IDX[terreno] * 4 if _agrupado else IDX[terreno]
	var img := _carregar(BASES + _estacao + "/frame_%d.png" % i)
	return _cores_ordenadas([img], [Rect2i(0, 0, T, T)])

func _brilho(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

func _cores_ordenadas(imagens: Array, regioes: Array) -> Array:
	var vistas := {}
	for n in imagens.size():
		var img: Image = imagens[n]
		var r: Rect2i = regioes[n]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					vistas[c.to_html(false)] = c
	var lista: Array = vistas.values()
	lista.sort_custom(func(a: Color, b: Color) -> bool: return _brilho(a) < _brilho(b))
	return lista

func _processar(par: Array) -> void:
	var folha := _carregar(_fontes + par[0] + ".png")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_fontes + par[0] + ".json"))
	var tiles: Array = dados["tileset_data"]["tiles"]
	# Índice de cantos e região de cada tile da folha do PixelLab
	var por_indice := {}
	for tile in tiles:
		var cantos: Dictionary = tile["corners"]
		var indice := 0
		var k := 3
		for nome in ["NW", "NE", "SW", "SE"]:
			if cantos[nome] == "upper":
				indice |= 1 << k
			k -= 1
		var caixa: Dictionary = tile["bounding_box"]
		por_indice[indice] = Rect2i(int(caixa["x"]), int(caixa["y"]), T, T)
	# Cores de cada terreno nos tiles puros e o mapa para a rampa da estação, posição a posição
	var origem_baixo := _cores_ordenadas([folha], [por_indice[0]])
	var origem_cima := _cores_ordenadas([folha], [por_indice[15]])
	var mapa := {}
	_mapear(mapa, origem_baixo, _rampa(par[1]), _media_fixa(par[1]), (0.85 if _aconchego else 1.5) if par[1] == "pedra" else 0.8)
	_mapear(mapa, origem_cima, _rampa(par[2]), _media_fixa(par[2]), (0.85 if _aconchego else 1.5) if par[2] == "pedra" else 0.8)
	var conhecidas: Array = origem_baixo + origem_cima
	var eh_agua: bool = par[2] == "agua"
	var rampa_agua: Array = _rampa("agua") if eh_agua else []
	var cores_agua := {}
	if eh_agua:
		for c in origem_cima:
			cores_agua[c.to_html(false)] = true
	var quadros := QUADROS_AGUA if eh_agua else 1
	for q in quadros:
		var saida := Image.create(4 * T, 6 * T, false, Image.FORMAT_RGBA8)
		for indice in 16:
			_copiar(folha, por_indice[indice], saida, Vector2i((indice % 4) * T, (indice / 4) * T), mapa, conhecidas, cores_agua, rampa_agua, q)
		for v in 4:
			_copiar(folha, por_indice[0], saida, Vector2i(v * T, 4 * T), mapa, conhecidas, cores_agua, rampa_agua, q)
			_copiar(folha, por_indice[15], saida, Vector2i(v * T, 5 * T), mapa, conhecidas, cores_agua, rampa_agua, q)
		var nome: String = par[0] + ("_%d" % q if eh_agua else "")
		saida.save_png(ProjectSettings.globalize_path(SAIDA + _estacao + "/" + nome + ".png"))
	print("ok ", _estacao, " ", par[0])

## Tingimento: cada cor do terreno vira a cor média da estação com o mesmo brilho relativo (o desenho do PixelLab fica, só
## as cores mudam para as do Mana Seed). Contraste um pouco menor que o original, como no Mana Seed; na pedra, maior,
## para as juntas das pedras aparecerem
func _media_fixa(terreno: String) -> Variant:
	if _aconchego:
		return Color(PALETA_ACONCHEGO[_estacao][terreno])
	for chave in [terreno + "_" + _estacao, terreno]:
		if MEDIAS.has(chave):
			return MEDIAS[chave]
	return null

func _mapear(mapa: Dictionary, origem: Array, rampa: Array, fixa: Variant, contraste: float) -> void:
	if origem.is_empty() or rampa.is_empty():
		return
	var media := Color(0, 0, 0)
	for c in rampa:
		media += Color(c.r, c.g, c.b, 0)
	media = Color(media.r / rampa.size(), media.g / rampa.size(), media.b / rampa.size())
	if fixa != null:
		media = fixa
	var brilho_origem := 0.0
	for c in origem:
		brilho_origem += _brilho(c)
	brilho_origem /= origem.size()
	for c in origem:
		var fator := pow(_brilho(c) / maxf(brilho_origem, 0.01), contraste)
		mapa[c.to_html(false)] = Color(clampf(media.r * fator, 0, 1), clampf(media.g * fator, 0, 1), clampf(media.b * fator, 0, 1))

func _mais_proxima(c: Color, conhecidas: Array) -> Color:
	var melhor: Color = conhecidas[0]
	var distancia := 99.0
	for k in conhecidas:
		var d := Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length()
		if d < distancia:
			distancia = d
			melhor = k
	return melhor

func _copiar(folha: Image, regiao: Rect2i, saida: Image, destino: Vector2i, mapa: Dictionary, conhecidas: Array, cores_agua: Dictionary, rampa_agua: Array, quadro: int) -> void:
	for y in T:
		for x in T:
			var c := folha.get_pixel(regiao.position.x + x, regiao.position.y + y)
			if c.a < 0.5:
				saida.set_pixel(destino.x + x, destino.y + y, Color(0, 0, 0, 0))
				continue
			var chave := c.to_html(false)
			var nova: Color
			if mapa.has(chave):
				nova = mapa[chave]
			else:
				# Cor de borda: a mesma relação de brilho com a cor de terreno mais próxima
				var perto := _mais_proxima(c, conhecidas)
				var alvo: Color = mapa[perto.to_html(false)]
				var fator := clampf(_brilho(c) / maxf(_brilho(perto), 0.05), 0.4, 1.6)
				nova = Color(clampf(alvo.r * fator, 0, 1), clampf(alvo.g * fator, 0, 1), clampf(alvo.b * fator, 0, 1))
			if cores_agua.has(chave):
				# Água: a posição na rampa sobe e desce em ondas diagonais que andam a cada quadro
				# Período de 16 px nos dois eixos: a onda continua de um tile para o vizinho, qualquer que seja ele.
				# Os tons claros da água acendem e apagam em ondas diagonais que andam a cada quadro
				var onda := sin((x + y) * TAU / T - quadro * TAU / QUADROS_AGUA)
				var luz := 1.0 + 0.16 * onda * clampf((_brilho(c) - 0.35) * 3.0, 0.0, 1.0)
				nova = Color(clampf(nova.r * luz, 0, 1), clampf(nova.g * luz, 0, 1), clampf(nova.b * luz, 0, 1))
			saida.set_pixel(destino.x + x, destino.y + y, nova)
