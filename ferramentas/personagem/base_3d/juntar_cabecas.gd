extends SceneTree
## Recorta cabeça e pescoço de uma folha 4x2 (células 640) nas direções 0,1,2,3 e amplia 4x.
func _initialize():
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[1])
	var final := Image.create(150*4, 150, false, Image.FORMAT_RGBA8)
	for c in 4:
		var parte := img.get_region(Rect2i(c*640+245, 165, 150, 150))
		final.blit_rect(parte, Rect2i(0, 0, 150, 150), Vector2i(c*150, 0))
	final.resize(final.get_width()*4, final.get_height()*4, Image.INTERPOLATE_LANCZOS)
	final.save_png(args[0])
	quit()
