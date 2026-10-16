extends SceneTree
const Objetos := preload("res://codigo/dados/objetos_refinados.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Acabamento := preload("res://codigo/dados/acabamento_refinado.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Objetos.RAIZ))
	var fontes := {}
	var catalogo := Equipamentos.new()
	for id in Equipamentos.FAMILIAS:
		for nivel in catalogo.armas[id]["niveis"]:
			var dados: Dictionary = catalogo.armas[id]["niveis"][nivel]
			for campo in ["textura","textura_ataque","textura_carregando"]:
				if dados.get(campo) is Texture2D:
					fontes[dados[campo].resource_path] = true
	for pasta in ["um_mao","lanca","arco"]:
		var raiz: String = "res://assets/personagens/Reacao/"+pasta+"/"
		for nome in DirAccess.get_files_at(raiz):
			if nome.ends_with(".png") and (nome.begins_with("arma_") or nome.begins_with("escudo_") or nome == "aljava.png"):
				fontes[raiz+nome] = true
	for arquivo in ["Fazenda/ferramenta_fazenda.png","Fazenda/ferramenta_machado.png","Fazenda/ferramenta_picareta.png","body_smithing/hammer/char_a_p4_6tla_smth_v01.png","Arco/aljava_p2.png","Arco/aljava_p3.png","Arco/carregando/aljava.png","Arco/flecha.png"]:
		fontes["res://assets/personagens/"+arquivo] = true
	var manifesto := {}
	for fonte in fontes:
		var nativa: Texture2D = load(fonte)
		var imagem := Acabamento.refinar(nativa.get_image(),true,true)
		var destino := Objetos.caminho(nativa)
		if imagem.save_png(destino) != OK:
			quit(1)
			return
		manifesto[fonte] = {"folha":destino,"tamanho_nativo":[nativa.get_width(),nativa.get_height()],"escala":0.5,"grade":[8,8] if nativa.get_width() == 512 else [1,1]}
	catalogo.free()
	var arquivo := FileAccess.open(Objetos.RAIZ+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t")+"\n")
	print("Armas e ferramentas refinadas: ",manifesto.size()," folhas")
	quit()
