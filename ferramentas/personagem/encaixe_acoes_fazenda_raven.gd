extends RefCounted
## Compositor de peças originais sobre a geometria das novas poses. Não muda os
## desenhos de cabelo/elmo nem os ids; tecido segue as articulações e a silhueta.
const RAIZ="res://assets/personagens/raven_fantasy/"
const DESTINO=RAIZ+"acoes_fazenda/"
const GUIAS="res://arte/fontes/personagens/acoes_fazenda_raven/encaixes.json"
const PELES={"plantar":"plantio","colher":"colheita"}
const PECAS=["elmo","peitoral","luvas","botas"]

static func v(p: Array) -> Vector2:return Vector2(p[0],p[1])
static func ossos(p: Dictionary) -> Dictionary:
	var o={"tronco":[v(p.pescoco),v(p.quadril),4.3],"quadril":[v(p.quadril)-Vector2(0,1),v(p.quadril)+Vector2(0,1.5),3.7]}
	for lado in ["esquerdo","direito"]:
		var braco=p["braco_"+lado]
		var perna=p["perna_"+lado.replace("o","a")]
		o["braco_"+lado]=[v(braco[0]),v(braco[1]),1.7]
		o["antebraco_"+lado]=[v(braco[1]),v(braco[2]),1.7]
		o["coxa_"+lado]=[v(perna[0]),v(perna[1]),2.0]
		o["canela_"+lado]=[v(perna[1]),v(perna[2]),1.9]
	return o
static func projecao(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var eixo=b-a
	var t=clampf((p-a).dot(eixo)/maxf(eixo.length_squared(),0.01),0,1)
	return Vector2(t,p.distance_to(a+eixo*t))
static func parte(p: Vector2, guia: Dictionary) -> String:
	var centro=v(guia.cabeca)
	var cabeca=(p-centro)/Vector2(5.5,5.8)
	var o=ossos(guia)
	var nome="tronco"
	var menor=INF
	for id in o:
		var r=projecao(p,o[id][0],o[id][1])
		var distancia=r.y/float(o[id][2])
		if distancia<menor:menor=distancia;nome=id
	if cabeca.length_squared()<=1.0 and p.y<=centro.y+5:
		# Nos braços erguidos a mão pode passar junto ao contorno da cabeça.
		if not ((nome.begins_with("braco") or nome.begins_with("antebraco")) and menor<0.55 and cabeca.length_squared()>0.7):return "cabeca"
	return nome
static func coordenada(p: Vector2, id: String, alvo: Dictionary, origem: Dictionary) -> Vector2:
	var a=ossos(alvo)[id]
	var b=ossos(origem)[id]
	var t=projecao(p,a[0],a[1]).x
	var normal=(a[1]-a[0]).normalized().orthogonal()
	var afastamento=(p-a[0].lerp(a[1],t)).dot(normal)
	return b[0].lerp(b[1],t)+(b[1]-b[0]).normalized().orthogonal()*afastamento
static func mapa(corpo: Image, alvo: Dictionary, origem: Dictionary) -> Array:
	var pixels=[]
	for y in 80:
		for x in 80:
			if corpo.get_pixel(x,y).a<0.5:continue
			var p=Vector2(x,y)
			var id=parte(p,alvo)
			pixels.append({"pos":Vector2i(x,y),"parte":id,"uv":p if id=="cabeca" else coordenada(p,id,alvo,origem),"contorno":corpo.get_pixel(x,y)==Color("2e1c2c")})
	return pixels
static func candidatos(imagem: Image) -> Array[Vector2i]:
	var lista: Array[Vector2i]=[]
	for y in 80:
		for x in 80:
			if imagem.get_pixel(x,y).a>0.5:lista.append(Vector2i(x,y))
	return lista
static func amostrar(imagem: Image, uv: Vector2, lista: Array[Vector2i]) -> Color:
	var p=Vector2i(roundi(uv.x),roundi(uv.y))
	if Rect2i(0,0,80,80).has_point(p):
		var cor=imagem.get_pixelv(p)
		if cor.a>0.5:return cor
	var menor=INF
	var cor=Color.TRANSPARENT
	for pos in lista:
		var d=Vector2(pos).distance_squared_to(uv)
		if d<menor:menor=d;cor=imagem.get_pixelv(pos)
	return cor
static func pertence(camada: String, id: String) -> bool:
	match camada:
		"camisa_azul","camisa_verde","peitoral":return id=="tronco" or id.begins_with("braco") or (camada=="peitoral" and id=="quadril")
		"calca_marrom","calca_jeans":return id=="quadril" or id.begins_with("coxa")
		"luvas":return id.begins_with("antebraco")
		"botas":return id.begins_with("canela")
		"grevas":return id.begins_with("canela") or id.begins_with("coxa")
	return false
static func tecido(camada: String, origem: Image, pixels: Array) -> Image:
	var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
	var lista=candidatos(origem)
	for pixel in pixels:
		if pertence(camada,pixel.parte):
			var cor=amostrar(origem,pixel.uv,lista)
			# As roupas nativas usam o contorno do corpo sob o tecido. Preencher
			# também esse contorno com a cor interna apagava mangas e pernas.
			if camada in ["camisa_azul","camisa_verde","calca_marrom","calca_jeans","luvas","botas"] and pixel.contorno:
				cor=Color("2e1c2c")
			saida.set_pixelv(pixel.pos,cor)
	return saida
static func cabeca(origem: Image, guia: Dictionary, original: Dictionary, corpo: Image) -> Image:
	var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
	var deslocamento=Vector2i((v(guia.cabeca)-v(original.cabeca)).round())
	saida.blit_rect(origem,Rect2i(0,0,80,80),deslocamento)
	for y in 80:
		for x in 80:
			if corpo.get_pixel(x,y).a<0.5:continue
			var id=parte(Vector2(x,y),guia)
			if id.begins_with("braco") or id.begins_with("antebraco"):saida.set_pixel(x,y,Color.TRANSPARENT)
	return saida
static func capa_inteira() -> Image:
	# A camada parada já tem buracos onde os braços a cobriam. Ao erguer as
	# mãos, esses buracos precisam ser preenchidos com o tecido das poses
	# nativas que o revelam, no mesmo pivô, sem inventar outra capa.
	var atlas=Image.load_from_file(RAIZ+"camadas/capa.png")
	var acoes=JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"camadas/acoes.json"))
	var saida=atlas.get_region(Rect2i(0,acoes.find("parado")*320,320,320))
	for acao in ["jogar","puxar","magia","conjurar"]:
		var fonte=atlas.get_region(Rect2i(0,acoes.find(acao)*320,320,320))
		for d in 4:
			for y in 80:
				for x in 80:
					var p=Vector2i(x,d*80+y)
					if saida.get_pixelv(p).a<0.5 and fonte.get_pixelv(p).a>0.5:saida.set_pixelv(p,fonte.get_pixelv(p))
	return saida
