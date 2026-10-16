extends SceneTree

## Mede as imagens dos interiores: retângulo com pixels de cada móvel (para ancorar na base) e as bordas das salas.
## Uso: godot --headless --path . --script ferramentas/interiores/medir.gd
const RAIZ := "res://assets/cenario/cidade/interiores/"

func _init() -> void:
	var saida := {}
	for casa in DirAccess.get_directories_at(RAIZ):
		var itens := {}
		for arq in DirAccess.get_files_at(RAIZ + casa + "/props"):
			if not arq.ends_with(".png"):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(RAIZ + casa + "/props/" + arq))
			var u := img.get_used_rect()
			itens[arq.get_basename()] = [img.get_width(), img.get_height(), u.position.x, u.position.y, u.size.x, u.size.y]
		var sala := Image.load_from_file(ProjectSettings.globalize_path(RAIZ + casa + "/sala.png"))
		saida[casa] = {"props": itens, "sala_usada": str(sala.get_used_rect()), "canto": str(sala.get_pixel(0, 0)), "baixo": str(sala.get_pixel(128, 223)), "cima": str(sala.get_pixel(128, 0))}
	print(JSON.stringify(saida, "  "))
	quit()
