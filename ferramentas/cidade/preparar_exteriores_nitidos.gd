extends SceneTree
## Preserva detalhe dos originais em texturas 4x, mantendo a escala lógica do mapa.
const SAIDA := "res://assets/cenario/cidade/fachadas_detalhadas/"
const ESTACOES := ["primavera","verao","outono","inverno"]
const PADRAO_TAVERNA := ["venda", "sede", "enfermaria", "mistica", "casa_bento", "forja", "carpintaria"]
const FONTES := {
	"venda":"res://arte/fontes/cidade/fachadas_padrao_taverna/venda.png", "sede":"res://arte/fontes/cidade/fachadas_padrao_taverna/sede.png",
	"enfermaria":"res://arte/fontes/cidade/fachadas_padrao_taverna/enfermaria.png", "pousada":"res://arte/fontes/cidade/enfeites_detalhados/pousada_frontal.png",
	"mistica":"res://arte/fontes/cidade/fachadas_padrao_taverna/mistica.png", "casa_bento":"res://arte/fontes/cidade/fachadas_padrao_taverna/casa_bento.png",
	"casa_jogador":"res://arte/fontes/fazenda/acabamento_detalhado/casa.png",
	"forja":"res://arte/fontes/cidade/fachadas_padrao_taverna/forja.png", "carpintaria":"res://arte/fontes/cidade/fachadas_padrao_taverna/carpintaria.png"
}
const JANELAS := {
	"venda":[Vector2(.24,.72),Vector2(.78,.72),Vector2(.35,.38)], "sede":[Vector2(.18,.72),Vector2(.82,.72),Vector2(.50,.40)],
	"enfermaria":[Vector2(.25,.72),Vector2(.75,.74)], "pousada":[Vector2(.22,.40),Vector2(.78,.40),Vector2(.50,.51),Vector2(.22,.76),Vector2(.78,.76)],
	"mistica":[Vector2(.21,.49),Vector2(.21,.75),Vector2(.52,.55),Vector2(.76,.50),Vector2(.82,.74)], "casa_bento":[Vector2(.28,.73),Vector2(.70,.73),Vector2(.495,.46)],
	"casa_jogador":[Vector2(.27,.72),Vector2(.73,.72)], "forja":[Vector2(.48,.44),Vector2(.77,.68)], "carpintaria":[Vector2(.225,.66),Vector2(.43,.37),Vector2(.65,.66)]
}
const CHAMINES := {"venda":Vector2(.22,.05),"sede":Vector2(.29,.04),"enfermaria":Vector2(.25,.03),"pousada":Vector2(.20,.025),"mistica":Vector2(.44,.20),"casa_bento":Vector2(.26,.03),"casa_jogador":Vector2(.82,.025),"forja":Vector2(.23,.04),"carpintaria":Vector2(.63,.02)}
## Soleiras medidas nos originais: vasos, barris e placas não são a porta.
const SOLEIRAS := {"venda":Vector2(.54,.95),"sede":Vector2(.51,1),"enfermaria":Vector2(.51,1),"pousada":Vector2(.529,1),"mistica":Vector2(.52,.985),"casa_bento":Vector2(.48,.995),"casa_jogador":Vector2(.501,1),"forja":Vector2(.48,.995),"carpintaria":Vector2(.43,1)}
func _initialize() -> void:
	var medidas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/casas/exteriores.json"))
	var caminho_manifesto := SAIDA+"manifesto.json"
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho_manifesto)) if FileAccess.file_exists(caminho_manifesto) else {}
	var filtro := OS.get_cmdline_user_args()
	for id: String in FONTES:
		if not filtro.is_empty() and id not in filtro: continue
		var fonte := Image.load_from_file(FONTES[id])
		var sazonal := id in PADRAO_TAVERNA
		var tamanho: Vector2i = fonte.get_size()/2 if sazonal else fonte.get_size()
		var primavera := fonte.get_region(Rect2i(Vector2i.ZERO,tamanho))
		if sazonal: primavera = _limpar_recorte(primavera)
		var area := _area(primavera)
		# A soleira é o trecho inferior central, e continua na mesma origem do mapa.
		var ancora_fonte: Vector2 = Vector2(area.position)+SOLEIRAS[id]*Vector2(area.size)
		var geometria: Dictionary = medidas[id]
		var ancora := Vector2(geometria.ancora[0],geometria.ancora[1])
		var usado: Array = geometria.usado
		var nativa := Image.load_from_file("res://assets/cenario/cidade/casas/exterior/"+id+".png")
		var canvas := nativa.get_size()*4
		var horizontal := minf((ancora.x-float(usado[0]))/(ancora_fonte.x-area.position.x),(float(usado[0]+usado[2])-ancora.x)/(area.end.x-ancora_fonte.x))
		var vertical := (ancora.y-float(usado[1]))/(ancora_fonte.y-area.position.y)
		var escala := Vector2(horizontal,vertical)*4.0
		var posicao := (ancora*4.0-(ancora_fonte-Vector2(area.position))*escala).round()
		var dimensao := (Vector2(area.size)*escala).round()
		var caminhos: Array[String] = []
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA+id))
		for e in 4:
			var celula := fonte.get_region(Rect2i(Vector2i(e%2,e/2)*tamanho,tamanho)) if sazonal else primavera
			if sazonal: celula = _limpar_recorte(celula)
			var area_quadro := _area(celula) if sazonal else area
			var recorte := celula.get_region(area_quadro)
			var dimensao_quadro := dimensao
			var posicao_quadro := posicao
			if sazonal:
				# Alinha a soleira de cada quadro à mesma porta física, mesmo com neve maior.
				var ancora_quadro: Vector2 = Vector2(area_quadro.position) + SOLEIRAS[id] * Vector2(area_quadro.size)
				var sx := minf((ancora.x-float(usado[0]))/(ancora_quadro.x-area_quadro.position.x),(float(usado[0]+usado[2])-ancora.x)/(area_quadro.end.x-ancora_quadro.x))
				var sy := (ancora.y-float(usado[1]))/(ancora_quadro.y-area_quadro.position.y)
				var escala_quadro := Vector2(sx,sy)*4.0
				dimensao_quadro = (Vector2(area_quadro.size)*escala_quadro).round()
				posicao_quadro = (ancora*4.0-(ancora_quadro-Vector2(area_quadro.position))*escala_quadro).round()
			if id == "casa_jogador" and e == 3:
				var inverno := Image.load_from_file("res://arte/fontes/fazenda/acabamento_detalhado/casa_inverno.png")
				inverno = inverno.get_region(Rect2i(0,40,inverno.get_width(),inverno.get_height()-40))
				recorte = inverno.get_region(_area(inverno))
			recorte.resize(int(dimensao_quadro.x),int(dimensao_quadro.y),Image.INTERPOLATE_LANCZOS)
			var imagem := Image.create(canvas.x,canvas.y,false,Image.FORMAT_RGBA8)
			imagem.blit_rect(recorte,Rect2i(Vector2i.ZERO,recorte.get_size()),Vector2i(posicao_quadro))
			if not sazonal and not (id == "casa_jogador" and e == 3): _estacao(imagem,e,id)
			var caminho: String = SAIDA+id+"/"+ESTACOES[e]+".png"
			assert(imagem.save_png(caminho)==OK)
			caminhos.append(caminho)
			if e==0:
				var mascara: Image = imagem.duplicate()
				for y in mascara.get_height():
					for x in mascara.get_width():
						var alfa := mascara.get_pixel(x,y).a
						mascara.set_pixel(x,y,Color(1,1,1,alfa))
				assert(mascara.save_png("res://assets/cenario/cidade/sombras/casas/"+id+".png")==OK)
		var chamine: Vector2 = (posicao+CHAMINES[id]*dimensao)/4.0-ancora
		var janelas: Array = []
		for centro: Vector2 in JANELAS[id]:
			var ponto := (posicao+centro*dimensao)/4.0-ancora
			janelas.append([ponto.x,ponto.y])
		manifesto[id] = {"texturas":caminhos,"quadros":1,"fps":0,"resolucao":4,"fonte":FONTES[id],"chamine":[chamine.x,chamine.y],"janelas":janelas,"ancora_fonte":[ancora_fonte.x,ancora_fonte.y],"area_fonte":[area.position.x,area.position.y,area.size.x,area.size.y],"canvas_logico":[nativa.get_width(),nativa.get_height()]}
		print("Fachada detalhada ",id,": ",canvas," / escala lógica 4; quatro estações")
	var arquivo := FileAccess.open(SAIDA+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto," ",false)+"\n")
	quit()

