extends SceneTree

## Converte a arte de seis estados para folhas nativas sem mipmaps ou suavização.
const PALETA := ["123d50", "1c6278", "268ba7", "3cb6d0", "64d5e2", "a4eaf0", "d8f7fa", "ffffff"]

func _initialize() -> void:
	var fonte := Image.load_from_file("res://assets/efeitos/congelamento/conceito_v1.png")
	var vistas: Array[Image] = []
	var recorte := Rect2i()
	for i in 6:
		var inicio := roundi(i * fonte.get_width() / 6.0)
		var fim := roundi((i + 1) * fonte.get_width() / 6.0)
		var vista := fonte.get_region(Rect2i(inicio, 0, fim - inicio, fonte.get_height()))
		for y in vista.get_height():
			for x in vista.get_width():
				if vista.get_pixel(x, y).a < 0.3:
					vista.set_pixel(x, y, Color.TRANSPARENT)
		var area := vista.get_used_rect()
		recorte = area if i == 0 else recorte.merge(area)
		vistas.append(vista)
	var tamanhos := {"pequeno": Vector2i(24, 24), "normal": Vector2i(32, 40), "grande": Vector2i(64, 64), "gigante": Vector2i(128, 128)}
	for variante in tamanhos:
		var tamanho: Vector2i = tamanhos[variante]
		var folha := Image.create(tamanho.x * 6, tamanho.y, false, Image.FORMAT_RGBA8)
		for i in 6:
			var quadro := vistas[i].get_region(recorte)
			quadro.resize(tamanho.x - 2, tamanho.y - 2, Image.INTERPOLATE_NEAREST)
			for y in quadro.get_height():
				for x in quadro.get_width():
					var pixel := quadro.get_pixel(x, y)
					if pixel.a < 0.3:
						quadro.set_pixel(x, y, Color.TRANSPARENT)
						continue
					var melhor := Color.BLACK
					var distancia := INF
					for html in PALETA:
						var cor := Color.html(html)
						var d := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
						if d < distancia:
							distancia = d
							melhor = cor
					# A janela frontal deixa o inimigo visível; contorno e brilhos são sólidos.
					var janela := i in [2, 3, 4] and x > quadro.get_width() * 0.23 and x < quadro.get_width() * 0.77 and y > quadro.get_height() * 0.3 and y < quadro.get_height() * 0.9
					melhor.a = 0.3 if janela and melhor.r < 0.65 and melhor.g > 0.4 else 1.0
					quadro.set_pixel(x, y, melhor)
			folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i(i * tamanho.x + 1, 1))
		folha.save_png("res://assets/efeitos/congelamento/" + variante + ".png")
		print("Gelo: ", variante, " ", folha.get_size())
	quit()
