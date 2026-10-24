extends SceneTree

const Recorte := preload("res://ferramentas/inimigos/preparar_dragao.gd")
const PAGINAS := ["movimento", "garras", "cauda", "bote", "olhar"]
const LADO := 256
const LINHAS := [0, 1, 3, 2] # Fontes: frente, costas, esquerda, direita; jogo: frente, costas, direita, esquerda.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/inimigos/medusa"))
	for pagina in PAGINAS:
		var fonte_cidade: String = "res://arte/fontes/inimigos/medusa/revisao_cidade/" + pagina + ".png"
		if FileAccess.file_exists(fonte_cidade):
			var original := Image.load_from_file(fonte_cidade)
			if original.get_size() != Vector2i(1536, 1024):
				push_error("Grade inesperada na Medusa: " + pagina)
				quit(1)
				return
			# Transformação única para a folha inteira: mantém raiz, gesto e balanço.
			original.convert(Image.FORMAT_RGBA8)
			if pagina == "bote":
				_compor_chaves_bote(original)
			_preparar_cidade(original).save_png("res://assets/inimigos/medusa/" + pagina + ".png")
			print("Medusa cidade: ", pagina, " / grade fixa 160px, sem recentralizar poses")
			continue
		var revisada: String = "res://arte/fontes/inimigos/medusa/revisao_nitidez/"+pagina+".png"
		if FileAccess.file_exists(revisada):
			var fonte_nova := Image.load_from_file(revisada)
			var nativa := Image.create(768,512,false,Image.FORMAT_RGBA8)
			for linha in 4:
				for coluna in 6:
					var quadro := fonte_nova.get_region(Rect2i(coluna*256,linha*256,256,256))
					quadro.convert(Image.FORMAT_RGBA8)
					quadro.resize(128,128,Image.INTERPOLATE_NEAREST)
					for y in 128:
						for x in 128:
							var pixel := quadro.get_pixel(x,y)
							pixel.a=1 if pixel.a>=.5 else 0
							quadro.set_pixel(x,y,pixel if pixel.a>0 else Color.TRANSPARENT)
					quadro=Recorte.extrair_silhueta(quadro)
					var limites := quadro.get_used_rect()
					if not limites.has_area():
						push_error("Pose vazia: "+pagina)
						quit(1)
						return
					# Encaixe no chão preservado; não normaliza largura/altura por pose.
					nativa.blit_rect(quadro,limites,Vector2i(coluna*128+limites.position.x,linha*128+120-limites.size.y))
			nativa.save_png("res://assets/inimigos/medusa/"+pagina+".png")
			print("Medusa nativa: ",pagina," 128px, 24 poses")
			continue
		var caminho: String = "res://arte/fontes/inimigos/medusa/" + pagina + "_v1.png"
		if FileAccess.file_exists("res://arte/fontes/inimigos/medusa/" + pagina + "_v2.png"):
			caminho = "res://arte/fontes/inimigos/medusa/" + pagina + "_v2.png"
		var fonte := Image.load_from_file(caminho)
		if fonte == null:
			quit(1)
			return
		var quadros: Array[Image] = []
		var frente_costas: Image
		if pagina == "bote" and FileAccess.file_exists("res://arte/fontes/inimigos/medusa/bote_frente_costas_v3.png"):
			frente_costas = Image.load_from_file("res://arte/fontes/inimigos/medusa/bote_frente_costas_v3.png")
		var altura_maxima := 0
		for linha in 4:
			for coluna in 6:
				var origem: Image = frente_costas if frente_costas != null and linha < 2 else fonte
				var linhas_fonte := 2 if origem == frente_costas else 4
				var linha_fonte: int = linha if origem == frente_costas else LINHAS[linha]
				var inicio := Vector2i(roundi(coluna * origem.get_width() / 6.0), roundi(linha_fonte * origem.get_height() / float(linhas_fonte)))
				var fim := Vector2i(roundi((coluna + 1) * origem.get_width() / 6.0), roundi((linha_fonte + 1) * origem.get_height() / float(linhas_fonte)))
				var quadro := origem.get_region(Rect2i(inicio, fim - inicio))
				# A correção frontal usa células mais altas; converte o tamanho antes de medir a silhueta.
				if origem == frente_costas:
					quadro.resize(fonte.get_width() / 6, fonte.get_height() / 4, Image.INTERPOLATE_NEAREST)
				quadro.convert(Image.FORMAT_RGBA8)
				for y in quadro.get_height():
					for x in quadro.get_width():
						var pixel := quadro.get_pixel(x, y)
						pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
						quadro.set_pixel(x, y, pixel if pixel.a > 0 else Color.TRANSPARENT)
				quadro = Recorte.extrair_silhueta(quadro)
				var limites := quadro.get_used_rect()
				if not limites.has_area():
					push_error("Pose vazia: " + pagina + " / " + str(linha * 6 + coluna))
					quit(1)
					return
				altura_maxima = maxi(altura_maxima, limites.size.y)
				quadros.append(quadro.get_region(limites))
		if frente_costas != null:
			var altura_frontal := 0
			for i in 12:
				altura_frontal = maxi(altura_frontal, quadros[i].get_height())
			var compensacao := float(altura_maxima) / altura_frontal
			for i in 12:
				quadros[i].resize(roundi(quadros[i].get_width() * compensacao), roundi(quadros[i].get_height() * compensacao), Image.INTERPOLATE_NEAREST)
		var fator := 224.0 / altura_maxima
		var folha := Image.create(6 * LADO, 4 * LADO, false, Image.FORMAT_RGBA8)
		for i in quadros.size():
			var quadro := quadros[i]
			var escala := minf(fator, 240.0 / quadro.get_width())
			quadro.resize(maxi(1, roundi(quadro.get_width() * escala)), maxi(1, roundi(quadro.get_height() * escala)), Image.INTERPOLATE_NEAREST)
			var posicao := Vector2i((LADO - quadro.get_width()) / 2, 240 - quadro.get_height())
			folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i((i % 6) * LADO, (i / 6) * LADO) + posicao)
		folha.save_png("res://assets/inimigos/medusa/" + pagina + ".png")
		print("Medusa: ", pagina, " / ", folha.get_size(), " / 24 poses completas")
	quit()