static func capa(origem: Image, guia: Dictionary, original: Dictionary, corpo: Image) -> Image:
	var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
	var alvo=v(guia.pescoco)
	var fonte=v(original.pescoco)
	# Agachar dobra o tecido; erguer o tronco não alonga a capa até o chão.
	var escala=clampf((47.0-alvo.y)/(47.0-fonte.y),0.4,1.0)
	var inclinacao=(v(guia.quadril).x-alvo.x)-(v(original.quadril).x-fonte.x)
	for y in 80:
		for x in 80:
			var altura=clampf((y-alvo.y)/maxf(47.0-alvo.y,1.0),0,1)
			var uv=Vector2(x-alvo.x+fonte.x-inclinacao*altura,(y-alvo.y)/escala+fonte.y).round()
			if not Rect2i(0,0,80,80).has_point(Vector2i(uv)):continue
			var id=parte(Vector2(x,y),guia)
			if corpo.get_pixel(x,y).a>0.5 and (id=="cabeca" or id.begins_with("braco") or id.begins_with("antebraco")):continue
			saida.set_pixel(x,y,origem.get_pixelv(Vector2i(uv)))
	return saida
static func carregar_guias() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GUIAS))
static func escrever(imagem: Image, caminho: String):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	assert(imagem.save_png(caminho)==OK)

## Usa as quatro peças já compiladas pelo manifesto, sem mudar ids, status ou páginas.
static func preparar_conjunto(destino: String) -> void:
	var guias=carregar_guias()
	var acoes=JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"camadas/acoes.json"))
	var fontes={}
	for peca in PECAS:
		fontes[peca]=Image.load_from_file(destino+"raven_"+peca+".png").get_region(Rect2i(0,acoes.find("parado")*320,320,320))
	for acao in PELES:
		var corpo=Image.load_from_file(DESTINO+acao+"/corpo_0.png")
		var folhas={}
		for peca in PECAS:folhas[peca]=Image.create(320,320,false,Image.FORMAT_RGBA8)
		for d in 4:
			for q in 4:
				var guia=guias.acoes[acao][d][q]
				var original=guias.originais[d]
				var modelo=corpo.get_region(Rect2i(q*80,d*80,80,80))
				var pixels=mapa(modelo,guia,original)
				var partes={}
				for peca in PECAS:
					var fonte=fontes[peca].get_region(Rect2i(0,d*80,80,80))
					partes[peca]=cabeca(fonte,guia,original,modelo) if peca=="elmo" else tecido("grevas" if peca=="botas" else peca,fonte,pixels)
				# Regra compartilhada: cada pixel pertence a uma peça. Elmo fica acima.
				for y in 80:
					for x in 80:
						if partes.elmo.get_pixel(x,y).a>0.5:
							for peca in ["peitoral","luvas","botas"]:partes[peca].set_pixel(x,y,Color.TRANSPARENT)
				for peca in PECAS:folhas[peca].blit_rect(partes[peca],Rect2i(0,0,80,80),Vector2i(q*80,d*80))
		for peca in PECAS:escrever(folhas[peca],destino+"raven_"+peca+"/"+acao+".png")
