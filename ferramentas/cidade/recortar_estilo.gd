extends SceneTree

## Recorta trechos da imagem de referência do estilo novo (arte/fontes/cenario/estilo_ref/referencia.webp) para usar como
## style_image no PixelLab. Uso: godot --headless --path . --script ferramentas/cidade/recortar_estilo.gd -- nome x y largura altura [...]
func _init() -> void:
	var pasta := ProjectSettings.globalize_path("res://arte/fontes/cenario/estilo_ref/")
	var img := Image.new()
	img.load_webp_from_buffer(FileAccess.get_file_as_bytes(pasta + "referencia.webp"))
	img.convert(Image.FORMAT_RGBA8)
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		img.save_png(pasta + "referencia.png")
	var i := 0
	while i + 4 < args.size():
		img.get_region(Rect2i(int(args[i + 1]), int(args[i + 2]), int(args[i + 3]), int(args[i + 4]))).save_png(pasta + args[i] + ".png")
		i += 5
	print("tamanho ", img.get_size())
	quit()
