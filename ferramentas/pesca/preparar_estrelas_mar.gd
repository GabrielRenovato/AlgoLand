extends SceneTree

## Converte os quatro quadros da fonte em sprites nativos com a mesma tela e grade.
const NOMES := ["primavera","verao","outono","inverno"]
func _initialize() -> void:
	var fonte := Image.load_from_file("res://arte/fontes/praia/estrelas_mar/atlas_gerado.png")
	if fonte == null:
		quit(1)
		return
	for i in 4:
		var inicio := Vector2i((i%2)*fonte.get_width()/2,(i/2)*fonte.get_height()/2)
		var fim := Vector2i(((i%2)+1)*fonte.get_width()/2,((i/2)+1)*fonte.get_height()/2)
		var quadro := fonte.get_region(Rect2i(inicio,fim-inicio))
		quadro.resize(32,32,Image.INTERPOLATE_NEAREST)
		var erro := quadro.save_png("res://assets/cenario/praia/estrelas_mar/"+NOMES[i]+".png")
		if erro != OK:
			quit(1)
			return
	print("Estrelas-do-mar: quatro quadros nativos de 32x32, margens comuns e filtro vizinho mais proximo.")
	quit()