func _compor_chaves_bote(folha: Image) -> void:
	# O estudo dirigido contém só impacto/continuação; demais poses ficam na folha.
	# Registro por direção, comum aos dois quadros. Sem normalização por silhueta.
	var chaves := Image.load_from_file("res://arte/fontes/inimigos/medusa/revisao_cidade/bote_chaves.png")
	chaves.convert(Image.FORMAT_RGBA8)
	var limites := [0, 350, 745, 1100, 1536]
	var bases := [344, 390, 349, 377]
	for linha in 4:
		for coluna in 2:
			var recorte := chaves.get_region(Rect2i(coluna * 512, limites[linha], 512, limites[linha + 1] - limites[linha]))
			recorte.resize(328, roundi(recorte.get_height() * 0.64), Image.INTERPOLATE_NEAREST)
			var celula := Image.create(256, 256, false, Image.FORMAT_RGBA8)
			celula.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(-36, 240 - roundi(bases[linha] * 0.64)))
			folha.blit_rect(celula, Rect2i(0, 0, 256, 256), Vector2i((coluna + 3) * 256, linha * 256))

func _preparar_cidade(fonte: Image) -> Image:
	var folha := Image.create(960, 640, false, Image.FORMAT_RGBA8)
	for linha in 4:
		for coluna in 6:
			# Margem de leitura recupera cobras/mãos que cruzaram a grade da fonte.
			# A transformação é idêntica nas120 poses; não alinha pela caixa da silhueta.
			var area := Rect2i(coluna * 256 - 40, linha * 256 - 40, 336, 336)
			var intersecao := area.intersection(Rect2i(Vector2i.ZERO, fonte.get_size()))
			var quadro := Image.create(336, 336, false, Image.FORMAT_RGBA8)
			quadro.blit_rect(fonte, intersecao, intersecao.position - area.position)
			quadro.resize(155, 155, Image.INTERPOLATE_NEAREST)
			for y in 155:
				for x in 155:
					var pixel := quadro.get_pixel(x, y)
					pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
					quadro.set_pixel(x, y, pixel if pixel.a > 0 else Color.TRANSPARENT)
			quadro = Recorte.extrair_silhueta(quadro)
			# Margem uniforme16px permite estender as mãos sem cortar o golpe.
			var celula := Image.create(160, 160, false, Image.FORMAT_RGBA8)
			celula.blit_rect(quadro, Rect2i(0, 0, 155, 155), Vector2i(3, 8))
			folha.blit_rect(celula, Rect2i(0, 0, 160, 160), Vector2i(coluna * 160, linha * 160))
	return folha
