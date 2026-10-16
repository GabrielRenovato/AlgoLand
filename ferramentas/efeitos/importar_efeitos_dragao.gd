extends SceneTree

## Compila seis estados em folhas nativas, preservando a origem e a escala entre quadros.
const TAMANHOS := {"fogo": 192, "impacto": 176, "vento": 240, "meteoro": 64}
const PALETAS := {
	"meteoro": ["321822", "502034", "862334", "b9342b", "e4512d", "f47b32", "ffa744", "ffd36d", "fff0aa", "fffbdc"],
	"fogo": ["502034", "862334", "b9342b", "e4512d", "f47b32", "ffa744", "ffd36d", "fff0aa", "fffbdc"],
	"impacto": ["382c36", "55404a", "70594e", "927559", "b7956b", "d1b889", "ecdbb0", "675c6e", "938399", "beb1bb"],
	"vento": ["394354", "536779", "788f9a", "a0b6bd", "c4d6d7", "e5e9dc", "fff4d9", "8a817c", "b3a79a"]
}

func _initialize() -> void:
	for efeito in TAMANHOS:
		var fonte := Image.load_from_file("res://arte/fontes/efeitos/dragao/" + efeito + "_v1.png")
		if fonte == null or fonte.is_empty():
			push_error("Fonte ausente: " + efeito)
			quit(1)
			return
		var lado: int = TAMANHOS[efeito]
		var folha := Image.create(lado * 6, lado, false, Image.FORMAT_RGBA8)
		for i in 6:
			var coluna := i % 3
			var linha := i / 3
			var inicio := Vector2i(roundi(coluna * fonte.get_width() / 3.0), roundi(linha * fonte.get_height() / 2.0))
			var fim := Vector2i(roundi((coluna + 1) * fonte.get_width() / 3.0), roundi((linha + 1) * fonte.get_height() / 2.0))
			var quadro := fonte.get_region(Rect2i(inicio, fim - inicio))
			quadro.resize(lado, lado, Image.INTERPOLATE_NEAREST)
			for y in lado:
				for x in lado:
					var pixel := quadro.get_pixel(x, y)
					if pixel.a < 0.45:
						quadro.set_pixel(x, y, Color.TRANSPARENT)
						continue
					var melhor := Color.BLACK
					var menor := INF
					for html in PALETAS[efeito]:
						var cor := Color.html(html)
						var distancia := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
						if distancia < menor:
							menor = distancia
							melhor = cor
					quadro.set_pixel(x, y, melhor)
			folha.blit_rect(quadro, Rect2i(0, 0, lado, lado), Vector2i(i * lado, 0))
		folha.save_png("res://assets/efeitos/dragao/" + efeito + ".png")
		print("Efeito dragão: ", efeito, " ", folha.get_size())
	quit()
