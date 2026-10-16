extends SceneTree

const Aparencia := preload("res://codigo/dados/aparencia.gd")

func _initialize() -> void:
	var corpo: Image = load("res://assets/personagens/Body/body_1.png").get_image()
	var armadura: Image = load("res://assets/personagens/conjuntos/carrasco/andar.png").get_image()
	var roupas := [6, 29, 34]
	var atlas := Image.create(480, 400, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.html("29302c"))
	for i in roupas.size():
		var antiga: Image = Aparencia.roupa(roupas[i], "andar").get_image()
		var corrigida: Image = Aparencia.roupa(roupas[i], "andar", 15).get_image()
		# Frente durante a corrida: corpo e roupa são as mesmas poses usadas pelo jogador.
		var regiao := Rect2i(64 + 16, 256 + 4, 32, 48)
		for linha in 2:
			var imagem := corpo.get_region(regiao)
			if linha == 0:
				imagem.blend_rect(antiga.get_region(regiao), Rect2i(0, 0, 32, 48), Vector2i.ZERO)
				imagem.blend_rect(armadura.get_region(regiao), Rect2i(0, 0, 32, 48), Vector2i.ZERO)
			else:
				imagem.blend_rect(corrigida.get_region(regiao), Rect2i(0, 0, 32, 48), Vector2i.ZERO)
			imagem.resize(128, 192, Image.INTERPOLATE_NEAREST)
			atlas.blend_rect(imagem, Rect2i(0, 0, 128, 192), Vector2i(i * 160 + 16, linha * 200 + 4))
	atlas.save_png("res://arte/previas/armaduras/carrasco/previa_encaixe.png")
	print("Prévia: linha superior antes, inferior corrigida; três roupas de baixo diferentes.")
	quit()
