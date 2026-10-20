extends SceneTree
## Recorta a direção original sem redesenhar nenhuma pose.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var fonte := Image.load_from_file(raiz.path_join("assets/personagens/craftpix_base_masculina/Sword_attack/Sword_attack_full.png"))
	var guia := fonte.get_region(Rect2i(0, 128, fonte.get_width(), 64))
	guia.resize(guia.get_width() * 4, 256, Image.INTERPOLATE_NEAREST)
	guia.save_png("/tmp/algoland-guia-espada-direita.png")
	for dados in [["frente", 0], ["esquerda", 1], ["costas", 3]]:
		var linha := fonte.get_region(Rect2i(0, int(dados[1]) * 64, fonte.get_width(), 64))
		linha.resize(linha.get_width() * 4, 256, Image.INTERPOLATE_NEAREST)
		linha.save_png("/tmp/algoland-guia-espada-%s.png" % dados[0])
	quit()
