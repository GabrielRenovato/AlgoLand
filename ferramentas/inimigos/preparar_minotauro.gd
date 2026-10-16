extends SceneTree

const Recorte := preload("res://ferramentas/inimigos/preparar_dragao.gd")
const PAGINAS := ["movimento", "caminhada", "investida", "pisao", "machado", "furia"]
const LADO := 192
const CONTEUDO := 176
const MARGEM := 8
const PALETA := ["201c28", "342c32", "503a32", "71503d", "976a48", "bd8b60", "ddac7d", "3d4148", "64656a", "909394", "c3c4b6", "594126", "8e6735", "c79a4d", "e7c174", "fff0bd", "41492d", "77804a", "a3292b", "271d22", "42302b", "604133", "80583e", "ac7952", "c99768", "edbe8a", "f5d2a2", "252e3a", "45515d", "697580", "9ba8af", "e0ddd0", "705025", "aa813e", "d5ad61", "f6d98e", "2d3726", "586137", "94a265", "642128", "cf4436"]

func _initialize() -> void:
	for pagina in PAGINAS:
		var colunas := 6
		var sufixo := "_v2.png" if pagina == "caminhada" else ("_arma_v3.png" if pagina == "machado" else "_arma_v2.png")
		var fonte := Image.load_from_file("res://arte/fontes/inimigos/minotauro/" + pagina + sufixo)
		if fonte == null or fonte.is_empty():
			if pagina != "movimento":
				continue
			quit(1)
			return
		var folha := Image.create(colunas * LADO, 4 * LADO, false, Image.FORMAT_RGBA8)
		for linha in 4:
			for coluna in colunas:
				# Margem uniforme: a arma pode atravessar a grade da fonte sem ser cortada.
				var centro := Vector2i(roundi((coluna + 0.5) * fonte.get_width() / float(colunas)), roundi((linha + 0.5) * fonte.get_height() / 4.0))
				var janela := Rect2i(centro - Vector2i(224, 224), Vector2i(448, 448))
				var faixa := Rect2i(0, roundi(linha * fonte.get_height() / 4.0), fonte.get_width(), roundi(fonte.get_height() / 4.0))
				var regiao := janela.intersection(faixa)
				var quadro := Image.create(448, 448, false, Image.FORMAT_RGBA8)
				quadro.blit_rect(fonte, regiao, regiao.position - janela.position)
				quadro = Recorte.extrair_silhueta(quadro)
				quadro.resize(CONTEUDO, CONTEUDO, Image.INTERPOLATE_NEAREST)
				for y in CONTEUDO:
					for x in CONTEUDO:
						var pixel := quadro.get_pixel(x, y)
						if pixel.a < 0.5:
							quadro.set_pixel(x, y, Color.TRANSPARENT)
							continue
						var menor := INF
						var melhor := Color.BLACK
						for html in PALETA:
							var cor := Color.html(html)
							var distancia := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
							if distancia < menor:
								menor = distancia
								melhor = cor
						quadro.set_pixel(x, y, melhor)
				quadro = Recorte.extrair_silhueta(quadro)
				folha.blit_rect(quadro, Rect2i(0, 0, CONTEUDO, CONTEUDO), Vector2i(coluna * LADO + MARGEM, linha * LADO + MARGEM))
		folha.save_png("res://assets/inimigos/minotauro/" + pagina + ".png")
		print("Minotauro: ", pagina, " ", folha.get_size())
	quit()
