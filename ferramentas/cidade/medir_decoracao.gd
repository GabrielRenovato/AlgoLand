extends SceneTree

## Mede o retângulo com pixels de cada imagem de assets/cenario/cidade/decoracao/<categoria>/ (se for folha animada, vale o
## conjunto de quadros: use a medida da imagem estática). Saída em JSON: nome -> [largura, altura, x, y, w, h].
## Uso: godot --headless --path . --script ferramentas/cidade/medir_decoracao.gd > medidas_decoracao.json (só a linha do JSON)
const RAIZ := "res://assets/cenario/cidade/decoracao/"

func _init() -> void:
	var saida := {}
	for pasta in DirAccess.get_directories_at(RAIZ):
		for arq in DirAccess.get_files_at(RAIZ + pasta):
			if not arq.ends_with(".png"):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(RAIZ + pasta + "/" + arq))
			var u := img.get_used_rect()
			saida[arq.get_basename()] = [img.get_width(), img.get_height(), u.position.x, u.position.y, u.size.x, u.size.y]
	print("JSON:", JSON.stringify(saida))
	quit()
