extends RefCounted
## Adaptador de atlas cartoon. Recorta camadas geradas; não desenha nem altera o corpo.
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const PECAS := ["elmo", "peitoral", "luvas", "botas"]

static func _ler(caminho: String) -> Image:
	var imagem := Image.load_from_file(caminho)
	if imagem != null: imagem.convert(Image.FORMAT_RGBA8)
	return imagem

static func _opaco(imagem: Image, x: int, y: int) -> bool:
	return imagem.get_pixel(x,y).a > 0.5

static func cabeca(imagem: Image) -> Dictionary:
	var topo := 0
	for y in mini(500,imagem.get_height()):
		var quantidade := 0
		for x in imagem.get_width():
			if _opaco(imagem,x,y): quantidade += 1
		if quantidade > 6:
			topo = y
			break
	var centros: Array[float] = []
	var raios: Array[float] = []
	for d in [25,35,45,55,65]:
		var y: int = topo+d
		var x0 := imagem.get_width()
		var x1 := -1
		for x in imagem.get_width():
			if _opaco(imagem,x,y):
				x0 = mini(x0,x)
				x1 = maxi(x1,x)
		if x1 <= x0: continue
		var largura := float(x1-x0+1)
		centros.append(float(x0+x1)*0.5)
		raios.append((largura*largura*0.25+d*d)/(2.0*d))
	centros.sort()
	raios.sort()
	return {"x":centros[centros.size()/2], "topo":topo,
		"raio":clampf(raios[raios.size()/2],75.0,145.0)}

static func _ponto(dados: Array) -> Vector2:
	return Vector2(float(dados[0]),float(dados[1]))

static func _distancia_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var v := b-a
	return p.distance_to(a+v*clampf((p-a).dot(v)/maxf(v.length_squared(),0.001),0.0,1.0))

static func _solas(corpo: Image, cranio: Dictionary) -> Array:
	var hip_y: float = cranio.topo+cranio.raio*2.0+(850.0-cranio.topo-cranio.raio*2.0)*0.32
	var saida := []
	for metade in 2:
		var inicio := 0 if metade == 0 else int(cranio.x)
		var fim := int(cranio.x) if metade == 0 else corpo.get_width()
		var y_sole := 0
		for y in range(int(hip_y+70),mini(870,corpo.get_height())):
			for x in range(inicio,fim):
				if _opaco(corpo,x,y): y_sole = y
		if y_sole == 0: continue
		var soma := 0.0
		var n := 0
		for y in range(maxi(0,y_sole-12),y_sole+1):
			for x in range(inicio,fim):
				if _opaco(corpo,x,y):
					soma += x
					n += 1
		var sola := Vector2(soma/maxi(1,n),y_sole-16)
		var joelho := Vector2(lerpf(float(cranio.x),sola.x,0.75),lerpf(hip_y,sola.y,0.5))
		saida.append([joelho,sola])
	return saida

static func _luva(p: Vector2, bracos: Array) -> bool:
	for braco in bracos:
		var mao := _ponto(braco.mao)
		var cotovelo := _ponto(braco.cotovelo)
		var cuff := mao+(cotovelo-mao).limit_length(88.0)
		if p.distance_to(mao) <= 53.0 or _distancia_segmento(p,mao,cuff) <= 43.0:
			return true
	return false

static func _regiao_elmo(p: Vector2, cranio: Dictionary, direcao: String, base: Array = []) -> bool:
	var r: float = cranio.raio
	if not base.is_empty():
		var limite := float(base[1])+(p.x-float(base[0]))*(float(base[3])-float(base[1]))/(float(base[2])-float(base[0]))
		return absf(p.x-float(cranio.x)) < r*1.4 and p.y < limite
	if direcao in ["frente","costas"]:
		var limite := float(cranio.topo)+r*(2.42 if direcao == "frente" else 2.08)
		if direcao == "frente": limite -= 0.5*maxf(0.0,absf(p.x-float(cranio.x))-r*0.5)
		return absf(p.x-float(cranio.x)) < r*1.4 and p.y < limite
	if p.y >= float(cranio.topo)+r*2.02 or absf(p.x-float(cranio.x)) >= r*1.32: return false
	if direcao in ["direita","esquerda"]:
		var x := p.x if direcao == "direita" else 2.0*float(cranio.x)-p.x
		# A borda inferior do perfil sobe na nuca: a ombreira não pertence ao elmo.
		return p.y < float(cranio.topo)+r*1.18+0.46*(x-(float(cranio.x)-r))
	return true

