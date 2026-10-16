extends SceneTree

## Monta as folhas de transição do terreno da vila a partir dos tiles-base gerados no PixelLab no padrão Mana Seed
## (arte/fontes/cenario/terreno_mana/<estacao>/frame_N.png: 16 tiles = 4 terrenos x 4 variações, na ordem grama, terra,
## pedra, água). Para cada par de terrenos (inferior, superior) sai uma folha de 4 colunas x 6 linhas de tiles 16x16:
##   linhas 0 a 3: as 16 combinações de cantos, índice = NO*8 + NE*4 + SO*2 + SE (1 = canto do terreno superior)
##   linha 4: variações do terreno inferior puro; linha 5: do superior puro (só as duas primeiras do PixelLab, de brilho parecido)
## A borda entre os dois vem do campo bilinear dos cantos (curvas arredondadas) com um pouco de ruído, e um contorno
## escuro no terreno que "cobre" o outro (a grama sobre a terra, a pedra sobre a grama), como nos tiles do Mana Seed.
## Uso: godot --headless --path . --script ferramentas/cidade/gerar_transicoes.gd -- <estacao>
const RAIZ_FONTES := "res://arte/fontes/cenario/terreno_mana/"
const SAIDA := "res://assets/cenario/cidade/terreno/"
const T := 16
## Ordem dos terrenos no arquivo do PixelLab
const IDX := {"grama": 0, "terra": 1, "pedra": 2, "agua": 3}
## Pares: nome, inferior, superior, contorno no inferior (escurece), contorno no superior, brilho de margem no superior,
## ruído da borda
const PARES := [
	["grama_terra", "grama", "terra", 0.62, 1.0, 1.0, 0.08],
	["grama_pedra", "grama", "pedra", 1.0, 0.55, 1.0, 0.05],
	["terra_pedra", "terra", "pedra", 1.0, 0.55, 1.0, 0.05],
	["grama_agua", "grama", "agua", 0.55, 1.0, 1.28, 0.07],
]

## Quadros da animação da água: a água corre deslocando o tile (que se repete sem emenda) alguns pixels por quadro
const QUADROS_AGUA := 8
var _tiles: Array = []
## O PixelLab devolveu os 16 tiles em duas ordens: intercalados (grama, terra, pedra, água, grama...) na primavera e no verão,
## e agrupados por terreno (4 de grama, 4 de terra...) no outono e no inverno
var _agrupado := false
var _quadro_agua := 0

func _init() -> void:
	var estacao: String = OS.get_cmdline_user_args()[0]
	_agrupado = estacao in ["outono", "inverno"]
	for i in 16:
		var caminho := ProjectSettings.globalize_path(RAIZ_FONTES + estacao + "/frame_%d.png" % i)
		var img := Image.load_from_file(caminho)
		if img == null:
			push_error("Não leu " + caminho)
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		_tiles.append(img)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA + estacao))
	for par in PARES:
		if par[2] == "agua":
			for q in QUADROS_AGUA:
				_quadro_agua = q
				_montar(par).save_png(ProjectSettings.globalize_path(SAIDA + estacao + "/" + par[0] + "_%d.png" % q))
		else:
			_montar(par).save_png(ProjectSettings.globalize_path(SAIDA + estacao + "/" + par[0] + ".png"))
		print("ok ", estacao, " ", par[0])
	quit()

## Variação v (0 a 3) do terreno; a água sai deslocada conforme o quadro da animação
func _tile(nome: String, v: int) -> Image:
	var img: Image = _tiles[IDX[nome] * 4 + v if _agrupado else IDX[nome] + 4 * v]
	if nome == "agua" and _quadro_agua > 0:
		return _deslocar(img, _quadro_agua * 2, _quadro_agua)
	return img

func _deslocar(img: Image, dx: int, dy: int) -> Image:
	var saida := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			saida.set_pixel(x, y, img.get_pixel((x + dx) % T, (y + dy) % T))
	return saida

