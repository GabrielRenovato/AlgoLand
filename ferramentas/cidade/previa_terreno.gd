extends SceneTree

## Prévia de todos os tilesets do terreno: uma linha por estação, com os quatro pares lado a lado (grama/terra, grama/pedra,
## terra/pedra e grama/água no quadro 0), ampliada 3x. Saída: arte/previas/cenario/tilesets_estacoes.png
func _init() -> void:
	var estacoes := ["primavera", "verao", "outono", "inverno"]
	var pares := ["grama_terra", "grama_pedra", "terra_pedra", "grama_agua_0"]
	var folha := Image.create(4 * 64 + 3 * 4, 4 * 96 + 3 * 4, false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.12, 0.1, 0.14))
	for e in estacoes.size():
		for p in pares.size():
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/cenario/cidade/terreno/%s/%s.png" % [estacoes[e], pares[p]]))
			folha.blit_rect(img, Rect2i(0, 0, 64, 96), Vector2i(p * 68, e * 100))
	folha.resize(folha.get_width() * 3, folha.get_height() * 3, Image.INTERPOLATE_NEAREST)
	folha.save_png(ProjectSettings.globalize_path("res://arte/previas/cenario/tilesets_estacoes.png"))
	quit()
