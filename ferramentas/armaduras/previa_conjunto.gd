extends SceneTree

## Prévia das poses nativas compostas; não instancia a arena nem altera saves.
const Padrao := preload("res://Codigos/DadosLocais/padrao_armadura.gd")
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var config := Padrao.carregar(args[0])
	var raiz: String = config["destino"]
	var saida := raiz + "previas/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var paginas := Padrao.CORPOS.keys()
	var contato := Image.create(768, paginas.size() * 192, false, Image.FORMAT_RGBA8)
	contato.fill(Color.html("29312f"))
	for i in paginas.size():
		var pagina: String = paginas[i]
		var corpo: Image = load("res://CharacterSprites/" + Padrao.CORPOS[pagina]).get_image()
		if bool(config.get("substituir_cabeca", false)):
			corpo = Image.load_from_file(raiz + "corpo_sem_cabeca/" + pagina + ".png")
		var armadura := Image.load_from_file(raiz + pagina + ".png")
		if config.get("modo_visual", "armadura") == "tecido":
			# Cor de cabelo demonstrativa; a versão no jogo mantém a escolha do jogador.
			var cabelo := Aparencia.cabelo(0, pagina, -1, 0).get_image()
			var cartola := Image.load_from_file(raiz + "elmo/" + pagina + ".png")
			var limites := {}
			for linha in 8:
				for coluna in 8:
					var origem := Vector2i(coluna * 64, linha * 64)
					limites[origem] = Aparencia.limites_cabelo_cartola(cartola.get_region(Rect2i(origem, Vector2i(64, 64))))
			corpo = corpo.duplicate()
			for y in 512:
				for x in 512:
					var pixel := cabelo.get_pixel(x, y)
					var origem := Vector2i((x / 64) * 64, (y / 64) * 64)
					if pixel.a > 0.5 and y - origem.y >= int(limites[origem][x - origem.x]) and cartola.get_pixel(x, y).a < 0.5:
						corpo.set_pixel(x, y, Color(pixel.r * 0.65, pixel.g * 0.35, pixel.b * 0.16, pixel.a))
		for direcao in 4:
			var origem := Vector2i(0, direcao * 64)
			var quadro := _quadro(corpo, armadura, origem)
			quadro.resize(192, 192, Image.INTERPOLATE_NEAREST)
			contato.blend_rect(quadro, Rect2i(0, 0, 192, 192), Vector2i(direcao * 192, i * 192))
		for f in 8:
			var animado := Image.create(256, 64, false, Image.FORMAT_RGBA8)
			animado.fill(Color.html("29312f"))
			for direcao in 4:
				var linha := direcao + (4 if pagina == "andar" else 0)
				var quadro := _quadro(corpo, armadura, Vector2i(f * 64, linha * 64))
				animado.blend_rect(quadro, Rect2i(0, 0, 64, 64), Vector2i(direcao * 64, 0))
			if pagina == "andar" and f < 6:
				var detalhe := Image.create(128, 48, false, Image.FORMAT_RGBA8)
				for direcao in 4:
					detalhe.blit_rect(animado, Rect2i(direcao * 64 + 16, 4, 32, 48), Vector2i(direcao * 32, 0))
				detalhe.resize(768, 288, Image.INTERPOLATE_NEAREST)
				detalhe.save_png(saida + "caminhada_detalhe_%d.png" % f)
			animado.resize(768, 192, Image.INTERPOLATE_NEAREST)
			animado.save_png(saida + "%s_%d.png" % [pagina, f])
	contato.save_png(saida + "poses.png")
	print("Prévia: ", saida)
	quit()

func _quadro(corpo: Image, armadura: Image, origem: Vector2i) -> Image:
	var imagem := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	imagem.fill(Color.html("29312f"))
	var regiao := Rect2i(origem, Vector2i(64, 64))
	imagem.blend_rect(corpo, regiao, Vector2i.ZERO)
	imagem.blend_rect(armadura, regiao, Vector2i.ZERO)
	return imagem
