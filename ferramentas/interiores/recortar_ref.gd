extends SceneTree

## Recorta trechos do "cozy furnishings sampler" do Mana Seed para servir de referência de estilo no PixelLab.
func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/cenario/Starter Pack/cozy furnishings sampler.png"))
	var pasta := ProjectSettings.globalize_path("res://arte/fontes/cenario/interiores/")
	img.get_region(Rect2i(112, 0, 48, 48)).save_png(pasta + "ref_mana_moveis_a.png")
	img.get_region(Rect2i(0, 0, 48, 48)).save_png(pasta + "ref_mana_moveis_b.png")
	img.get_region(Rect2i(48, 32, 48, 48)).save_png(pasta + "ref_mana_moveis_c.png")
	quit()
