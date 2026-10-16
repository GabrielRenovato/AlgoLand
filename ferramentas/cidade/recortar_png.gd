extends SceneTree

## Recorta um retângulo de uma imagem PNG. Uso: godot --headless --path . --script ferramentas/cidade/recortar_png.gd -- entrada saida x y largura altura
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.get_region(Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))).save_png(a[1])
	quit()
