extends SceneTree

## A segunda imagem escolhida pelo usuário é a própria textura, sem redesenho ou redução.
const FONTE := "res://arte/fontes/comercio/cavalo_estudo_v2.png"
const PIXELS_POR_UNIDADE := 22
const TELA := Vector2i(2112, 1408) # 96x64 unidades de jogo.
const ORIGEM := Vector2i(462, 160)
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const COURO_SAZONAL := [Vector3.ONE, Vector3(1.08, 1.10, 1.08), Vector3(0.91, 0.85, 0.85), Vector3(0.78, 0.72, 0.82)]

static func variante(origem: Image, estacao: int) -> Image:
	var imagem := origem.duplicate() as Image
	if estacao == 0:
		return imagem
	var fator: Vector3 = COURO_SAZONAL[estacao]
	for y in imagem.get_height():
		for x in imagem.get_width():
			var pixel := imagem.get_pixel(x, y)
			# Apenas os marrons do couro: preservar pelagem, crina e latão.
			if pixel.a == 0 or pixel.r >= 0.80 or pixel.r <= pixel.g * 1.20 or pixel.g <= pixel.b * 1.15:
				continue
			imagem.set_pixel(x, y, Color(pixel.r * fator.x, pixel.g * fator.y, pixel.b * fator.z, pixel.a))
	return imagem

static func enquadrar(origem: Image) -> Image:
	var tela := Image.create(TELA.x, TELA.y, false, Image.FORMAT_RGBA8)
	tela.blit_rect(origem, Rect2i(Vector2i.ZERO, origem.get_size()), ORIGEM)
	return tela

func _initialize() -> void:
	var origem := Image.load_from_file(FONTE)
	if origem == null or origem.get_size() != Vector2i(1484, 1060):
		push_error("Cavalo: preservar a segunda imagem original de 1484x1060.")
		quit(1)
		return
	for estacao in 4:
		var tela := enquadrar(variante(origem, estacao))
		tela.save_png("res://assets/cenario/comercio/cavalo_%s.png" % ESTACOES[estacao])
	print("Cavalo: imagem original preservada em quatro telas 2112x1408; escala no motor 1/22.")
	quit()