func _limpar_recorte(imagem: Image) -> Image:
	# Extrai a silhueta útil sem levar pontos soltos do espaço entre os quadros.
	imagem.convert(Image.FORMAT_RGBA8)
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var dados := imagem.get_data()
	var vistos := PackedByteArray()
	vistos.resize(largura*altura)
	var manter := PackedByteArray()
	manter.resize(largura*altura)
	for inicio in largura*altura:
		if vistos[inicio] or dados[inicio*4+3] < 32: continue
		var fila := PackedInt32Array([inicio])
		vistos[inicio] = 1
		var frente := 0
		while frente < fila.size():
			var i := fila[frente]
			frente += 1
			for vizinho in [i-1,i+1,i-largura,i+largura]:
				if vizinho < 0 or vizinho >= largura*altura: continue
				if absi(vizinho-i) == 1 and vizinho/largura != i/largura: continue
				if vistos[vizinho] or dados[vizinho*4+3] < 32: continue
				vistos[vizinho] = 1
				fila.append(vizinho)
		if fila.size() < 128: continue
		for i in fila:
			manter[i] = 1
			# Conserva a borda com alfa suave junto à arte válida.
			for vizinho in [i-1,i+1,i-largura,i+largura]:
				if vizinho >= 0 and vizinho < manter.size(): manter[vizinho] = 1
	for i in manter.size():
		if not manter[i]: dados[i*4+3] = 0
	return Image.create_from_data(largura,altura,false,Image.FORMAT_RGBA8,dados)

