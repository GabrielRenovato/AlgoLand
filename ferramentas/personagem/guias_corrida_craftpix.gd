extends SceneTree
## Referências de movimento: cada direção conserva os oito quadros originais.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var fonte := Image.load_from_file(raiz.path_join("assets/personagens/craftpix_base_masculina/Unarmed_Run/Unarmed_Run_full.png"))
	for dados in [["frente", 0], ["direita", 2], ["costas", 3], ["esquerda", 1]]:
		var guia := fonte.get_region(Rect2i(0, int(dados[1]) * 64, fonte.get_width(), 64))
		guia.resize(guia.get_width() * 4, 256, Image.INTERPOLATE_NEAREST)
		guia.save_png("/tmp/algoland-guia-corrida-%s.png" % dados[0])
	quit()
