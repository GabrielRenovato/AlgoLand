extends SceneTree

const PAGINAS := ["movimento", "porretada", "varrida", "salto", "furia", "execucao"]
const LADO := 256

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/inimigos/goblin_maromba"))
	for pagina in PAGINAS:
		var caminho: String = "res://arte/fontes/inimigos/goblin_maromba/" + pagina + "_v1.png"
		if FileAccess.file_exists("res://arte/fontes/inimigos/goblin_maromba/" + pagina + "_v2.png"):
			caminho = "res://arte/fontes/inimigos/goblin_maromba/" + pagina + "_v2.png"
		var fonte := Image.load_from_file(caminho)
		if fonte == null:
			quit(1)
			return
		var folha := Image.create(6 * LADO, 4 * LADO, false, Image.FORMAT_RGBA8)
		var quadros := _recortar_poses(fonte)
		if quadros.size() != 24:
			quit(1)
			return
		if pagina == "movimento":
			if not _salvar_movimento(quadros, fonte.get_width()):
				quit(1)
				return
			continue
		if pagina == "porretada" and FileAccess.file_exists("res://arte/fontes/inimigos/goblin_maromba/preparacao_v1.png"):
			var preparacao := Image.load_from_file("res://arte/fontes/inimigos/goblin_maromba/preparacao_v1.png")
			var poses := _recortar_poses(preparacao, 2, 2)
			if poses.size() != 4:
				quit(1)
				return
			for linha in 4:
				var pose := poses[linha]
				var fator := 260.0 / maxf(pose.get_width(), pose.get_height())
				pose.resize(roundi(pose.get_width() * fator), roundi(pose.get_height() * fator), Image.INTERPOLATE_NEAREST)
				quadros[linha * 6 + 2] = pose
		for i in 24:
			var quadro := quadros[i]
			var fator := minf(0.9 * 1536.0 / fonte.get_width(), 240.0 / maxf(quadro.get_width(), quadro.get_height()))
			quadro.resize(roundi(quadro.get_width() * fator), roundi(quadro.get_height() * fator), Image.INTERPOLATE_NEAREST)
			folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i((i % 6) * LADO + (LADO - quadro.get_width()) / 2, (i / 6) * LADO + 240 - quadro.get_height()))
		folha.save_png("res://assets/inimigos/goblin_maromba/" + pagina + ".png")
		print("Goblin: ", pagina, " / 24 poses")
	quit()

func _salvar_movimento(originais: Array[Image], largura_fonte: int) -> bool:
	var caminho := "res://arte/fontes/inimigos/goblin_maromba/caminhada_lateral_v2.png"
	var lateral := Image.load_from_file(caminho)
	if lateral == null:
		return false
	var poses := _recortar_poses(lateral)
	if poses.size() != 24:
		return false
	var quadros: Array[Image] = []
	for linha in 4:
		for coluna in 12:
			var pose: Image = originais[linha * 6 + coluna / 2] if linha < 2 else poses[(linha - 2) * 12 + coluna]
			quadros.append(pose.get_region(Rect2i(Vector2i.ZERO, pose.get_size())))
	var centros: Array[float] = []
	var fator := minf(0.9 * 1536.0 / largura_fonte, 0.9 * 1536.0 / lateral.get_width())
	for quadro in quadros:
		# Ancora o tronco, não o centro da caixa que muda quando a arma balança.
		var soma := 0.0
		var quantidade := 0
		for y in range(int(quadro.get_height() * 0.25), int(quadro.get_height() * 0.5)):
			for x in quadro.get_width():
				if quadro.get_pixel(x, y).a > 0.5:
					soma += x
					quantidade += 1
		var centro := soma / maxi(1, quantidade)
		centros.append(centro)
		fator = minf(fator, 124.0 / maxf(centro, quadro.get_width() - centro))
		fator = minf(fator, 224.0 / quadro.get_height())
	var folha := Image.create(12 * LADO, 4 * LADO, false, Image.FORMAT_RGBA8)
	for i in quadros.size():
		var quadro := quadros[i]
		quadro.resize(roundi(quadro.get_width() * fator), roundi(quadro.get_height() * fator), Image.INTERPOLATE_NEAREST)
		var posicao := Vector2i((i % 12) * LADO + 128 - roundi(centros[i] * fator), (i / 12) * LADO + 240 - quadro.get_height())
		folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), posicao)
	folha.save_png("res://assets/inimigos/goblin_maromba/movimento.png")
	print("Goblin: movimento / 12 quadros por direção, tronco ancorado")
	return true

