extends SceneTree
# Converte as folhas dos goblins renderizados em 3D para pixel art no tamanho do
# pixel do mundo (um bloco da folha = ~1 px na tela do jogo), com paleta
# reduzida e contorno escuro, para combinar com os monstros 2D.
#
# Lê as folhas originais de arte/fontes/inimigos/goblins_hd/ e grava em
# assets/inimigos/ com o mesmo tamanho e a mesma grade de células, então
# animacoes.tres, pivôs e escalas continuam valendo.
#
# flatpak run org.godotengine.Godot --headless --path . --script res://ferramentas/inimigos/pixelizar_goblins.gd

const FONTE := "res://arte/fontes/inimigos/goblins_hd/"
const DESTINO := "res://assets/inimigos/"
# pasta, célula da folha, bloco (≈ 1 px do mundo; 2 px deixou os goblins ilegíveis), cores da paleta
const CONJUNTOS := [
	["goblin_adaga", 640, 14, 18],
	["goblin_machado_2d", 640, 14, 18],
	["goblins_moinho/lanceiro", 256, 4, 18],
	["lorde_goblin_2d", 640, 5, 26],
]
const SATURACAO := 1.18
const CONTRASTE := 1.08
const COR_CONTORNO := Color("1b1220")

func _initialize() -> void:
	for conjunto in CONJUNTOS:
		_converter(conjunto[0], conjunto[1], conjunto[2], conjunto[3])
	_zerar_ganhos_lorde()
	quit()

