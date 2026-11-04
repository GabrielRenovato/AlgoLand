extends SceneTree
func _initialize() -> void:
	var fontes := "res://arte/fontes/campanha/bacia_moinho/correcoes_2d/"
	var fichas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fontes+"registro.json"))
	var pasta := "res://assets/inimigos/bacia_moinho/ataques_corrigidos/"
	DirAccess.make_dir_recursive_absolute(pasta)
	for especie in fichas:
		var ficha: Dictionary = fichas[especie]
		var fonte := Image.load_from_file(fontes+"fontes/"+especie+".png")
		var atlas := Image.create(2048,1024,false,Image.FORMAT_RGBA8)
		for q in 8:
			var quad: Dictionary = ficha.quadros[q]
			var o: Array = quad.origem
			var d: Array = quad.destino
			# Cada recorte é isolado antes de posicionar, para não invadir o quadro vizinho.
			var celula := Image.create(512,512,false,Image.FORMAT_RGBA8)
			celula.blit_rect(fonte,Rect2i(int(o[0]),int(o[1]),int(o[2]),int(o[3])),Vector2i(int(d[0]),int(d[1])))
			atlas.blit_rect(celula,Rect2i(0,0,512,512),Vector2i(q%4*512,floori(float(q)/4.0)*512))
		atlas.save_png(pasta+especie+".png")
		print("ATLAS_2D ",especie)
	quit()
