extends SceneTree
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const Acabamento := preload("res://codigo/dados/acabamento_refinado.gd")

func _initialize() -> void:
	var destino := Aparencia.RAIZ_ROUPAS_REFINADAS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	var manifesto := {"grade":[8,8],"quadro":[128,128],"escala":0.5,"roupas":{},"fontes":{}}
	for indice in Aparencia.total_roupas():
		var id: String = Aparencia.roupas()[indice]["id"]
		for pagina in Padrao.CORPOS:
			var textura := Aparencia.roupa(indice,pagina,0)
			# As prévias completas de conjunto usam as quatro peças.
			var raiz := Aparencia.raiz_armadura_visual(indice)
			if not raiz.is_empty():
				textura = Aparencia.roupa(indice,pagina,15)
			var fonte := textura.resource_path
			var caminho := Aparencia.caminho_roupa_refinada(textura)
			if not manifesto["fontes"].has(fonte):
				var imagem: Image
				if not raiz.is_empty():
					imagem = Image.load_from_file(Acabamento.RAIZ+raiz.trim_suffix("/").get_file()+"/"+pagina+".png")
				else:
					imagem = Acabamento.refinar(textura.get_image(),id == "armadura_teste")
				if imagem == null or imagem.save_png(caminho) != OK:
					push_error("Não foi possível refinar: "+fonte)
					quit(1)
					return
				manifesto["fontes"][fonte] = caminho
			manifesto["roupas"][id+"/"+pagina] = {"indice":indice,"molde":fonte,"folha":caminho}
	var arquivo := FileAccess.open(destino+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t")+"\n")
	print("Roupas: %d, páginas cadastradas: %d, folhas distintas: %d" % [Aparencia.total_roupas(),manifesto["roupas"].size(),manifesto["fontes"].size()])
	quit()
