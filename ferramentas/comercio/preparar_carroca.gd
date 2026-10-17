extends SceneTree

## A arte gerada permanece em alta resolução; o conjunto controla a escala no motor.
const FONTE := "res://arte/fontes/comercio/carroca_arte.png"
const INVERNO := "res://arte/fontes/comercio/carroca_arte_inverno.png"
const PIXELS_POR_UNIDADE := 19
const TELA := Vector2i(1824, 1216)
const ORIGEM := Vector2i(2, 232)
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const RODAS := [Vector2i(418, 938), Vector2i(1162, 938)]
const RAIO_GIRO := 122

static func enquadrar(origem: Image) -> Image:
	var tela := Image.create(TELA.x, TELA.y, false, Image.FORMAT_RGBA8)
	tela.blit_rect(origem, Rect2i(Vector2i.ZERO, origem.get_size()), ORIGEM)
	return tela

static func variante(origem: Image, estacao: int) -> Image:
	var imagem := origem.duplicate() as Image
	if estacao == 0 or estacao == 3:
		return imagem
	for y in imagem.get_height():
		for x in imagem.get_width():
			var pixel := imagem.get_pixel(x, y)
			if pixel.a == 0 or pixel.r <= pixel.g * 1.12 or pixel.g <= pixel.b * 1.10:
				continue
			# Madeira mais seca e clara no verão; úmida e escura no outono.
			if estacao == 1:
				pixel = Color(minf(pixel.r * 1.05 + 0.01, 1.0), minf(pixel.g * 1.09 + 0.01, 1.0), minf(pixel.b * 1.13 + 0.01, 1.0), pixel.a)
			else:
				pixel = Color(pixel.r * 0.87, pixel.g * 0.81, pixel.b * 0.82, pixel.a)
			imagem.set_pixel(x, y, pixel)
	return imagem

static func quadro_andando(base: Image, quadro: int) -> Image:
	var imagem := base.duplicate() as Image
	var angulo := TAU * quadro / 32.0
	for centro: Vector2i in RODAS:
		for y in range(centro.y - RAIO_GIRO, centro.y + RAIO_GIRO + 1):
			for x in range(centro.x - RAIO_GIRO, centro.x + RAIO_GIRO + 1):
				var ponto := Vector2(x - centro.x, y - centro.y)
				if ponto.length_squared() > RAIO_GIRO * RAIO_GIRO:
					continue
				var amostra := Vector2i((Vector2(centro) + ponto.rotated(-angulo)).round())
				imagem.set_pixel(x, y, base.get_pixelv(amostra))
	return imagem

func _initialize() -> void:
	var somente_base := "--base" in OS.get_cmdline_user_args()
	var origem := Image.load_from_file(FONTE)
	if origem == null or origem.get_size() != Vector2i(1672, 941):
		push_error("Carroça: preservar a fonte gerada de 1672x941.")
		quit(1)
		return
	if not somente_base and not FileAccess.file_exists(INVERNO):
		push_error("Carroça: falta a fonte de inverno.")
		quit(1)
		return
	for estacao in ([0] if somente_base else [0, 1, 2, 3]):
		var fonte := Image.load_from_file(INVERNO) if estacao == 3 else origem
		var base := enquadrar(variante(fonte, estacao))
		base.save_png("res://assets/cenario/comercio/carroca_%s.png" % ESTACOES[estacao])
		var folha := Image.create(TELA.x * 2, TELA.y * 4, false, Image.FORMAT_RGBA8)
		for quadro in 8:
			folha.blit_rect(quadro_andando(base, quadro), Rect2i(Vector2i.ZERO, TELA), Vector2i(quadro % 2, quadro / 2) * TELA)
		folha.save_png("res://assets/cenario/comercio/carroca_andando_%s.png" % ESTACOES[estacao])
	print("Carroça: fonte em alta resolução, rodas independentes e estrutura rígida; estações preparadas: %d." % (1 if somente_base else 4))
	quit()
