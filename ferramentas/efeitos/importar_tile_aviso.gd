extends SceneTree

func _initialize() -> void:
	var imagem := Image.load_from_file("res://arte/fontes/efeitos/avisos/perigo_v1.png")
	imagem.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var paleta := ["451826", "79232b", "b13a2c", "e16932", "eeb552", "fff0a0"]
	for y in 64:
		for x in 64:
			var pixel := imagem.get_pixel(x, y)
			if pixel.a < 0.5:
				imagem.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var menor := INF
			var melhor := Color.BLACK
			for html in paleta:
				var cor := Color.html(html)
				var distancia := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
				if distancia < menor:
					menor = distancia
					melhor = cor
			imagem.set_pixel(x, y, melhor)
	imagem.save_png("res://assets/efeitos/avisos/perigo.png")
	quit()