func _recortar_poses(fonte: Image, linhas: int = 4, colunas: int = 6) -> Array[Image]:
	var total := linhas * colunas
	fonte.convert(Image.FORMAT_RGBA8)
	var largura := fonte.get_width()
	var altura := fonte.get_height()
	var visitados := PackedByteArray()
	visitados.resize(largura * altura)
	var componentes: Array[Dictionary] = []
	for y in altura:
		for x in largura:
			var indice := y * largura + x
			if visitados[indice] == 1 or fonte.get_pixel(x, y).a < 0.5:
				continue
			var fila := PackedInt32Array([indice])
			visitados[indice] = 1
			var cursor := 0
			var minimo := Vector2i(x, y)
			var maximo := minimo
			while cursor < fila.size():
				var atual := fila[cursor]
				cursor += 1
				var ponto := Vector2i(atual % largura, atual / largura)
				minimo = minimo.min(ponto)
				maximo = maximo.max(ponto)
				for vizinho in [ponto + Vector2i.LEFT, ponto + Vector2i.RIGHT, ponto + Vector2i.UP, ponto + Vector2i.DOWN]:
					if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= largura or vizinho.y >= altura:
						continue
					var proximo: int = vizinho.y * largura + vizinho.x
					if visitados[proximo] == 0 and fonte.get_pixelv(vizinho).a >= 0.5:
						visitados[proximo] = 1
						fila.append(proximo)
			if fila.size() > 8:
				componentes.append({"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE), "pixels": fila})
	componentes.sort_custom(func(a, b): return a.pixels.size() > b.pixels.size())
	if componentes.size() < total:
		push_error("Folha com poses conectadas: " + str(componentes.size()))
		return []
	var partes := componentes.slice(total)
	componentes.resize(total)
	# Mãos, cabo e cabeça da arma podem formar ilhas de alpha separadas.
	# Une cada ilha à pose mais próxima antes de recortar, sem perder o porrete.
	for parte in partes:
		var melhor := -1
		var distancia := INF
		var retangulo: Rect2i = parte.retangulo
		for i in total:
			var corpo: Rect2i = componentes[i].retangulo
			var separacao := Vector2(maxi(0, maxi(corpo.position.x - retangulo.end.x, retangulo.position.x - corpo.end.x)), maxi(0, maxi(corpo.position.y - retangulo.end.y, retangulo.position.y - corpo.end.y)))
			var medida := separacao.length() + retangulo.get_center().distance_to(corpo.get_center()) * 0.01
			if medida < distancia:
				distancia = medida
				melhor = i
		if melhor >= 0 and distancia < 28:
			componentes[melhor].pixels.append_array(parte.pixels)
			componentes[melhor].retangulo = componentes[melhor].retangulo.merge(retangulo)
	componentes.sort_custom(func(a, b): return a.retangulo.get_center().y < b.retangulo.get_center().y)
	var quadros: Array[Image] = []
	for linha in linhas:
		var poses := componentes.slice(linha * colunas, (linha + 1) * colunas)
		poses.sort_custom(func(a, b): return a.retangulo.get_center().x < b.retangulo.get_center().x)
		for pose in poses:
			var retangulo: Rect2i = pose.retangulo
			var imagem := Image.create(retangulo.size.x, retangulo.size.y, false, Image.FORMAT_RGBA8)
			for indice in pose.pixels:
				var ponto := Vector2i(indice % largura, indice / largura)
				var cor := fonte.get_pixelv(ponto)
				cor.a = 1
				imagem.set_pixelv(ponto - retangulo.position, cor)
			quadros.append(imagem)
	return quadros
