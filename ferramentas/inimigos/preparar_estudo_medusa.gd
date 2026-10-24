extends SceneTree
const Recorte := preload("res://ferramentas/inimigos/preparar_dragao.gd")
const PASTA := "res://arte/previas/inimigos/medusa/poses_20261024/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var fonte := Image.load_from_file("res://arte/fontes/inimigos/medusa/poses_20261024/garras_direita.png")
	fonte.convert(Image.FORMAT_RGBA8)
	if fonte.get_size() != Vector2i(1536, 1024):
		quit(1)
		return
	var anterior := Image.load_from_file("res://assets/inimigos/medusa/garras.png")
	var folha := Image.create(1152, 768, false, Image.FORMAT_RGBA8)
	for linha in 4:
		for coluna in 6:
			folha.blit_rect(anterior, Rect2i(coluna * 160, linha * 160, 160, 160), Vector2i(coluna * 192 + 16, linha * 192 + 16))
	for indice in 6:
		var linha := indice / 3
		var area := Rect2i((indice % 3) * 512 - 64, linha * 512 - 64, 640, 640)
		var intersecao := area.intersection(Rect2i(Vector2i.ZERO, fonte.get_size()))
		var quadro := Image.create(640, 640, false, Image.FORMAT_RGBA8)
		quadro.blit_rect(fonte, intersecao, intersecao.position - area.position)
		# Escala única184/640. Compensa apenas a diagramação das duas fileiras,
		# sem normalizar tamanho, caixa delimitadora ou posição de cada pose.
		quadro.resize(184, 184, Image.INTERPOLATE_NEAREST)
		for y in 184:
			for x in 184:
				var pixel := quadro.get_pixel(x, y)
				pixel.a = 1 if pixel.a >= 0.5 else 0
				quadro.set_pixel(x, y, pixel if pixel.a > 0 else Color.TRANSPARENT)
		quadro = Recorte.extrair_silhueta(quadro)
		var celula := Image.create(192, 192, false, Image.FORMAT_RGBA8)
		celula.blit_rect(quadro, Rect2i(0, 0, 184, 184), Vector2i(4, -2 if linha == 0 else 6))
		folha.fill_rect(Rect2i(indice * 192, 384, 192, 192), Color.TRANSPARENT)
		folha.blit_rect(celula, Rect2i(0, 0, 192, 192), Vector2i(indice * 192, 384))
	folha.save_png(PASTA + "garras_direita_folha.png")
	quit()
