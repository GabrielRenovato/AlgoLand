extends SceneTree

## Normaliza o enquadramento de cada folha e mantém todo pixel fora da boca idêntico.
const RAIZ := "res://arte/fontes/npcs/retratos/"
const DESTINO := "res://assets/npcs/retratos/"
const LADO := 128

func _initialize() -> void:
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"geracao.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	for nome in manifesto["personagens"]:
		var dados: Dictionary = manifesto["personagens"][nome]
		var origem := Image.load_from_file(RAIZ+dados["origem"])
		assert(origem != null)
		var largura := origem.get_width()/2
		var fechada := origem.get_region(Rect2i(0,0,largura,origem.get_height()))
		var falando := origem.get_region(Rect2i(largura,0,largura,origem.get_height()))
		fechada.resize(LADO,LADO,Image.INTERPOLATE_NEAREST)
		falando.resize(LADO,LADO,Image.INTERPOLATE_NEAREST)
		if dados.get("alfa_binario", false):
			for imagem in [fechada, falando]:
				for y in LADO:
					for x in LADO:
						var cor: Color = imagem.get_pixel(x,y)
						cor.a = 1.0 if cor.a >= 0.5 else 0.0
						imagem.set_pixel(x,y,cor)
		var boca: Array = dados["boca"]
		var recorte := Rect2i(boca[0],boca[1],boca[2],boca[3])
		var aberta := fechada.duplicate()
		aberta.blit_rect(falando,recorte,recorte.position)
		var folha := Image.create(LADO*2,LADO,false,Image.FORMAT_RGBA8)
		folha.blit_rect(fechada,Rect2i(0,0,LADO,LADO),Vector2i.ZERO)
		folha.blit_rect(aberta,Rect2i(0,0,LADO,LADO),Vector2i(LADO,0))
		assert(folha.save_png(DESTINO+nome+".png") == OK)
		print("Retrato pronto: ",nome)
	quit()
