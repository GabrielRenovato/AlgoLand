extends SceneTree

## Amplia uma imagem 4x com linhas de grade a cada 16 px originais (vermelhas a cada 64), para medir coordenadas.
## Uso: godot --headless --path . --script ferramentas/interiores/ampliar.gd -- entrada.png saida.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var fundo := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	fundo.fill(Color(0.8, 0.9, 0.8))
	fundo.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	fundo.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	for x in range(0, fundo.get_width(), 64):
		var cor := Color(1, 0, 0, 0.8) if (x / 4) % 64 == 0 else Color(0, 0, 1, 0.45)
		fundo.fill_rect(Rect2i(x, 0, 1, fundo.get_height()), cor)
	for y in range(0, fundo.get_height(), 64):
		var cor := Color(1, 0, 0, 0.8) if (y / 4) % 64 == 0 else Color(0, 0, 1, 0.45)
		fundo.fill_rect(Rect2i(0, y, fundo.get_width(), 1), cor)
	fundo.save_png(args[1])
	print("used ", img.get_used_rect())
	quit()