func _area(imagem: Image) -> Rect2i:
	var minimo := imagem.get_size()
	var maximo := Vector2i.ZERO
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x,y).a>.5:
				minimo = Vector2i(mini(minimo.x,x),mini(minimo.y,y))
				maximo = Vector2i(maxi(maximo.x,x),maxi(maximo.y,y))
	return Rect2i(minimo,maximo-minimo+Vector2i.ONE)
func _soleira(imagem: Image, area: Rect2i) -> Vector2:
	var limite := area.position.y
	var xs: Array[int] = []
	for y in range(area.end.y-1,area.position.y,-1):
		for x in range(area.position.x+int(area.size.x*.30),area.position.x+int(area.size.x*.70)):
			if imagem.get_pixel(x,y).a>.7: xs.append(x)
		if not xs.is_empty():
			limite = y
			break
	return Vector2(float(xs[0]+xs[-1])/2.0,limite+1)
func _estacao(imagem: Image, e: int, id: String) -> void:
	if e==0: return
	var w := imagem.get_width()
	var h := imagem.get_height()
	for y in h:
		for x in w:
			var cor := imagem.get_pixel(x,y)
			if cor.a<.1: continue
			# Preservar telhados verdes e ferragens; mudar somente plantas baixas.
			if y>h*.60 and cor.g>cor.r*1.06 and cor.g>cor.b*1.15:
				if e==1: cor=Color(cor.r*.92,cor.g*.97,cor.b*.92,cor.a)
				elif e==2: cor=Color.from_hsv(.08,clampf(cor.s*.85,.25,.8),cor.v,cor.a)
				else: cor=Color.from_hsv(.12,cor.s*.23,cor.v*.82,cor.a)
				imagem.set_pixel(x,y,cor)
			# Flores expostas acompanham as plantas, inclusive sob a neve.
			if y>h*.65 and cor.r>cor.g*1.3 and cor.b>cor.g*1.15:
				if e==1: cor=Color.from_hsv(.12,.55,cor.v,cor.a)
				elif e==2: cor=Color.from_hsv(.065,.65,cor.v*.9,cor.a)
				else: cor=Color(.83*cor.v,.89*cor.v,.93*cor.v,cor.a)
				imagem.set_pixel(x,y,cor)
	if e==3:
		# Camada de neve nas superfícies expostas, sem tingir paredes inteiras.
		for x in w:
			var topo := -1
			for y in h:
				if imagem.get_pixel(x,y).a>.7:
					topo=y
					break
			if topo<0: continue
			for dy in 7:
				if topo+dy>=h: break
				var cor := imagem.get_pixel(x,topo+dy)
				if cor.a>.5: imagem.set_pixel(x,topo+dy,Color("e3eef1") if dy<4 else Color("a7c1d2"))
