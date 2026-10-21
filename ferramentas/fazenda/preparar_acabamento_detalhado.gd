extends SceneTree
## Adapta fontes pintadas à geometria existente; nenhum tile ou obstáculo muda.
const FONTES := "res://arte/fontes/fazenda/acabamento_detalhado/"
const SAIDA := "res://assets/cenario/fazenda/acabamento_detalhado/"
const ESTACOES := ["primavera", "verao", "outono", "inverno"]

func _initialize() -> void:
	var fonte := Image.load_from_file("res://arte/fontes/cidade/enfeites_detalhados/cerca.png")
	var poste := fonte.get_region(Rect2i(66, 210, 210, 555))
	poste.resize(32, 92, Image.INTERPOLATE_LANCZOS)
	var tabua := fonte.get_region(Rect2i(280, 350, 395, 125))
	var horizontal := Image.create(64, 92, false, Image.FORMAT_RGBA8)
	var travessa: Image = tabua.duplicate()
	travessa.resize(40, 20, Image.INTERPOLATE_LANCZOS)
	for y in [24, 59]:
		horizontal.blend_rect(travessa, Rect2i(Vector2i.ZERO, travessa.get_size()), Vector2i(24, y))
	horizontal.blend_rect(poste, Rect2i(Vector2i.ZERO, poste.get_size()), Vector2i.ZERO)
	var vertical := Image.create(32, 188, false, Image.FORMAT_RGBA8)
	var lateral: Image = tabua.duplicate()
	lateral.rotate_90(CLOCKWISE)
	lateral.resize(16, 112, Image.INTERPOLATE_LANCZOS)
	vertical.blend_rect(lateral, Rect2i(Vector2i.ZERO, lateral.get_size()), Vector2i(8, 32))
	vertical.blend_rect(poste, Rect2i(Vector2i.ZERO, poste.get_size()), Vector2i(0, 96))
	var mato := Image.load_from_file(FONTES + "mato.png")
	mato = mato.get_region(_area(mato))
	mato.resize(44, 40, Image.INTERPOLATE_LANCZOS)
	var pecas := {"cerca_horizontal": horizontal, "cerca_vertical": vertical, "cerca_poste": poste}
	var flores := Image.load_from_file("res://arte/fontes/cidade/enfeites_detalhados/flores.png")
	flores = flores.get_region(_area(flores))
	flores.resize(32, 24, Image.INTERPOLATE_LANCZOS)
	for v in 2:
		var desenho: Image = mato.duplicate()
		if v == 1: desenho.flip_x()
		var quadro := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		quadro.blend_rect(desenho, Rect2i(Vector2i.ZERO, desenho.get_size()), Vector2i(12, 20))
		pecas["mato_%d" % v] = quadro
		var flor: Image = flores.duplicate()
		if v == 1: flor.flip_x()
		var tela := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		tela.blend_rect(flor, Rect2i(Vector2i.ZERO, flor.get_size()), Vector2i(16, 28))
		pecas["flor_%d" % v] = tela
	for nome: String in pecas:
		for e in 4: _salvar(_estacao(pecas[nome], e, nome.begins_with("mato") or nome.begins_with("flor")), SAIDA + ESTACOES[e] + "/" + nome + ".png")
	_casa()
	print("Acabamento da fazenda: três peças de cerca, dois matos e casa; quatro estações.")
	quit()

func _area(imagem: Image) -> Rect2i:
	var minimo := imagem.get_size()
	var maximo := Vector2i.ZERO
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x, y).a > .5:
				minimo = Vector2i(mini(minimo.x, x), mini(minimo.y, y))
				maximo = Vector2i(maxi(maximo.x, x), maxi(maximo.y, y))
	return Rect2i(minimo, maximo - minimo + Vector2i.ONE)

