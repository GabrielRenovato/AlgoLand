extends SceneTree

## Gera as quatro versões de estação de um detalhe de chão (mancha de grama, tufo, terra...) tingindo a imagem com a cor do
## terreno de cada estação (a mesma PALETA_ACONCHEGO do chão, em recolorir_wang.gd), com o mesmo brilho relativo de cada pixel.
## Assim o detalhe combina com a grama ou a terra embaixo dele em qualquer estação.
## Uso: godot --headless --path . --script ferramentas/cidade/tingir_sazonal.gd -- <entrada.png> <pasta_saida> <nome> <grama|terra>
const PALETA := {
	"primavera": {"grama": "7fa24a", "terra": "a07850"},
	"verao": {"grama": "5e8f3c", "terra": "b08a5c"},
	"outono": {"grama": "a9953f", "terra": "9a6a42"},
	"inverno": {"grama": "e6eef0", "terra": "8a6e5a"},
}

func _brilho(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var soma := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				soma += _brilho(c)
				n += 1
	var media := soma / maxf(n, 1)
	for estacao in PALETA:
		var cor := Color(PALETA[estacao][a[3]])
		var saida := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var fator := pow(_brilho(c) / maxf(media, 0.01), 0.9)
				saida.set_pixel(x, y, Color(clampf(cor.r * fator, 0, 1), clampf(cor.g * fator, 0, 1), clampf(cor.b * fator, 0, 1), c.a))
		saida.save_png(a[1].path_join("%s_%s.png" % [a[2], estacao]))
	print("ok ", a[2])
	quit()
