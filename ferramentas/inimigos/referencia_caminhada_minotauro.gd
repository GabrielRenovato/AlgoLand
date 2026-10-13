extends SceneTree

func _initialize() -> void:
	var corpo := Image.load_from_file("res://CharacterSprites/Body/body_1.png")
	var referencia := Image.create(1536, 1024, false, Image.FORMAT_RGBA8)
	for linha in 4:
		for quadro in 6:
			var pose := corpo.get_region(Rect2i(quadro * 64 + 16, (linha + 4) * 64 + 8, 32, 40))
			pose.resize(192, 240, Image.INTERPOLATE_NEAREST)
			referencia.blit_rect(pose, Rect2i(0, 0, 192, 240), Vector2i(quadro * 256 + 32, linha * 256 + 8))
	referencia.save_png("res://inimigos/minotauro/fontes/referencia_passos_mana_seed.png")
	quit()
