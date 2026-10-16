extends RefCounted

## Acabamento de apresentação. Os moldes de 64 px e os dados do conjunto permanecem nativos.
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const RAIZ := "res://assets/personagens/refinado/conjuntos/"

static func refinar(nativa: Image, metal: bool = false, preservar_claros: bool = false) -> Image:
	var fonte: Image = nativa.duplicate()
	fonte.convert(Image.FORMAT_RGBA8)
	var nova := Image.create(fonte.get_width()*2,fonte.get_height()*2,false,Image.FORMAT_RGBA8)
	for y in fonte.get_height():
		for x in fonte.get_width():
			var pixel: Color = fonte.get_pixel(x,y)
			if pixel.a < 0.5:
				continue
			var base := _tom(pixel)
			for sy in 2:
				for sx in 2:
					if preservar_claros and minf(pixel.r,minf(pixel.g,pixel.b)) >= 0.90:
						# Rastros de golpe, água e brilhos conservam a intensidade original.
						pixel.a = 1
						nova.set_pixel(x*2+sx,y*2+sy,pixel)
						continue
					var cor := base
					if pixel.get_luminance() > 0.16:
						var nx: int = x-1 if sx == 0 else x+1
						var ny: int = y-1 if sy == 0 else y+1
						for ponto in [Vector2i(nx,y),Vector2i(x,ny)]:
							if ponto.x < 0 or ponto.y < 0 or ponto.x >= fonte.get_width() or ponto.y >= fonte.get_height() or ponto.x/64 != x/64 or ponto.y/64 != y/64:
								continue
							var vizinho: Color = fonte.get_pixelv(ponto)
							if vizinho.a < 0.5:
								# Contorno de meio pixel, sem apagar ou ampliar a silhueta.
								cor = cor.darkened(0.18)
							elif vizinho.get_luminance() > 0.16 and absf(vizinho.get_luminance()-pixel.get_luminance()) < 0.25 and absf(vizinho.h-pixel.h) < 0.10:
								# As dobras e chapas seguem os traços da pose nativa.
								cor = cor.lerp(_tom(vizinho),0.12)
						if metal and sx == 0 and sy == 0 and pixel.get_luminance() > 0.3:
							cor = cor.lightened(0.04)
					cor.a = 1.0
					nova.set_pixel(x*2+sx,y*2+sy,cor)
	return nova

static func _tom(cor: Color) -> Color:
	if cor.get_luminance() < 0.16:
		return Color(cor.r*0.8,cor.g*0.8,cor.b*0.8,1)
	return Color(clampf((cor.r-0.45)*1.08+0.45,0,1),clampf((cor.g-0.45)*1.08+0.45,0,1),clampf((cor.b-0.45)*1.08+0.45,0,1),1)

static func compilar_conjunto(config: Dictionary) -> bool:
	var origem: String = config["destino"]
	var destino: String = RAIZ+String(config["id"])+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	var manifesto := {"origem":origem,"id":config["id"],"modo_visual":config.get("modo_visual","armadura"),"grade":[8,8],"quadro":[128,128],"escala":0.5,"paginas":{}}
	for pagina in Padrao.CORPOS:
		var nativa := Image.load_from_file(origem+pagina+".png")
		if nativa == null:
			return false
		var completa := refinar(nativa,config.get("modo_visual","armadura") != "tecido")
		if completa.save_png(destino+pagina+".png") != OK:
			return false
		for peca in Padrao.PECAS:
			var mascara := Image.load_from_file(origem+peca+"/"+pagina+".png")
			if mascara == null:
				return false
			var folha := completa.duplicate()
			for y in folha.get_height():
				for x in folha.get_width():
					if mascara.get_pixel(x/2,y/2).a < 0.5:
						folha.set_pixel(x,y,Color.TRANSPARENT)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino+peca))
			if folha.save_png(destino+peca+"/"+pagina+".png") != OK:
				return false
		manifesto["paginas"][pagina] = {"molde":origem+pagina+".png","folha":destino+pagina+".png"}
	var arquivo := FileAccess.open(destino+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t")+"\n")
	print("Acabamento refinado: ",config["id"]," — 11 páginas, quatro peças independentes")
	return true

static func validar_conjunto(config: Dictionary) -> PackedStringArray:
	var erros := PackedStringArray()
	var raiz: String = RAIZ+String(config["id"])+"/"
	for pagina in Padrao.CORPOS:
		var completa := Image.load_from_file(raiz+pagina+".png")
		var nativa := Image.load_from_file(String(config["destino"])+pagina+".png")
		if completa == null or completa.get_size() != Vector2i(1024,1024):
			erros.append(pagina+": resolução refinada inválida")
			continue
		var recomposta := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
		var cobertura := true
		for peca in Padrao.PECAS:
			var folha := Image.load_from_file(raiz+peca+"/"+pagina+".png")
			var original := Image.load_from_file(String(config["destino"])+peca+"/"+pagina+".png")
			if folha == null or folha.get_size() != Vector2i(1024,1024):
				erros.append(pagina+"/"+peca+": resolução inválida")
				continue
			for y in 1024:
				for x in 1024:
					var alfa := folha.get_pixel(x,y).a
					if alfa != original.get_pixel(x/2,y/2).a or (alfa != 0 and alfa != 1):
						cobertura = false
					if alfa > 0 and recomposta.get_pixel(x,y).a > 0:
						cobertura = false
			recomposta.blend_rect(folha,Rect2i(0,0,1024,1024),Vector2i.ZERO)
		for y in 1024:
			for x in 1024:
				if completa.get_pixel(x,y).a != nativa.get_pixel(x/2,y/2).a:
					cobertura = false
		if not cobertura:
			erros.append(pagina+": máscara ou independência das peças mudou")
		if recomposta.get_data() != completa.get_data():
			erros.append(pagina+": recomposição inexata")
	return erros
