extends SceneTree
## Monta as poses fornecidas sem redesenhá-las e sem carregar a partida.

const PASTA := "assets/personagens/base_ataque_uma_mao"
const FONTES := "arte/fontes/personagem/ataque_uma_mao"
const PREVIAS := "arte/previas/personagem/ataque_uma_mao"
const DIRECOES := ["baixo", "direita", "cima", "esquerda"]
const CONTAGENS := [6, 5, 4, 5]
const TAMANHO := 64
const PES_Y := 44
const ALTURA := 31
var raiz := ""

func _initialize() -> void:
	raiz = OS.get_cmdline_user_args()[0]
	if DisplayServer.get_name() == "headless":
		montar()
		quit()
	else:
		mostrar.call_deferred()

func carregar(caminho: String) -> Image:
	var imagem := Image.load_from_file(raiz.path_join(caminho))
	assert(imagem != null and not imagem.is_empty(), caminho)
	imagem.convert(Image.FORMAT_RGBA8)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= 0.5 else 0.0
			imagem.set_pixel(x, y, cor)
	return imagem

func escrever(caminho: String, texto: String) -> void:
	var arquivo := FileAccess.open(raiz.path_join(caminho), FileAccess.WRITE)
	assert(arquivo != null, caminho)
	arquivo.store_string(texto)

func regioes_linha(imagem: Image, linha: int) -> Array[Rect2i]:
	var regioes: Array[Rect2i] = []
	# A fonte gerada não respeita divisões verticais exatas: usar faixas medidas
	# impede que a sola de uma direção apareça como risco na seguinte.
	var bandas := [Vector2i(42, 238), Vector2i(297, 482), Vector2i(526, 710), Vector2i(736, 916)]
	var y0: int = bandas[linha].x
	var altura: int = bandas[linha].y - y0
	var inicio := -1
	var ultimo := -1
	for x in imagem.get_width():
		var pontos := 0
		for y in range(y0, y0 + altura):
			if imagem.get_pixel(x, y).a > 0.5:
				pontos += 1
		if pontos < 4:
			continue
		if inicio >= 0 and x - ultimo > 8:
			regioes.append(Rect2i(inicio, y0, ultimo - inicio + 1, altura))
			inicio = -1
		if inicio < 0:
			inicio = x
		ultimo = x
	if inicio >= 0:
		regioes.append(Rect2i(inicio, y0, ultimo - inicio + 1, altura))
	return regioes

