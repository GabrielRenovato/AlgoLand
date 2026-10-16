extends SceneTree

const NOMES := ["porretada", "varrida", "salto", "furia", "execucao"]
const LADO := 128

func _initialize() -> void:
	var fonte := Image.load_from_file("res://arte/fontes/efeitos/goblin_maromba/ataques_v1.png")
	if fonte == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/efeitos/goblin_maromba"))
	_importar(fonte, NOMES)
	print("Goblin: cinco efeitos separados")
	quit()

func _importar(fonte: Image, nomes: Array) -> void:
	for linha in nomes.size():
		var lado := 256 if nomes[linha] == "execucao" else LADO
		var folha := Image.create(lado * 6, lado, false, Image.FORMAT_RGBA8)
		for coluna in 6:
			var inicio := Vector2i(roundi(coluna * fonte.get_width() / 6.0), roundi(linha * fonte.get_height() / float(nomes.size())))
			var fim := Vector2i(roundi((coluna + 1) * fonte.get_width() / 6.0), roundi((linha + 1) * fonte.get_height() / float(nomes.size())))
			var quadro := fonte.get_region(Rect2i(inicio, fim - inicio))
			quadro.convert(Image.FORMAT_RGBA8)
			quadro.resize(lado, lado, Image.INTERPOLATE_NEAREST)
			for y in lado:
				for x in lado:
					var pixel := quadro.get_pixel(x, y)
					pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
					quadro.set_pixel(x, y, pixel if pixel.a > 0 else Color.TRANSPARENT)
			folha.blit_rect(quadro, Rect2i(0, 0, lado, lado), Vector2i(coluna * lado, 0))
		folha.save_png("res://assets/efeitos/goblin_maromba/" + nomes[linha] + ".png")
