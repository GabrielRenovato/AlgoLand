extends SceneTree
## Gera a pele em pixel art do personagem 3D (atlas 64×64) a partir de pele_pixel_3d.gd.
## O PNG pode ser repintado à mão depois; rodar de novo sobrescreve.
func _initialize():
	var imagem: Image = preload("res://codigo/jogador/pele_pixel_3d.gd").pintar()
	var caminho: String = preload("res://codigo/jogador/pele_pixel_3d.gd").TEXTURA
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	assert(imagem.save_png(ProjectSettings.globalize_path(caminho)) == OK)
	print("PELE PIXEL: salva em ", caminho)
	quit()
