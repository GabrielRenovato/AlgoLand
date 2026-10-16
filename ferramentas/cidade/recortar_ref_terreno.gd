extends SceneTree

## Recorta tiles de referência do Mana Seed (Seasonal Forest, primavera) para servir de estilo no PixelLab:
## grama, terra (centro do caminho), pedra e água, cada um repetido em 2x2 (32x32), mais uma amostra de borda grama/terra.
func _init() -> void:
	var pasta := ProjectSettings.globalize_path("res://arte/fontes/cenario/terreno_mana/")
	for estacao in ["spring", "summer", "autumn", "winter"]:
		var folha := Image.load_from_file(ProjectSettings.globalize_path("res://assets/cenario/Seasonal Forest/arena/%s.png" % estacao))
		for par in [["ref_grama", Vector2i(0, 3)], ["ref_terra", Vector2i(4, 1)]]:
			var t: Vector2i = par[1]
			folha.get_region(Rect2i(t.x * 16, t.y * 16, 16, 16)).save_png(pasta + "%s_%s.png" % [par[0], estacao])
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/cenario/Seasonal Forest/arena/spring.png"))
	# Região maior da folha: caminho de terra com grama (esquerda, topo) e água (parte de baixo)
	img.get_region(Rect2i(0, 0, 48, 96)).save_png(pasta + "ref_caminho.png")
	img.get_region(Rect2i(0, 256, 128, 48)).save_png(pasta + "ref_agua.png")
	quit()