static func _dono(p: Vector2, cranio: Dictionary, bracos: Array, solas: Array, direcao: String, base: Array = []) -> int:
	if _luva(p,bracos): return 2
	if _regiao_elmo(p,cranio,direcao,base):
		return 0
	for perna in solas:
		if _distancia_segmento(p,perna[0],perna[1]) <= 64.0 or p.distance_to(perna[1]) <= 79.0:
			return 3
	return 1

static func _caminho(raiz: String, peca: String, pagina: String) -> String:
	return raiz+peca+"/"+pagina+".png"

static func _alinhar_folha(cfg: Dictionary, dados: Dictionary, tamanho: Vector2i) -> Image:
	var fonte := _ler(String(cfg.fontes)+String(dados.fonte))
	var escala := minf(float(tamanho.x)/fonte.get_width(),float(tamanho.y)/fonte.get_height())
	fonte.resize(roundi(fonte.get_width()*escala),roundi(fonte.get_height()*escala),Image.INTERPOLATE_LANCZOS)
	var saida := Image.create(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
	saida.blit_rect(fonte,Rect2i(Vector2i.ZERO,fonte.get_size()),(tamanho-fonte.get_size())/2)
	return saida

static func _olhos(imagem: Image, cranio: Dictionary) -> Rect2i:
	var r: float = cranio.raio
	var inicio := Vector2i(imagem.get_width(),896)
	var fim := Vector2i.ZERO
	for y in range(int(cranio.topo+r*0.6),mini(896,int(cranio.topo+r*2.4))):
		for x in range(maxi(0,int(cranio.x-r*1.4)),mini(imagem.get_width(),int(cranio.x+r*1.4))):
			var c := imagem.get_pixel(x,y)
			if c.a > 0.5 and minf(c.r,minf(c.g,c.b)) > 0.65 and maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) < 0.18:
				inicio = inicio.min(Vector2i(x,y))
				fim = fim.max(Vector2i(x+1,y+1))
	return Rect2i(inicio,fim-inicio)

static func _janela(roupa: Image, dados: Dictionary) -> Image:
	var mascara := Image.create(roupa.get_width(),896,false,Image.FORMAT_RGBA8)
	if dados.janela == null: return mascara
	var b: Array = dados.janela
	var area := Rect2i(int(b[0]),int(b[1]),int(b[2])-int(b[0]),int(b[3])-int(b[1]))
	if bool(dados.get("aberta",false)):
		# A face de perfil fornece a silhueta natural do nariz e do queixo.
		mascara.fill_rect(Rect2i(area.position-Vector2i(12,12),area.size+Vector2i(44,20)),Color.WHITE)
		return mascara
	area = area.grow(3)
	var semente := area.get_center()
	var melhor := INF
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if roupa.get_pixel(x,y).a > 0.13: continue
			var distancia := Vector2(x,y).distance_squared_to(Vector2(area.get_center()))
			if distancia < melhor:
				melhor = distancia
				semente = Vector2i(x,y)
	var fila: Array[Vector2i] = [semente]
	mascara.set_pixelv(semente,Color.WHITE)
	var indice := 0
	while indice < fila.size():
		var p := fila[indice]
		indice += 1
		for v in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var vizinho: Vector2i = p+v
			if not area.has_point(vizinho) or mascara.get_pixelv(vizinho).a > 0.0 or roupa.get_pixelv(vizinho).a > 0.13: continue
			mascara.set_pixelv(vizinho,Color.WHITE)
			fila.append(vizinho)
	# Um pixel por baixo do contorno antialias, mantendo a arte intacta.
	for p in fila:
		for v in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var vizinho: Vector2i = p+v
			if area.grow(1).has_point(vizinho): mascara.set_pixelv(vizinho,Color.WHITE)
	return mascara

