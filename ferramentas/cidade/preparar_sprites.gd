extends SceneTree

## Copia as imagens originais sem reduzir nem alterar pixels ou transparência.
## A geometria permite ao Godot recortar a margem e ajustar apenas a escala de exibição.
const IDS := ["venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]

func _initialize() -> void:
	var destino := "res://assets/cenario/cidade/casas"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	var geometria := {}
	for id in IDS:
		var fonte := "res://arte/fontes/cidade/%s.png" % id
		var imagem := Image.load_from_file(fonte)
		if imagem == null or imagem.is_empty():
			push_error("Fonte ausente: " + fonte)
			quit(1)
			return
		var arquivo := FileAccess.open(destino.path_join(id + ".png"), FileAccess.WRITE)
		if arquivo == null:
			push_error("Falha ao copiar sprite: " + id)
			quit(1)
			return
		arquivo.store_buffer(FileAccess.get_file_as_bytes(fonte))
		arquivo.close()
		var area := _area_visivel(imagem)
		geometria[id] = {"regiao": [area.position.x, area.position.y, area.size.x, area.size.y],
			"escala": 112.0 / maxi(area.size.x, area.size.y), "resolucao_original": [imagem.get_width(), imagem.get_height()]}
		print("original preservado: ", id, " ", imagem.get_size())
	var manifesto := FileAccess.open(destino.path_join("geometria.json"), FileAccess.WRITE)
	manifesto.store_string(JSON.stringify(geometria, "\t"))
	quit()

## Mede somente a arte visível; pixels quase invisíveis não deslocam a soleira.
func _area_visivel(imagem: Image) -> Rect2i:
	var minimo := Vector2i(imagem.get_width(), imagem.get_height())
	var maximo := Vector2i(-1, -1)
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x, y).a >= 0.25:
				minimo.x = mini(minimo.x, x)
				minimo.y = mini(minimo.y, y)
				maximo.x = maxi(maximo.x, x)
				maximo.y = maxi(maximo.y, y)
	return Rect2i(minimo, maximo - minimo + Vector2i.ONE)
