extends RefCounted
## Material pela raridade. Nível não repinta armas; escudos conservam seu acabamento existente.
const Visual=preload("res://codigo/dados/visual_armas.gd")
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const Paleta := preload("res://codigo/dados/paleta_raven.gd")
const RAMPAS := [
	[], # Nível 1 conserva os materiais nativos.
	["875239","c47c4c","f4c58f"], # Cobre.
	["3b638c","6eacd2","d2eef4"], # Azul.
	["916024","dfad42","fff0ac"], # Ouro.
	["623e93","a477db","e9d8ff"], # Ametista.
]
static var _materiais := {}
static var _icones := {}

static func paleta(tipo: String, nivel: int, raridade: String="comum") -> Dictionary:
	var n := clampi(nivel,1,5)
	var rampa: Array=RAMPAS[n-1] if tipo=="escudo_basico" else Visual.RAMPAS.get(raridade,[])
	if rampa.is_empty(): return {}
	var cores := {"a49a7e":rampa[0],"c9be9f":rampa[1],"f1ebd9":rampa[2]}
	if tipo.begins_with("arco_"):
		cores["4f3e2c"]=rampa[0]
		cores["745c42"]=rampa[1]
	elif tipo=="escudo_basico":
		cores["7b6554"]=rampa[1]
		cores["43382f"]=Color.html(rampa[0]).darkened(0.45).to_html(false)
	return cores

static func material(tipo: String, nivel: int, raridade: String="comum") -> ShaderMaterial:
	var n := clampi(nivel,1,5)
	if paleta(tipo,n,raridade).is_empty() or preload("res://codigo/dados/armas_montantes.gd").MODELOS.has(tipo): return Raven.material_corpo()
	var chave := tipo+":"+str(n if tipo=="escudo_basico" else 1)+":"+raridade
	if not _materiais.has(chave):
		var cores: Dictionary = Paleta.CORES.duplicate()
		cores.merge(paleta(tipo,n,raridade),true)
		var origem := PackedColorArray()
		var destino := PackedColorArray()
		for cor: String in cores:
			origem.append(Color.html(cor))
			destino.append(Color.html(cores[cor]))
		var mat := Raven.material_corpo().duplicate() as ShaderMaterial
		mat.set_shader_parameter("cores_origem",origem)
		mat.set_shader_parameter("cores_destino",destino)
		mat.set_shader_parameter("quantidade_cores",origem.size())
		_materiais[chave]=mat
	return _materiais[chave]

static func icone(tipo: String, nivel: int, raridade: String="comum") -> Texture2D:
	var n := clampi(nivel,1,5)
	var textura := Raven.carregar(Raven.RAIZ+"icones/"+tipo+".png")
	if paleta(tipo,n,raridade).is_empty(): return textura
	var chave := tipo+":"+str(n if tipo=="escudo_basico" else 1)+":"+raridade
	if not _icones.has(chave):
		var imagem: Image = textura.get_image()
		imagem.convert(Image.FORMAT_RGBA8)
		var cores := paleta(tipo,n,raridade)
		for y in imagem.get_height():
			for x in imagem.get_width():
				var pixel := imagem.get_pixel(x,y)
				var cor := pixel.to_html(false)
				if pixel.a>0 and cores.has(cor):
					var nova := Color.html(cores[cor])
					nova.a=pixel.a
					imagem.set_pixel(x,y,nova)
				elif pixel.a>0 and raridade!="comum" and (tipo=="maca" or preload("res://codigo/dados/armas_montantes.gd").MODELOS.has(tipo)):
					# Esses modelos têm paletas próprias. Tingir só o metal claro/frio;
					# conservar contorno, madeira e ferragens quentes.
					var luz:=maxf(pixel.r,maxf(pixel.g,pixel.b))
					var madeira: bool=pixel.r>pixel.g*1.12 and pixel.g>pixel.b*1.12
					if luz>.20 and not madeira:
						var tom: Color=pixel.lerp(Visual.cor_material(raridade)*luz,.64)
						tom.a=pixel.a
						imagem.set_pixel(x,y,tom)
		_icones[chave]=ImageTexture.create_from_image(imagem)
	return _icones[chave]
