extends SceneTree

const Recorte := preload("res://ferramentas/inimigos/preparar_dragao.gd")
const PAGINAS := ["movimento", "garras", "cauda", "bote", "olhar"]
const LADO := 256
const LINHAS := [0, 1, 3, 2] # Fontes: frente, costas, esquerda, direita; jogo: frente, costas, direita, esquerda.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/inimigos/medusa"))
	for pagina in PAGINAS:
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