func montar() -> void:
	DirAccess.make_dir_recursive_absolute(raiz.path_join(PASTA))
	var original := carregar(FONTES + "/uniforme-v1.png")
	var costas := carregar(FONTES + "/costas-ataque-v3.png")
	assert(original.get_size() == Vector2i(1659, 948))
	assert(costas.get_size() == Vector2i(2172, 724))
	var regioes: Array = []
	for linha in 4:
		regioes.append(regioes_linha(original, linha))
		assert(regioes[linha].size() == [6, 5, 5, 5][linha])
	var folha := Image.create(448, 256, false, Image.FORMAT_RGBA8)
	# Cada fonte é normalizada pela pose parada, preservando a altura dos agachamentos.
	var altura_original := original.get_region(regioes[1][0]).get_used_rect().size.y
	var altura_costas := costas.get_region(Rect2i(0, 0, 543, 724)).get_used_rect().size.y
	var quadros: Array = []
	var subrecursos := ""
	var animacoes: Array[String] = []
	var indice := 1
	for linha in 4:
		var frames: Array[String] = []
		for coluna in CONTAGENS[linha]:
			# A revisão das costas tem quatro quadros; demais direções são preservadas.
			var regiao: Rect2i = Rect2i(coluna * 543, 0, 543, 724) if linha == 2 else regioes[linha][coluna]
			var largura := regiao.size.x
			var imagem_fonte := costas if linha == 2 else original
			var quadro := imagem_fonte.get_region(regiao)
			var area := quadro.get_used_rect()
			assert(area.has_area())
			var fator := float(ALTURA) / (altura_costas if linha == 2 else altura_original)
			# O pivô horizontal acompanha a base dos pés, nunca a ponta do braço.
			var faixa := maxi(1, roundi(2.0 / fator))
			var sola := quadro.get_region(Rect2i(0, area.end.y - faixa, largura, faixa)).get_used_rect()
			var pivo_x := sola.position.x + sola.size.x / 2.0
			var recorte := quadro.get_region(area)
			recorte.resize(maxi(1, roundi(area.size.x * fator)), maxi(1, roundi(area.size.y * fator)), Image.INTERPOLATE_NEAREST)
			assert(recorte.get_used_rect().has_area())
			var destino := Vector2i(roundi(32.0 + (area.position.x - pivo_x) * fator), PES_Y - recorte.get_height())
			assert(destino.x >= 0 and destino.y >= 0 and destino.x + recorte.get_width() <= 64)
			folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(coluna * 64, linha * 64) + destino)
			quadros.append({"direcao": DIRECOES[linha], "coluna": coluna, "linha": linha, "fonte": "costas-ataque-v3.png" if linha == 2 else "uniforme-v1.png", "regiao_fonte": [regiao.position.x, regiao.position.y, regiao.size.x, regiao.size.y], "escala_fonte": fator})
			subrecursos += "[sub_resource type=\"AtlasTexture\" id=\"Quadro_%d\"]\natlas = ExtResource(\"1\")\nregion = Rect2(%d, %d, 64, 64)\n\n" % [indice, coluna * 64, linha * 64]
			var duracao: float = [1.2, 0.6, 1.0, 2.2][coluna] if linha == 2 else 1.0
			frames.append("{\"duration\": %s, \"texture\": SubResource(\"Quadro_%d\")}" % [str(duracao), indice])
			indice += 1
		animacoes.append("{\"frames\": [%s], \"loop\": false, \"name\": &\"ataque_%s\", \"speed\": 10.0}" % [", ".join(frames), DIRECOES[linha]])
	assert(folha.save_png(raiz.path_join(PASTA + "/folha.png")) == OK)
	DirAccess.make_dir_recursive_absolute(raiz.path_join(PREVIAS))
	for coluna in 4:
		var previa := folha.get_region(Rect2i(coluna * 64, 128, 64, 64))
		previa.resize(256, 256, Image.INTERPOLATE_NEAREST)
		previa.save_png(raiz.path_join(PREVIAS + "/costas_%d.png" % coluna))
	var manifesto := {"versao": 2, "quadro": [64, 64], "grade": [7, 4], "pes_y": PES_Y, "pivo": [32, PES_Y], "offset_sprite_centralizado": [0, -12], "filtro": "nearest", "altura_parado": ALTURA, "direcoes": DIRECOES, "quadros_por_direcao": CONTAGENS, "total_poses": quadros.size(), "celulas_restantes": "transparentes", "acao": "ataque_espada_uma_mao_corpo", "camada_arma": false, "roupa": "camiseta_azul_shorts_marrons_sapatos_marrons_em_todas_as_direcoes", "base_tecnica": "arte/fontes/npcs/base_vila/adulto_avental.json", "quadros": quadros}
	escrever(PASTA + "/manifesto.json", JSON.stringify(manifesto, "\t") + "\n")
	var recurso := "[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://%s/folha.png\" id=\"1\"]\n\n" % [indice + 1, PASTA]
	escrever(PASTA + "/animacoes.tres", recurso + subrecursos + "[resource]\nanimations = [%s]\n" % ",\n".join(animacoes))
	print("Folha uniforme: 20 poses, 448x256, células 64x64, pés y44; costas revisadas.")

class Painel extends Node2D:
	var folha: Texture2D
	var morador: Texture2D
	func _draw() -> void:
		var fonte := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1510, 1060), Color("18202b"))
		draw_string(fonte, Vector2(24, 35), "Ataque de uma mão — todas as poses / grade dos NPCs", HORIZONTAL_ALIGNMENT_LEFT, -1, 23)
		draw_string(fonte, Vector2(24, 62), "64×64 • pés y44 • altura parada 31px • 7×4 • ampliação 3× sem filtro", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("b5c5d8"))
		for linha in 4:
			draw_string(fonte, Vector2(18, 143 + linha * 192), DIRECOES[linha], HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
			for coluna in 7:
				var origem := Vector2(140 + coluna * 192, 86 + linha * 192)
				draw_rect(Rect2(origem, Vector2(192, 192)), Color("303d4e"), false)
				draw_line(origem + Vector2(0, 132), origem + Vector2(192, 132), Color("506b62"))
		draw_texture_rect(folha, Rect2(140, 86, 1344, 768), false)
		draw_string(fonte, Vector2(24, 893), "Comparação de tamanho com Tomas (mesma escala 3×):", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_texture_rect_region(morador, Rect2(490, 864, 192, 192), Rect2(0, 0, 64, 64))
		draw_texture_rect_region(folha, Rect2(690, 864, 192, 192), Rect2(0, 64, 64, 64))
		draw_texture_rect_region(folha, Rect2(890, 864, 192, 192), Rect2(0, 128, 64, 64))
		draw_string(fonte, Vector2(24, 950), "20 poses preservadas; 8 células vazias.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		draw_string(fonte, Vector2(24, 979), "Mesmo personagem e roupa nas quatro direções.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)

func mostrar() -> void:
	root.size = Vector2i(1510, 1060)
	var painel := Painel.new()
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.folha = ImageTexture.create_from_image(carregar(PASTA + "/folha.png"))
	painel.morador = ImageTexture.create_from_image(carregar("assets/npcs/cidade/tomas.png"))
	root.add_child(painel)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(raiz.path_join(PREVIAS))
	root.get_texture().get_image().save_png(raiz.path_join(PREVIAS + "/folha_no_godot.png"))
	print("Prévia renderizada no Godot sem carregar autoloads ou saves.")
	quit()