func _estacao(base: Image, e: int, planta: bool, neve := 5) -> Image:
	var imagem: Image = base.duplicate()
	if e == 0: return imagem
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a < .01: continue
			if planta:
				if e == 1: cor = Color(cor.r * .86, cor.g * .93, cor.b * .86, cor.a)
				elif e == 2: cor = Color.from_hsv(.105, cor.s * .70, cor.v * .92, cor.a)
				else: cor = Color.from_hsv(.12, cor.s * .20, cor.v * .75, cor.a)
			else:
				var fator := 1.025 if e == 1 else (.96 if e == 2 else .91)
				cor = Color(cor.r * fator, cor.g * fator, cor.b * fator, cor.a)
			imagem.set_pixel(x, y, cor)
	if e == 3:
		# Cobertura apenas nas faces expostas de cada poste, travessa e folha.
		for x in imagem.get_width():
			for y in imagem.get_height():
				if base.get_pixel(x, y).a < .7: continue
				if y > 0 and base.get_pixel(x, y - 1).a > .4: continue
				for dy in (3 if planta else neve):
					if y + dy >= imagem.get_height(): break
					var cor := imagem.get_pixel(x, y + dy)
					if cor.a < .5: break
					imagem.set_pixel(x, y + dy, Color(.88, .93, .95, cor.a) if dy < (2 if planta else neve - 2) else Color(.66, .77, .82, cor.a))
	return imagem

func _salvar(imagem: Image, caminho: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	assert(imagem.save_png(caminho) == OK)
	var config := ConfigFile.new()
	if config.load(caminho + ".import") != OK:
		config.set_value("remap", "importer", "texture")
		config.set_value("remap", "type", "CompressedTexture2D")
		config.set_value("deps", "source_file", caminho)
	config.set_value("params", "mipmaps/generate", true)
	config.save(caminho + ".import")

func _casa() -> void:
	var fonte := Image.load_from_file(FONTES + "casa.png")
	var area := _area(fonte)
	var base := fonte.get_region(area)
	base.resize(448, 360, Image.INTERPOLATE_LANCZOS)
	var inverno := Image.load_from_file(FONTES + "casa_inverno.png")
	# A faixa vazia superior contém um pequeno ponto solto, fora da construção.
	inverno = inverno.get_region(Rect2i(0, 40, inverno.get_width(), inverno.get_height() - 40))
	inverno = inverno.get_region(_area(inverno))
	inverno.resize(448, 360, Image.INTERPOLATE_LANCZOS)
	var manifesto := "res://assets/cenario/cidade/fachadas_detalhadas/manifesto.json"
	var conteudo := FileAccess.get_file_as_string(manifesto)
	var dados: Dictionary = JSON.parse_string(conteudo)
	var caminhos: Array[String] = []
	for e in 4:
		var caminho: String = "res://assets/cenario/cidade/fachadas_detalhadas/casa_jogador/" + ESTACOES[e] + ".png"
		_salvar(inverno if e == 3 else _estacao(base, e, false), caminho)
		caminhos.append(caminho)
	var sombra: Image = base.duplicate()
	for y in sombra.get_height():
		for x in sombra.get_width(): sombra.set_pixel(x, y, Color(1, 1, 1, sombra.get_pixel(x, y).a))
	_salvar(sombra, "res://assets/cenario/cidade/sombras/casas/casa_jogador.png")
	dados.casa_jogador = {"texturas": caminhos, "quadros": 1, "fps": 0, "resolucao": 4,
		"fonte": FONTES + "casa.png", "canvas_logico": [112, 90],
		"chamine": [35.5, -88], "janelas": [[-28, -25], [28, -25]],
		"ancora_fonte": [area.position.x + area.size.x * .5, area.end.y],
		"area_fonte": [area.position.x, area.position.y, area.size.x, area.size.y]}
	# Evita regravar números e metadados de fachadas alheias à fazenda.
	var trecho := RegEx.new()
	trecho.compile('(?ms)^ "casa_jogador": \\{.*?^ \\}')
	var encontrado := trecho.search(conteudo)
	assert(encontrado != null)
	var item := ' "casa_jogador": ' + JSON.stringify(dados.casa_jogador, " ", false).replace("\n", "\n ")
	conteudo = conteudo.substr(0, encontrado.get_start()) + item + conteudo.substr(encontrado.get_end())
	FileAccess.open(manifesto, FileAccess.WRITE).store_string(conteudo)
