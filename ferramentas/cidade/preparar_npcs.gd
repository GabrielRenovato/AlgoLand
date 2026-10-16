extends SceneTree

## Quadros 64x64 preservam os detalhes; a altura visível define a escala no mapa.
const IDS := ["tomas", "rosa", "caio", "estela", "lia", "bento"]
const TAMANHO := 64
const ALTURA_PES := 60
const ALTURA_NO_MAPA := 34.0  # referência: corpo do jogador, sem chapéus ou armas
const FONTES := {"lia": "lia_olhos_corrigidos"}

func _initialize() -> void:
	var manifesto := {}
	for id in IDS:
		var fonte := "res://arte/fontes/npcs/cidade/%s.png" % FONTES.get(id, id)
		var imagem := Image.load_from_file(fonte)
		if imagem == null or imagem.is_empty() or imagem.get_width() < 128 or imagem.get_height() < 128:
			push_error("Folha ausente ou fora da grade 4x4: " + fonte)
			quit(1)
			return
		imagem.convert(Image.FORMAT_RGBA8)
		var quadros: Array[Image] = []
		var areas: Array[Rect2i] = []
		var maior := Vector2i.ZERO
		for y in range(4):
			for x in range(4):
				var inicio := Vector2i(floori(imagem.get_width()*x/4.0), floori(imagem.get_height()*y/4.0))
				var fim := Vector2i(floori(imagem.get_width()*(x+1)/4.0), floori(imagem.get_height()*(y+1)/4.0))
				var quadro := imagem.get_region(Rect2i(inicio, fim-inicio))
				var area := _area(quadro)
				if area.size == Vector2i.ZERO:
					push_error("Quadro vazio em " + id)
					quit(1)
					return
				quadros.append(quadro)
				areas.append(area)
				maior.x = maxi(maior.x, area.size.x)
				maior.y = maxi(maior.y, area.size.y)
		var escala := minf(52.0 / maior.x, 58.0 / maior.y)
		var folha := Image.create(TAMANHO*4, TAMANHO*4, false, Image.FORMAT_RGBA8)
		for i in range(16):
			var recorte := quadros[i].get_region(areas[i])
			recorte.resize(maxi(1, roundi(areas[i].size.x*escala)), maxi(1, roundi(areas[i].size.y*escala)), Image.INTERPOLATE_NEAREST)
			# Transparência binária: evita halos semitransparentes no cenário.
			for y in recorte.get_height():
				for x in recorte.get_width():
					var cor := recorte.get_pixel(x,y)
					cor.a = 1.0 if cor.a >= 0.5 else 0.0
					recorte.set_pixel(x,y,cor)
			# A redução pode deixar uma linha vazia na borda: ancora a base visível.
			recorte = recorte.get_region(recorte.get_used_rect())
			var destino := Vector2i((i%4)*TAMANHO+(TAMANHO-recorte.get_width())/2, (i/4)*TAMANHO+ALTURA_PES-recorte.get_height())
			folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), destino)
		var caminho := "res://assets/npcs/cidade/%s.png" % id
		if folha.save_png(caminho) != OK:
			push_error("Falha ao gravar " + caminho)
			quit(1)
			return
		var altura_parado := folha.get_region(Rect2i(TAMANHO,0,TAMANHO,TAMANHO)).get_used_rect().size.y
		manifesto[id] = {"fonte":fonte, "folha":caminho, "grade":[4,4], "quadro":[TAMANHO,TAMANHO], "pes_y":ALTURA_PES, "altura_parado":altura_parado, "altura_mapa":ALTURA_NO_MAPA, "escala_mapa":ALTURA_NO_MAPA/altura_parado, "direcoes":["baixo","direita","cima","esquerda"]}
		print("NPC preparado: ", id)
	var arquivo := FileAccess.open("res://assets/npcs/cidade/manifesto.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t") + "\n")
	quit()

func _area(imagem: Image) -> Rect2i:
	var minimo := imagem.get_size()
	var maximo := Vector2i(-1,-1)
	var linhas := PackedInt32Array()
	var colunas := PackedInt32Array()
	linhas.resize(imagem.get_height())
	colunas.resize(imagem.get_width())
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x,y).a >= 0.5:
				linhas[y] += 1
				colunas[x] += 1
	# Pontos soltos do recorte gerado não deslocam os pés nem diminuem o personagem.
	for y in imagem.get_height():
		for x in imagem.get_width():
			if linhas[y] >= 8 and colunas[x] >= 8 and imagem.get_pixel(x,y).a >= 0.5:
				minimo.x = mini(minimo.x,x)
				minimo.y = mini(minimo.y,y)
				maximo.x = maxi(maximo.x,x)
				maximo.y = maxi(maximo.y,y)
	return Rect2i(minimo,maximo-minimo+Vector2i.ONE) if maximo.x >= 0 else Rect2i()
