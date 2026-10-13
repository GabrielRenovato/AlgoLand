extends SceneTree

const NOMES := ["investida", "pisao", "machado", "furia"]
const LADO := 128
const PALETA := ["28242d", "4e3735", "705344", "987351", "c09766", "e3c28c", "fff0bd", "727681", "b7b9bd", "914133", "c76a3a", "efae57"]

func _initialize() -> void:
	var fonte := Image.load_from_file("res://Efeitos/minotauro/fontes/ataques_v1.png")
	if fonte == null or fonte.is_empty():
		quit(1)
		return
	for linha in 4:
		var folha := Image.create(LADO * 6, LADO, false, Image.FORMAT_RGBA8)
		for coluna in 6:
			var inicio := Vector2i(roundi(coluna * fonte.get_width() / 6.0), roundi(linha * fonte.get_height() / 4.0))
			var fim := Vector2i(roundi((coluna + 1) * fonte.get_width() / 6.0), roundi((linha + 1) * fonte.get_height() / 4.0))
			var quadro := fonte.get_region(Rect2i(inicio, fim - inicio))
			quadro.resize(LADO, LADO, Image.INTERPOLATE_NEAREST)
			for y in LADO:
				for x in LADO:
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
			folha.blit_rect(quadro, Rect2i(0, 0, LADO, LADO), Vector2i(coluna * LADO, 0))
		folha.save_png("res://Efeitos/minotauro/" + NOMES[linha] + ".png")
	quit()