func _converter(pasta:String, celula:int, bloco:int, cores:int) -> void:
	var origem := ProjectSettings.globalize_path(FONTE+pasta+"/")
	var ganhos := _ganhos_lorde(origem) if pasta=="lorde_goblin_2d" else {}
	var arquivos := Array(DirAccess.get_files_at(origem)).filter(func(a:String): return a.ends_with(".png") and not a.begins_with("modelo"))
	var lado := ceili(float(celula)/bloco)
	# 1ª passada: reduz cada célula ao pixel do mundo.
	var folhas := {}
	var amostras := PackedColorArray()
	for arquivo in arquivos:
		var img := Image.load_from_file(origem+arquivo)
		img.convert(Image.FORMAT_RGBA8)
		var celulas := []
		for cy in img.get_height()/celula:
			for cx in img.get_width()/celula:
				var regiao := img.get_region(Rect2i(cx*celula,cy*celula,celula,celula))
				if ganhos.has(arquivo) and celulas.size()<ganhos[arquivo].size():
					_aplicar_ganho(regiao,ganhos[arquivo][celulas.size()])
				var pequena := _reduzir(regiao,lado,bloco)
				celulas.append(pequena)
				for y in lado:
					for x in lado:
						var c := pequena.get_pixel(x,y)
						if c.a>0.0 and (x+y)%2==0: amostras.append(c)
		folhas[arquivo] = {"tamanho":img.get_size(),"celulas":celulas}
	var paleta := _paleta(amostras,cores)
	# 2ª passada: paleta, contorno e ampliação de volta ao tamanho da folha.
	for arquivo in folhas:
		var dados:Dictionary = folhas[arquivo]
		var tamanho:Vector2i = dados.tamanho
		var saida := Image.create_empty(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
		var colunas := tamanho.x/celula
		for i in dados.celulas.size():
			var pequena:Image = dados.celulas[i]
			_quantizar(pequena,paleta)
			_contornar(pequena)
			pequena.resize(lado*bloco,lado*bloco,Image.INTERPOLATE_NEAREST)
			saida.blit_rect(pequena,Rect2i(0,0,celula,celula),Vector2i((i%colunas)*celula,(i/colunas)*celula))
		saida.save_png(DESTINO+pasta+"/"+arquivo)
	print("OK ",pasta," ",folhas.size()," folhas, ",paleta.size()," cores")

func _reduzir(regiao:Image, lado:int, bloco:int) -> Image:
	var base := Image.create_empty(lado*bloco,lado*bloco,false,Image.FORMAT_RGBA8)
	base.blit_rect(regiao,Rect2i(Vector2i.ZERO,regiao.get_size()),Vector2i.ZERO)
	base.premultiply_alpha()
	base.resize(lado,lado,Image.INTERPOLATE_TRILINEAR)
	for y in lado:
		for x in lado:
			var c := base.get_pixel(x,y)
			if c.a<0.5:
				base.set_pixel(x,y,Color(0,0,0,0))
				continue
			c = Color(c.r/c.a,c.g/c.a,c.b/c.a,1.0)
			var h := c.h; var s := c.s; var v := c.v
			c = Color.from_hsv(h,clampf(s*SATURACAO,0,1),clampf((v-0.5)*CONTRASTE+0.5,0,1))
			base.set_pixel(x,y,c)
	return base

func _paleta(amostras:PackedColorArray, cores:int) -> PackedColorArray:
	# k-means simples, começando de amostras espalhadas pelo brilho.
	var ordenadas := Array(amostras)
	ordenadas.sort_custom(func(a:Color,b:Color): return a.get_luminance()<b.get_luminance())
	var centros := PackedColorArray()
	for k in cores: centros.append(ordenadas[int((k+0.5)*ordenadas.size()/cores)])
	for volta in 10:
		var somas := []
		var contagens := PackedInt32Array()
		for k in centros.size():
			somas.append(Vector3.ZERO); contagens.append(0)
		for c in amostras:
			var k := _mais_proxima(c,centros)
			somas[k] += Vector3(c.r,c.g,c.b); contagens[k] += 1
		for k in centros.size():
			if contagens[k]>0:
				var m:Vector3 = somas[k]/contagens[k]
				centros[k] = Color(m.x,m.y,m.z)
	return centros

func _mais_proxima(c:Color, paleta:PackedColorArray) -> int:
	var melhor := 0
	var menor := INF
	for k in paleta.size():
		var p := paleta[k]
		var d := (c.r-p.r)*(c.r-p.r)*0.3+(c.g-p.g)*(c.g-p.g)*0.59+(c.b-p.b)*(c.b-p.b)*0.11
		if d<menor: menor=d; melhor=k
	return melhor

func _quantizar(img:Image, paleta:PackedColorArray) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			if c.a>0.0: img.set_pixel(x,y,paleta[_mais_proxima(c,paleta)])

func _contornar(img:Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	var bordas := []
	for y in h:
		for x in w:
			if img.get_pixel(x,y).a>0.0: continue
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var p:Vector2i = Vector2i(x,y)+d
				if p.x>=0 and p.y>=0 and p.x<w and p.y<h and img.get_pixel(p.x,p.y).a>0.0:
					bordas.append([Vector2i(x,y),img.get_pixel(p.x,p.y)])
					break
	for b in bordas:
		img.set_pixelv(b[0],COR_CONTORNO.lerp(b[1],0.18))

# O Lorde tinha um shader que igualava o tom do couro e do manto entre quadros
# (lorde_goblin_paleta.gdshader). O ganho entra na folha e o JSON fica neutro.
func _ganhos_lorde(origem:String) -> Dictionary:
	var dados:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(origem+"boss_direcoes.json"))
	var ganhos := {}
	for id in dados:
		var d:Dictionary = dados[id]
		for parte in [d, d.get("andada",{})]:
			if parte.has("textura"):
				var lista := []
				for i in parte.ganhos_couro.size(): lista.append([parte.ganhos_couro[i],parte.ganhos_manto[i]])
				ganhos[String(parte.textura).get_file()] = lista
	return ganhos

func _aplicar_ganho(img:Image, ganho:Array) -> void:
	var couro := Vector3(ganho[0][0],ganho[0][1],ganho[0][2])
	var manto := Vector3(ganho[1][0],ganho[1][1],ganho[1][2])
	if couro.is_equal_approx(Vector3.ONE) and manto.is_equal_approx(Vector3.ONE): return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			if c.a<=0.0: continue
			var v := Vector3(c.r,c.g,c.b)
			var m_couro := smoothstep(1.08,1.25,v.x/maxf(v.y,0.001))*(1.0-smoothstep(0.88,1.0,v.z/maxf(v.y,0.001)))
			var m_manto := smoothstep(1.03,1.18,v.y/maxf(v.x,0.001))*smoothstep(0.85,0.96,v.z/maxf(v.y,0.001))
			v *= Vector3.ONE.lerp(couro,m_couro)*Vector3.ONE.lerp(manto,m_manto)
			img.set_pixel(x,y,Color(v.x,v.y,v.z,c.a))

func _zerar_ganhos_lorde() -> void:
	var caminho := DESTINO+"lorde_goblin_2d/boss_direcoes.json"
	var dados:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONTE+"lorde_goblin_2d/boss_direcoes.json"))
	for id in dados:
		for parte in [dados[id], dados[id].get("andada",{})]:
			for chave in ["ganhos_couro","ganhos_manto"]:
				if parte.has(chave): parte[chave] = parte[chave].map(func(_g): return [1.0,1.0,1.0])
	var arquivo := FileAccess.open(caminho,FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(_inteiros(dados),"\t"))

# JSON.parse_string devolve tudo em float; colunas e quadros voltam a ser inteiros.
func _inteiros(valor:Variant, chave:String = "") -> Variant:
	if valor is Dictionary:
		var saida := {}
		for k in valor: saida[k] = _inteiros(valor[k], k)
		return saida
	if valor is Array: return valor.map(func(v): return _inteiros(v, chave))
	if valor is float and not chave.begins_with("ganhos") and valor==floorf(valor): return int(valor)
	return valor
