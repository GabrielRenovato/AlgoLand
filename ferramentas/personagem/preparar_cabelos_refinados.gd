extends SceneTree

## Preserva os sete penteados, as poses e a máscara de cada pixel nativo.
## Tons neutros permitem que a cor personalizada continue tingindo as mechas.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const TONS := {"181818":0.10,"503850":0.23,"686878":0.43,"8898a0":0.61,"c8c8b8":0.80,"f8f8f8":0.97}
const ACESSORIOS := ["7f4935","b47f54","dab988"]

func _initialize() -> void:
	var destino := Aparencia.RAIZ_CABELOS_REFINADOS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	var manifesto := {}
	for indice in Aparencia.total_cabelos():
		var id: String = Aparencia.cabelos()[indice]["id"]
		for pagina in Padrao.CORPOS:
			var textura := Aparencia.cabelo(indice,pagina,-1,0)
			var nativa := textura.get_image()
			nativa.convert(Image.FORMAT_RGBA8)
			var folha := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
			for y in 512:
				for x in 512:
					var pixel := nativa.get_pixel(x,y)
					if pixel.a < 0.5:
						continue
					var chave := pixel.to_html(false)
					if chave in ACESSORIOS:
						# Preserva o prendedor do coque; não o confunde com uma mecha.
						for sy in 2:
							for sx in 2:
								folha.set_pixel(x*2+sx,y*2+sy,pixel)
						continue
					if not TONS.has(chave):
						push_error("Tom desconhecido em %s/%s: %s" % [id,pagina,chave])
						quit(1)
						return
					var tom: float = TONS[chave]
					for sy in 2:
						for sx in 2:
							var valor := tom
							if tom > 0.10:
								# Realça a borda da mecha em meio pixel, sem ampliar o cabelo.
								var nx := x-1 if sx == 0 else x+1
								var ny := y-1 if sy == 0 else y+1
								for ponto in [Vector2i(nx,y),Vector2i(x,ny)]:
									if ponto.x < 0 or ponto.y < 0 or ponto.x >= 512 or ponto.y >= 512 or ponto.x/64 != x/64 or ponto.y/64 != y/64:
										continue
									var vizinho := nativa.get_pixelv(ponto)
									if vizinho.a < 0.5:
										valor = minf(valor,0.18)
									else:
										var proximo: float = TONS.get(vizinho.to_html(false),tom)
										# Luz e sombra seguem os traços já desenhados, inclusive em quedas.
										if proximo > 0.10 and proximo != tom:
											valor = lerpf(valor,proximo,0.15)
							folha.set_pixel(x*2+sx,y*2+sy,Color(valor,valor,valor,1))
			var caminho: String = destino+id+"_"+pagina+".png"
			folha.save_png(caminho)
			manifesto[id+"/"+pagina] = {"indice":indice,"folha":caminho,"molde":textura.resource_path,"quadro":[128,128],"escala":0.5}
		print("Cabelo refinado: ",id)
	var arquivo := FileAccess.open(destino+"manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t")+"\n")
	print("Folhas refinadas: ",manifesto.size())
	quit()
