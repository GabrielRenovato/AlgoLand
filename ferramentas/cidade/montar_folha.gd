extends SceneTree

## Junta quadros frame_0.png, frame_1.png... de uma pasta em uma folha horizontal (um quadro ao lado do outro).
## Uso: godot --headless --path . --script ferramentas/cidade/montar_folha.gd -- <pasta_dos_quadros> <saida.png>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var quadros: Array[Image] = []
	var i := 0
	while FileAccess.file_exists(args[0].path_join("frame_%d.png" % i)):
		var caminho: String = args[0].path_join("frame_%d.png" % i)
		var img := Image.load_from_file(caminho)
		if img == null:
			img = Image.new()
			if img.load_png_from_buffer(FileAccess.get_file_as_bytes(caminho)) != OK:
				push_error("Não leu " + caminho)
				quit(1)
				return
		img.convert(Image.FORMAT_RGBA8)
		quadros.append(img)
		i += 1
	var l := quadros[0].get_width()
	var a := quadros[0].get_height()
	var folha := Image.create(l * quadros.size(), a, false, Image.FORMAT_RGBA8)
	for n in quadros.size():
		folha.blit_rect(quadros[n], Rect2i(0, 0, l, a), Vector2i(n * l, 0))
	folha.save_png(args[1])
	print("quadros ", quadros.size(), " de ", l, "x", a)
	quit()
