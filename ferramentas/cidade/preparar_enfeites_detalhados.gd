extends SceneTree
## Originais detalhados, 4x a resolução lógica; nenhuma mudança no layout físico.
const SAIDA := "res://assets/cenario/cidade/enfeites_detalhados/"
const FONTES := "res://arte/fontes/cidade/enfeites_detalhados/"
const ESTACOES := ["primavera","verao","outono","inverno"]
const NOMES := ["fonte_anim","mural","poste_luz","placa_encruzilhada","correio","coreto","galinheiro","feno","lenha","cerca","mesa_piquenique","banco_piquenique_esquerdo","banco_piquenique_direito","canteiro","horta","arbusto","flores"]
func _initialize() -> void:
	var manifesto := {}
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/decoracao/decoracao.json"))
	for item: Dictionary in itens:
		var chave: String = item.p
		var nome := chave.get_file()
		if nome not in NOMES or manifesto.has(chave): continue
		var id := "fonte" if nome=="fonte_anim" else ("banqueta" if nome.begins_with("banco_piquenique_") else nome)
		var caminho := "res://arte/fontes/cidade/objetos/coreto.png" if id=="coreto" else FONTES+("fonte_estrutura" if id=="fonte" else id)+".png"
		var original := Image.load_from_file(caminho)
		var area := _area(Image.load_from_file(FONTES+"fonte.png")) if id=="fonte" else _area(original)
		var usado: Array = item.usado
		var tamanho := Vector2i(int(usado[0]+usado[2]),int(usado[1]+usado[3]))
		if id=="fonte": tamanho=Vector2i(96,96)
		var base := Image.create(tamanho.x*4,tamanho.y*4,false,Image.FORMAT_RGBA8)
		var recorte := original.get_region(area)
		recorte.resize(int(usado[2])*4,int(usado[3])*4,Image.INTERPOLATE_LANCZOS)
		base.blit_rect(recorte,Rect2i(Vector2i.ZERO,recorte.get_size()),Vector2i(int(usado[0])*4,int(usado[1])*4))
		var quadros := 1
		var caminhos: Array[String] = []
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA+id))
		for e in 4:
			var sazonal := _estacao(base,e,id)
			var folha := Image.create(base.get_width()*quadros,base.get_height(),false,Image.FORMAT_RGBA8)
			for q in quadros:
				var imagem := sazonal
				folha.blit_rect(imagem,Rect2i(Vector2i.ZERO,imagem.get_size()),Vector2i(q*base.get_width(),0))
			var destino: String = SAIDA+id+"/"+ESTACOES[e]+".png"
			assert(folha.save_png(destino)==OK)
			_importacao(destino)
			caminhos.append(destino)
		manifesto[chave] = {"texturas":caminhos,"resolucao":4,"quadros":quadros,"fps":0,"simulacao_agua":id=="fonte","canvas_logico":[tamanho.x,tamanho.y],"fonte":caminho,"area_fonte":[area.position.x,area.position.y,area.size.x,area.size.y]}
		print("Enfeite detalhado: ",chave,"; quatro estações; ",quadros," quadros")
	var arquivo := FileAccess.open(SAIDA+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto," ",false)+"\n")
	quit()
func _area(imagem: Image) -> Rect2i:
	var minimo := imagem.get_size()
	var maximo := Vector2i.ZERO
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x,y).a>.5:
				minimo=Vector2i(mini(minimo.x,x),mini(minimo.y,y))
				maximo=Vector2i(maxi(maximo.x,x),maxi(maximo.y,y))
	return Rect2i(minimo,maximo-minimo+Vector2i.ONE)
func _estacao(base: Image,e: int,id: String) -> Image:
	var imagem: Image = base.duplicate()
	if e==0: return imagem
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x,y)
			if cor.a<.01: continue
			var verde := cor.g>cor.r*1.06 and cor.g>cor.b*1.15
			var planta := id in ["canteiro","horta","arbusto","flores"] or y>imagem.get_height()*.7
			if verde and planta:
				if e==1: cor=Color(cor.r*.91,cor.g*.95,cor.b*.90,cor.a)
				elif e==2: cor=Color.from_hsv(.075,clampf(cor.s*.8,.25,.85),cor.v*.95,cor.a)
				else: cor=Color.from_hsv(.12,cor.s*.2,cor.v*.80,cor.a)
			elif id in ["canteiro","arbusto","flores"] and cor.r>cor.g*1.3 and cor.b>cor.g*1.15:
				if e==1: cor=Color.from_hsv(.12,.5,cor.v,cor.a)
				elif e==2: cor=Color.from_hsv(.065,.6,cor.v*.85,cor.a)
				else: cor=Color(.75*cor.v,.8*cor.v,.84*cor.v,cor.a)
			elif not (cor.b>cor.r*1.25 and cor.g>cor.r*1.15):
				# Umidade e exposição dos materiais, sem recolorir água ou ferragens.
				var fator := 1.025 if e==1 else (.97 if e==2 else .94)
				cor=Color(cor.r*fator,cor.g*fator,cor.b*fator,cor.a)
			imagem.set_pixel(x,y,cor)
	if e==3:
		for x in imagem.get_width():
			for y in imagem.get_height():
				if imagem.get_pixel(x,y).a<.7: continue
				for dy in 6:
					if y+dy>=imagem.get_height(): break
					var cor := imagem.get_pixel(x,y+dy)
					if cor.a>.5: imagem.set_pixel(x,y+dy,Color("e3eef1") if dy<4 else Color("a7c1d2"))
				break
	return imagem
func _importacao(caminho: String) -> void:
	var config := ConfigFile.new()
	var existe := config.load(caminho+".import")==OK
	if not existe:
		config.set_value("remap","importer","texture")
		config.set_value("remap","type","CompressedTexture2D")
		config.set_value("deps","source_file",caminho)
	config.set_value("params","mipmaps/generate",true)
	config.save(caminho+".import")