static func _rosto(corpo: Image, roupa: Image, cranio: Dictionary, direcao: String, dados: Dictionary) -> Dictionary:
	var saida := Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
	if dados.janela == null: return {"imagem":saida,"sem_rosto":true}
	var b: Array = dados.janela
	var area := Rect2(Vector2(float(b[0]),float(b[1])),Vector2(float(b[2])-float(b[0]),float(b[3])-float(b[1])))
	var olhos := _olhos(corpo,cranio)
	assert(olhos.size.y > 0,"Olhos ausentes no corpo original")
	var aberta := bool(dados.get("aberta",false))
	var escala := area.size.y*(0.35 if aberta else 0.46)/float(olhos.size.y)
	var centro := area.position+area.size*Vector2(0.44 if direcao == "direita" else 0.56 if direcao == "esquerda" else 0.5,0.32 if aberta else 0.47)
	var janela := _janela(roupa,dados)
	var deslocamento := Vector2i.ZERO
	var ajustada: Image
	var faltantes := 0
	var fonte: Image = corpo
	if dados.has("recorte_cabeca_origem"):
		var recorte: Array = dados.recorte_cabeca_origem
		fonte = Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
		var regiao := Rect2i(int(recorte[0]),int(recorte[1]),int(recorte[2])-int(recorte[0]),int(recorte[3])-int(recorte[1]))
		fonte.blit_rect(corpo,regiao,regiao.position)
	for tentativa in 12:
		var copia: Image = fonte.duplicate()
		copia.resize(roundi(corpo.get_width()*escala),roundi(896*escala),Image.INTERPOLATE_LANCZOS)
		deslocamento = Vector2i((centro-Vector2(olhos.get_center())*escala).round())
		ajustada = Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
		ajustada.blit_rect(copia,Rect2i(Vector2i.ZERO,copia.get_size()),deslocamento)
		faltantes = 0
		for y in range(int(area.position.y),int(area.end.y)):
			for x in range(int(area.position.x),int(area.end.x)):
				if janela.get_pixel(x,y).a > 0.0 and ajustada.get_pixel(x,y).a < 0.98: faltantes += 1
		if aberta or faltantes < 3: break
		escala *= 1.025
	for y in 896:
		for x in corpo.get_width():
			if janela.get_pixel(x,y).a > 0.0: saida.set_pixel(x,y,ajustada.get_pixel(x,y))
	return {"imagem":saida,"escala":escala,"deslocamento":[deslocamento.x,deslocamento.y],"olhos_origem":str(olhos),"janela":dados.janela,"aberta":aberta,"pixels_sem_pele":faltantes}

