extends SceneTree
## Escala comum por direção; registra a cabeça no eixo X, preservando o salto em Y.
const NOMES := ["frente", "direita", "costas", "esquerda"]
const ALTURAS := [261.0, 224.0, 225.0, 251.0]
const BASES := [517, 487, 481, 513]

func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var fontes := raiz.path_join("arte/fontes/personagens/base_vila_estudo")
	var saida := raiz.path_join("arte/previas/personagens/base_vila_estudo/corrida_quatro_direcoes")
	DirAccess.make_dir_recursive_absolute(saida)
	var folha := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var contato := Image.create(1536, 768, false, Image.FORMAT_RGBA8)
	var conjuntos: Array[Image] = []
	for i in 8:
		conjuntos.append(Image.create(768, 192, false, Image.FORMAT_RGBA8))
	for direcao in 4:
		var original := Image.load_from_file(fontes.path_join("corrida-%s-v1-original.png" % NOMES[direcao]))
		original.convert(Image.FORMAT_RGBA8)
		for y in original.get_height():
			for x in original.get_width():
				var cor := original.get_pixel(x, y)
				cor.a = 1.0 if cor.a >= 0.5 else 0.0
				original.set_pixel(x, y, cor)
		var escala: float = 31.0 / ALTURAS[direcao]
		for indice in 8:
			var inicio := original.get_width() * indice / 8
			var fim := original.get_width() * (indice + 1) / 8
			var quadro := original.get_region(Rect2i(inicio, 0, fim - inicio, original.get_height()))
			var area := quadro.get_used_rect()
			# Eixo da cabeça, medido acima dos braços; o contorno dos pés não define a raiz.
			var minimo := quadro.get_width()
			var maximo := 0
			for y in range(area.position.y + 30, area.position.y + 60):
				for x in quadro.get_width():
					var cor := quadro.get_pixel(x, y)
					if cor.a > 0.5 and cor.r > cor.g * 1.10 and cor.r > 0.35:
						minimo = mini(minimo, x)
						maximo = maxi(maximo, x)
			assert(maximo > minimo)
			var eixo := (minimo + maximo) / 2.0
			var recorte := quadro.get_region(area)
			recorte.resize(roundi(area.size.x * escala), roundi(area.size.y * escala), Image.INTERPOLATE_NEAREST)
			var destino := Vector2i(roundi(32 + (area.position.x - eixo) * escala), roundi(44 + (area.position.y - BASES[direcao]) * escala))
			assert(destino.x >= 0 and destino.y >= 0 and destino.x + recorte.get_width() <= 64 and destino.y + recorte.get_height() <= 64)
			var celula := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			celula.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), destino)
			folha.blit_rect(celula, Rect2i(0, 0, 64, 64), Vector2i(indice * 64, direcao * 64))
			celula.resize(192, 192, Image.INTERPOLATE_NEAREST)
			celula.save_png(saida.path_join("%s_%d.png" % [NOMES[direcao], indice]))
			contato.blit_rect(celula, Rect2i(0, 0, 192, 192), Vector2i(indice * 192, direcao * 192))
			conjuntos[indice].blit_rect(celula, Rect2i(0, 0, 192, 192), Vector2i(direcao * 192, 0))
	folha.save_png(fontes.path_join("corrida-v1-64.png"))
	contato.save_png(saida.path_join("contato.png"))
	for i in 8:
		conjuntos[i].save_png(saida.path_join("conjunto_%d.png" % i))
	print("Corrida: 32 quadros; células 64; oito quadros por direção; 100 ms por quadro.")
	quit()
