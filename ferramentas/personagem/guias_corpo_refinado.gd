extends SceneTree

const Padrao := preload("res://codigo/dados/padrao_armadura.gd")

func _initialize() -> void:
	for pagina in Padrao.CORPOS:
		var imagem := Image.load_from_file("res://arte/fontes/personagens/prototipo/base_mana_seed/%s.png" % pagina)
		imagem.convert(Image.FORMAT_RGBA8)
		for y in imagem.get_height():
			for x in imagem.get_width():
				var cor := imagem.get_pixel(x,y)
				if cor.a >= 0.5:
					imagem.set_pixel(x,y,Color("a8a9b3"))
				else:
					imagem.set_pixel(x,y,Color.TRANSPARENT)
		imagem.resize(1024,1024,Image.INTERPOLATE_NEAREST)
		imagem.save_png("res://arte/fontes/personagens/refinado/guia_%s.png" % pagina)
	quit()
