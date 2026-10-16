extends SceneTree

## Refina a paleta e o sombreado sem transportar partes entre poses.
## Olhos, mãos, contornos e cobertura vêm do desenho nativo em cada quadro.
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const DESTINO := "res://assets/personagens/refinado/paginas/"
const LADO := 128
const PALETA := {
	"181818": "241c24", # Contorno e olhos: posição original, contraste uniforme.
	"885848": "8b4e3b", # Sombra da pele.
	"d89878": "d58b59", # Meio-tom da pele.
	"f8d8b8": "f2c28b", # Luz da pele.
	"f8f8f8": "fff1d3", # Brilho dos olhos.
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	var manifesto := {}
	for pagina in Padrao.CORPOS:
		var caminho_molde: String = "res://assets/personagens/"+Padrao.CORPOS[pagina]
		var molde := Image.load_from_file(caminho_molde)
		if molde == null:
			push_error("Página ausente: "+pagina)
			quit(1)
			return
		molde.convert(Image.FORMAT_RGBA8)
		var folha := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
		for y in molde.get_height():
			for x in molde.get_width():
				var antigo := molde.get_pixel(x,y)
				if antigo.a < 0.5:
					continue
				var chave := antigo.to_html(false)
				if not PALETA.has(chave):
					push_error("Cor sem acabamento em %s: %s" % [pagina,chave])
					quit(1)
					return
				var cor := Color(PALETA[chave])
				for sy in 2:
					for sx in 2:
						var detalhe := cor
						# Suaviza a transição interna entre tons de pele em meio pixel.
						# Nunca altera contorno, olho, brilho ou borda transparente.
						if chave in ["885848","d89878","f8d8b8"]:
							var vizinho_y := y-1 if sy == 0 else y+1
							if vizinho_y >= 0 and vizinho_y < molde.get_height() and vizinho_y/64 == y/64:
								var vizinho := molde.get_pixel(x,vizinho_y)
								var tom := vizinho.to_html(false)
								if vizinho.a >= 0.5 and tom in ["885848","d89878","f8d8b8"] and tom != chave:
									detalhe = cor.lerp(Color(PALETA[tom]),0.18)
						folha.set_pixel(x*2+sx,y*2+sy,detalhe)
		var caminho: String = DESTINO+pagina+".png"
		folha.save_png(caminho)
		manifesto[pagina] = {"folha":caminho,"molde":caminho_molde,"grade":[8,8],"quadro":[LADO,LADO],"escala":0.5,"acabamento":"paleta_nativa_v2"}
		print("Página refinada: ",pagina)
	var arquivo := FileAccess.open("res://assets/personagens/refinado/manifesto.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(manifesto,"\t")+"\n")
	quit()
