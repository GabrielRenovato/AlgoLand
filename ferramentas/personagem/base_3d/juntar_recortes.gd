extends SceneTree
## Junta recortes (frente e perfil) de várias folhas 4x2 de 640px para comparar lado a lado.
func _initialize():
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var arquivos := args.slice(1)
	var final := Image.create(180*2, 290*arquivos.size(), false, Image.FORMAT_RGBA8)
	for i in arquivos.size():
		var img := Image.load_from_file(arquivos[i])
		for c in 2:
			var d: int = [0, 2][c]
			var parte := img.get_region(Rect2i((d%4)*640+228, (d/4)*640+168, 180, 290))
			final.blit_rect(parte, Rect2i(0, 0, 180, 290), Vector2i(c*180, i*290))
	final.resize(final.get_width()*3, final.get_height()*3, Image.INTERPOLATE_NEAREST)
	final.save_png(saida)
	quit()
