extends SceneTree
## Fonte de verdade: corpo e camadas da arma originais, sem geração de poses.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var pasta := raiz.path_join("assets/personagens/craftpix_base_masculina/Sword_attack")
	var corpo := Image.load_from_file(pasta.path_join("Sword_attack3_body.png"))
	var cabeca := Image.load_from_file(pasta.path_join("Sword_attack5_head.png"))
	var tras := Image.load_from_file(pasta.path_join("Sword_attack2_sword_back.png"))
	var frente := Image.load_from_file(pasta.path_join("Sword_attack4_sword_front.png"))
	var guia := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	# Linha superior sem cabeça e sem efeitos permite ver mãos/oclusão.
	for i in 8:
		for linha in 2:
			for imagem in [tras, corpo]:
				guia.blend_rect(imagem, Rect2i(i * 64, 192, 64, 64), Vector2i(i * 64, linha * 64))
			if linha == 1:
				guia.blend_rect(cabeca, Rect2i(i * 64, 192, 64, 64), Vector2i(i * 64, linha * 64))
			guia.blend_rect(frente, Rect2i(i * 64, 192, 64, 64), Vector2i(i * 64, linha * 64))
	guia.resize(2048, 512, Image.INTERPOLATE_NEAREST)
	guia.save_png("/tmp/algoland-bracos-costas-original.png")
	quit()
