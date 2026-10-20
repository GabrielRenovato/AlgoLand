extends SceneTree
## Comparação temporal: original intacto à esquerda, estudo à direita.
func _initialize() -> void:
	var raiz := OS.get_cmdline_user_args()[0]
	var costas := OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "costas"
	var linha := 3 if costas else 2
	var fonte := Image.load_from_file(raiz.path_join("assets/personagens/craftpix_base_masculina/Sword_attack/Sword_attack_full.png"))
	var versao := OS.get_cmdline_user_args()[2] if OS.get_cmdline_user_args().size() > 2 else "v2"
	var pasta := raiz.path_join("arte/previas/personagens/base_vila_estudo/comparacao_espada_costas_" + versao if costas else "arte/previas/personagens/base_vila_estudo/comparacao_espada")
	DirAccess.make_dir_recursive_absolute(pasta)
	var fundo := Color("20252d")
	for i in 8:
		var original := fonte.get_region(Rect2i(i * 64, linha * 64, 64, 64))
		# Mesmo tamanho aparente do corpo (22px ->33px) da base de estudo31px.
		original.resize(96, 96, Image.INTERPOLATE_NEAREST)
		var caminho_estudo := "arte/previas/personagens/base_vila_estudo/espada_quatro_direcoes/costas_%d.png" % i if costas else "arte/previas/personagens/base_vila_estudo/espada_direita/quadro_%d.png" % i
		var estudo := Image.load_from_file(raiz.path_join(caminho_estudo))
		estudo.resize(96, 96, Image.INTERPOLATE_NEAREST)
		var quadro := Image.create(128, 96, false, Image.FORMAT_RGBA8)
		quadro.fill(fundo)
		# Pivô do original(32,44) fica em(48,66); chão comum y72.
		quadro.blend_rect(original, Rect2i(Vector2i.ZERO, original.get_size()), Vector2i(16, 6))
		quadro.resize(384, 288, Image.INTERPOLATE_NEAREST)
		quadro.save_png(pasta.path_join("original_%d.png" % i))
		var par := Image.create(256, 96, false, Image.FORMAT_RGBA8)
		par.fill(fundo)
		original.resize(96, 96, Image.INTERPOLATE_NEAREST)
		par.blend_rect(original, Rect2i(Vector2i.ZERO, original.get_size()), Vector2i(16, 6))
		# Estudo exportado tem raiz x128 e chão190, ambos transformados por0.375.
		par.blend_rect(estudo, Rect2i(Vector2i.ZERO, estudo.get_size()), Vector2i(144, 1))
		par.resize(768, 288, Image.INTERPOLATE_NEAREST)
		par.save_png(pasta.path_join("par_%d.png" % i))
	print("Comparação: original linha", linha, ", quadros0..7; mesma sequência e durações.")
	quit()