func _ruido(x: int, y: int, semente: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (semente * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

func _escurecer(c: Color, fator: float) -> Color:
	return Color(minf(c.r * fator, 1.0), minf(c.g * fator, 1.0), minf(c.b * fator, 1.0), c.a)

func _montar(par: Array) -> Image:
	var folha := Image.create(4 * T, 6 * T, false, Image.FORMAT_RGBA8)
	var inferior: String = par[1]
	var superior: String = par[2]
	for combinacao in 16:
		var cantos := [(combinacao >> 3) & 1, (combinacao >> 2) & 1, (combinacao >> 1) & 1, combinacao & 1]
		var tile := _tile_de_cantos(cantos, inferior, superior, par, combinacao)
		folha.blit_rect(tile, Rect2i(0, 0, T, T), Vector2i((combinacao % 4) * T, (combinacao / 4) * T))
	for v in 4:
		folha.blit_rect(_tile(inferior, 0), Rect2i(0, 0, T, T), Vector2i(v * T, 4 * T))
		folha.blit_rect(_tile(superior, 0), Rect2i(0, 0, T, T), Vector2i(v * T, 5 * T))
	return folha

## Campo 0..1 por interpolação bilinear dos quatro cantos (NO, NE, SO, SE) no centro do pixel
func _campo(cantos: Array, x: int, y: int) -> float:
	var u := (x + 0.5) / T
	var v := (y + 0.5) / T
	return (cantos[0] * (1 - u) + cantos[1] * u) * (1 - v) + (cantos[2] * (1 - u) + cantos[3] * u) * v

func _tile_de_cantos(cantos: Array, inferior: String, superior: String, par: Array, semente: int) -> Image:
	var tile := Image.create(T, T, false, Image.FORMAT_RGBA8)
	# Só a primeira variação do PixelLab: as outras têm tom diferente e viravam quadrados escuros no meio da grama
	var base_inf := _tile(inferior, 0)
	var base_sup := _tile(superior, 0)
	var ruido: float = par[6]
	# Pertinência de cada pixel ao superior (com ruído só perto da borda)
	var sup: Array = []
	for y in T:
		var linha: Array = []
		for x in T:
			var f := _campo(cantos, x, y)
			var perto := 1.0 - absf(f - 0.5) * 2.0
			linha.append(f + (_ruido(x, y, semente + 1) - 0.5) * ruido * clampf(perto * 1.6, 0.0, 1.0) >= 0.5)
		sup.append(linha)
	_limpar(sup)
	for y in T:
		for x in T:
			var eh_sup: bool = sup[y][x]
			var cor := base_sup.get_pixel(x, y) if eh_sup else base_inf.get_pixel(x, y)
			var vizinho_outro := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < T and ny >= 0 and ny < T and sup[ny][nx] != eh_sup:
					vizinho_outro = true
			if vizinho_outro:
				cor = _escurecer(cor, float(par[4]) if eh_sup else float(par[3]))
				if eh_sup and float(par[5]) > 1.0:
					# Margem clara só na água, uma linha para dentro
					pass
			tile.set_pixel(x, y, cor)
	# Brilho de margem: uma linha clara do superior ao lado do contorno (água)
	if float(par[5]) > 1.0:
		for y in T:
			for x in T:
				if sup[y][x]:
					var junto := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if nx >= 0 and nx < T and ny >= 0 and ny < T and sup[ny][nx] and not _borda(sup, nx, ny):
							junto = true
					if _borda(sup, x, y):
						tile.set_pixel(x, y, _escurecer(base_sup.get_pixel(x, y), 0.8))
					elif junto:
						tile.set_pixel(x, y, _escurecer(base_sup.get_pixel(x, y), float(par[5])))
	return tile

## Tira pixels isolados da máscara (um pixel cercado do outro terreno em três ou quatro lados) e repete uma vez
func _limpar(sup: Array) -> void:
	for passo in 2:
		for y in T:
			for x in T:
				var iguais := 0
				var total := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and nx < T and ny >= 0 and ny < T:
						total += 1
						if sup[ny][nx] == sup[y][x]:
							iguais += 1
				if total >= 3 and iguais <= 1:
					sup[y][x] = not sup[y][x]

func _borda(sup: Array, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and nx < T and ny >= 0 and ny < T and not sup[ny][nx]:
			return true
	return false
