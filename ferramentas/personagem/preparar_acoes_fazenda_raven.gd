extends SceneTree
const Encaixe=preload("res://ferramentas/personagem/encaixe_acoes_fazenda_raven.gd")
func _initialize():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	var guias=Encaixe.carregar_guias()
	var acoes=JSON.parse_string(FileAccess.get_file_as_string(Encaixe.RAIZ+"camadas/acoes.json"))
	var fontes={}
	var nomes=["calca_marrom","calca_jeans","camisa_azul","camisa_verde","botas","luvas","capa","aljava"]
	for i in 28:nomes.append("cabelo_%d"%(i+1))
	for nome in nomes:
		fontes[nome]=Image.load_from_file(Encaixe.RAIZ+"camadas/"+nome+".png").get_region(Rect2i(0,acoes.find("parado")*320,320,320))
	fontes.capa=Encaixe.capa_inteira()
	var quantidade=0
	for acao in Encaixe.PELES:
		var pasta=Encaixe.DESTINO+acao+"/"
		var raiz=Encaixe.RAIZ+"estudo_"+Encaixe.PELES[acao]+"/base/"
		var corpo=Image.load_from_file(raiz+"corpo_0.png")
		for pele in 3:Encaixe.escrever(Image.load_from_file(raiz+"corpo_%d.png"%pele),pasta+"corpo_%d.png"%pele)
		Encaixe.escrever(Image.load_from_file(raiz+"efeitos.png"),pasta+"ferramentas.png")
		for vazio in ["vazio","escudo_tras","escudo_frente"]:Encaixe.escrever(Image.create(320,320,false,Image.FORMAT_RGBA8),pasta+vazio+".png")
		var folhas={}
		for nome in nomes:folhas[nome]=Image.create(320,320,false,Image.FORMAT_RGBA8)
		for d in 4:
			for q in 4:
				var guia=guias.acoes[acao][d][q]
				var original=guias.originais[d]
				var modelo=corpo.get_region(Rect2i(q*80,d*80,80,80))
				var pixels=Encaixe.mapa(modelo,guia,original)
				for nome in nomes:
					var fonte=fontes[nome].get_region(Rect2i(0,d*80,80,80))
					var imagem: Image
					if nome.begins_with("cabelo_"):imagem=Encaixe.cabeca(fonte,guia,original,modelo)
					elif nome in ["capa","aljava"]:imagem=Encaixe.capa(fonte,guia,original,modelo)
					else:imagem=Encaixe.tecido(nome,fonte,pixels)
					folhas[nome].blit_rect(imagem,Rect2i(0,0,80,80),Vector2i(q*80,d*80))
		for nome in nomes:Encaixe.escrever(folhas[nome],pasta+nome+".png");quantidade+=1
	print("OK roupas e28 cabelos: ",quantidade," folhas nas duas ações")
	quit()
