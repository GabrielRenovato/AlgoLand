extends SceneTree

## Junta várias imagens lado a lado sobre fundo verde-acinzentado, ampliadas 3x, para conferir recortes.
## Uso: godot --headless --path . --script ferramentas/cidade/folha_previa.gd -- <saida.png> <imagem>...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var imgs: Array[Image] = []
	var largura := 0
	var altura := 0
	for i in range(1, a.size()):
		var img := Image.load_from_file(a[i])
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		largura += img.get_width() + 4
		altura = maxi(altura, img.get_height())
	var folha := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.45, 0.55, 0.4))
	var x := 0
	for img in imgs:
		folha.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		x += img.get_width() + 4
	folha.resize(folha.get_width() * 3, folha.get_height() * 3, Image.INTERPOLATE_NEAREST)
	folha.save_png(a[0])
	quit()