static func gerar(config: Dictionary, pagina_unica: String = "") -> int:
	var cfg: Dictionary = config.cartoon
	var raiz: String = cfg.destino
	var marcas: Dictionary = Padrao.carregar(cfg.marcacoes)
	var encaixes: Dictionary = Padrao.carregar(cfg.encaixes_rosto)
	for pasta in PECAS+["cobertura","completo","rosto"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(raiz+pasta))
	var relatorio := {"id":config.id,"pecas":PECAS,"paginas":{},"fontes_corpo":{},"fontes_armadura":{},"armadura_original_preservada":true}
	if not pagina_unica.is_empty(): relatorio = Padrao.carregar(raiz+"compilacao.json")
	relatorio.fontes_armadura = relatorio.get("fontes_armadura",{})
	relatorio.armadura_original_preservada = true
	for pagina in cfg.paginas:
		if not pagina_unica.is_empty() and pagina != pagina_unica: continue
		var dados: Dictionary = cfg.paginas[pagina]
		var corpo := _ler(dados.corpo)
		var alinhada := _alinhar_folha(cfg,dados,corpo.get_size())
		var largura := corpo.get_width()/4
		var folhas: Array[Image] = []
		for peca in PECAS: folhas.append(Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8))
		var cobertura := Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
		cobertura.fill(Color(0,0,0,1))
		var rostos := Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
		var composto := Image.create(corpo.get_width(),896,false,Image.FORMAT_RGBA8)
		var poses := []
		for q in 4:
			var referencia := corpo.get_region(Rect2i(q*largura,0,largura,896))
			var roupa := alinhada.get_region(Rect2i(q*largura,0,largura,896))
			var cranio_corpo := cabeca(referencia)
			var cranio_roupa := cabeca(roupa)
			var bracos: Array = marcas[pagina][q].bracos
			var base: Array = dados.get("base_elmo",{}).get(str(q),[])
			var solas := _solas(referencia,cranio_corpo)
			var face := _rosto(referencia,roupa,cranio_corpo,dados.direcoes[q],encaixes[pagina][q])
			rostos.blit_rect(face.imagem,Rect2i(0,0,largura,896),Vector2i(q*largura,0))
			face.erase("imagem")
			poses.append(face)
			for y in 896:
				for x in largura:
					var cor := roupa.get_pixel(x,y)
					var original := referencia.get_pixel(x,y)
					if cor.a == 0.0 and original.a == 0.0: continue
					var p := Vector2(x,y)
					var dono := _dono(p,cranio_roupa,bracos,solas,dados.direcoes[q],base)
					folhas[dono].set_pixel(q*largura+x,y,cor)
					if original.a > 0.0:
						var cabeca_original := y < float(cranio_corpo.topo)+float(cranio_corpo.raio)*2.5 and absf(x-float(cranio_corpo.x)) < float(cranio_corpo.raio)*1.4
						var dono_corpo := 2 if _luva(p,bracos) else 0 if cabeca_original else dono
						cobertura.set_pixel(q*largura+x,y,Color(float(dono_corpo+1)/4.0,0,0,1))
		for i in 4: folhas[i].save_png(_caminho(raiz,PECAS[i],pagina))
		cobertura.save_png(_caminho(raiz,"cobertura",pagina))
		alinhada.save_png(_caminho(raiz,"completo",pagina))
		rostos.save_png(_caminho(raiz,"rosto",pagina))
		composto.blend_rect(rostos,Rect2i(Vector2i.ZERO,rostos.get_size()),Vector2i.ZERO)
		composto.blend_rect(alinhada,Rect2i(Vector2i.ZERO,alinhada.get_size()),Vector2i.ZERO)
		var previa := "res://arte/previas/armaduras/"+String(config.id)+"/composicoes/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(previa))
		composto.save_png(previa+String(pagina)+".png")
		relatorio.paginas[pagina] = {"dimensoes":[corpo.get_width(),896],"rostos":poses}
		relatorio.fontes_corpo[dados.corpo] = FileAccess.get_sha256(dados.corpo)
		var fonte: String = String(cfg.fontes)+String(dados.fonte)
		relatorio.fontes_armadura[fonte] = FileAccess.get_sha256(fonte)
		print("CARTOON: ",pagina," arte original intacta; rosto independente")
	for peca in PECAS+["cobertura","completo","rosto"]:
		if not pagina_unica.is_empty() and pagina_unica != "corrida_direita": continue
		var direita := _ler(_caminho(raiz,peca,"corrida_direita"))
		var esquerda := Image.create(direita.get_width(),896,false,Image.FORMAT_RGBA8)
		for q in 4:
			var quadro := direita.get_region(Rect2i(q*512,0,512,896))
			quadro.flip_x()
			esquerda.blit_rect(quadro,Rect2i(0,0,512,896),Vector2i(q*512,0))
		esquerda.save_png(_caminho(raiz,peca,"corrida_esquerda"))
	FileAccess.open(raiz+"compilacao.json",FileAccess.WRITE).store_string(JSON.stringify(relatorio,"\t"))
	return 0

static func validar(config: Dictionary) -> int:
	var cfg: Dictionary = config.cartoon
	var raiz: String = cfg.destino
	var relatorio := Padrao.carregar(raiz+"compilacao.json")
	var falhas := 0
	for grupo in ["fontes_corpo","fontes_armadura"]:
		for fonte in relatorio[grupo]:
			if FileAccess.get_sha256(fonte) != relatorio[grupo][fonte]:
				push_error("Fonte original alterada: "+String(fonte))
				falhas += 1
	for pagina in cfg.paginas.keys()+["corrida_esquerda"]:
		var inteiro := _ler(_caminho(raiz,"completo",pagina))
		if cfg.paginas.has(pagina):
			var tamanho := inteiro.get_size()
			if inteiro.get_data() != _alinhar_folha(cfg,cfg.paginas[pagina],tamanho).get_data():
				push_error("Armadura difere do original: "+String(pagina))
				falhas += 1
		var pecas: Array[Image] = []
		for peca in PECAS: pecas.append(_ler(_caminho(raiz,peca,pagina)))
		var divergentes := 0
		for y in 896:
			for x in inteiro.get_width():
				var quantidade := 0
				var cor := Color(0,0,0,0)
				for camada in pecas:
					var pixel := camada.get_pixel(x,y)
					if pixel.a > 0.0:
						quantidade += 1
						cor = pixel
				if quantidade > 1 or (inteiro.get_pixel(x,y).a > 0.0 and inteiro.get_pixel(x,y) != cor): divergentes += 1
		if divergentes:
			push_error("Recomposição divergente: "+String(pagina)+" "+str(divergentes))
			falhas += 1
	print("CARTOON: 11 páginas; arte original, quatro peças e fontes preservadas: ",falhas," falhas.")
	return falhas

