@tool
extends Node3D
## Geometria fundida por material; peças e cenas conservam pivôs independentes.
var _superficies: Dictionary = {}
var _instancias: Dictionary = {}
static var _materiais: Dictionary = {}
static var _pinturas: Dictionary = {}
var triangulos := 0

func _superficie(tipo: String) -> SurfaceTool:
	if not _superficies.has(tipo):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_superficies[tipo] = st
	return _superficies[tipo]

func _triangulo(a: Vector3, b: Vector3, c: Vector3, tipo: String, cor := Color.WHITE, uvs := PackedVector2Array()) -> void:
	var st := _superficie(tipo)
	var pontos := [a, b, c]
	for i in 3:
		st.set_color(cor)
		st.set_uv(uvs[i] if uvs.size() == 3 else Vector2(pontos[i].x, pontos[i].y))
		st.add_vertex(pontos[i])
	triangulos += 1

func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tipo: String, cor := Color.WHITE) -> void:
	var uv := PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	if tipo.begins_with("madeira"):
		var largura_face := a.distance_to(b)
		var altura_face := b.distance_to(c)
		var origem := Vector2(fposmod(a.x*0.31+a.z*0.37,0.73),fposmod(a.y*0.13,0.7))
		for i in 4:
			var p := uv[i]
			uv[i] = origem+Vector2(p.y*altura_face*0.45,p.x*largura_face*0.42) if largura_face>altura_face else origem+Vector2(p.x*largura_face*0.45,p.y*altura_face*0.42)
	_triangulo(a,b,c,tipo,cor,PackedVector2Array([uv[0],uv[1],uv[2]]))
	_triangulo(a,c,d,tipo,cor,PackedVector2Array([uv[0],uv[2],uv[3]]))

func _caixa(tamanho: Vector3, posicao: Vector3, tipo: String, cor := Color.WHITE, base := Basis.IDENTITY) -> void:
	var v: Array[Vector3] = []
	var locais: Array[Vector3] = []
	for p in [Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1),Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1)]:
		locais.append(p*tamanho*0.5)
		v.append(posicao+base*locais[-1])
	var eixo_longo := tamanho.max_axis_index()
	var faces := [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]
	var eixos := [2,2,0,0,1,1]
	for j in faces.size():
		var f: Array = faces[j]
		if not tipo.begins_with("madeira"):
			_face(v[f[0]],v[f[1]],v[f[2]],v[f[3]],tipo,cor)
		elif eixos[j] == eixo_longo:
			_face(v[f[0]],v[f[1]],v[f[2]],v[f[3]],"cerne",cor*(Color("987b58") if tipo == "madeira_escura" else Color.WHITE))
		else:
			# Os veios acompanham a peça mesmo quando a viga está inclinada.
			var eixo_curto: int = 3-eixo_longo-int(eixos[j])
			var origem := Vector2(fposmod(posicao.x*0.31+posicao.z*0.37,0.73),fposmod(posicao.y*0.13,0.7))
			var uv := PackedVector2Array()
			for i in 4: uv.append(origem+Vector2(locais[f[i]][eixo_curto]*0.45,locais[f[i]][eixo_longo]*0.42))
			_triangulo(v[f[0]],v[f[1]],v[f[2]],tipo,cor,PackedVector2Array([uv[0],uv[1],uv[2]]))
			_triangulo(v[f[0]],v[f[2]],v[f[3]],tipo,cor,PackedVector2Array([uv[0],uv[2],uv[3]]))

func _viga(a: Vector3, b: Vector3, espessura: float, tipo := "madeira", cor := Color.WHITE) -> void:
	_caixa(Vector3(espessura,a.distance_to(b),espessura),(a+b)*0.5,tipo,cor,Basis(Quaternion(Vector3.UP,(b-a).normalized())))

func _cilindro(posicao: Vector3, raio: float, altura: float, tipo: String, cor := Color.WHITE, segmentos := 12, raio_topo := -1.0) -> void:
	var rt := raio if raio_topo < 0 else raio_topo
	for i in segmentos:
		var a := TAU*i/segmentos
		var b := TAU*(i+1)/segmentos
		var p0 := posicao+Vector3(cos(a)*raio,0,sin(a)*raio)
		var p1 := posicao+Vector3(cos(b)*raio,0,sin(b)*raio)
		var p2 := posicao+Vector3(cos(b)*rt,altura,sin(b)*rt)
		var p3 := posicao+Vector3(cos(a)*rt,altura,sin(a)*rt)
		_face(p1,p0,p3,p2,tipo,cor)
		_triangulo(posicao+Vector3.UP*altura,p2,p3,tipo,cor)
		_triangulo(posicao,p0,p1,tipo,cor)

func _anel(posicao: Vector3, externo: float, interno: float, altura: float, tipo: String, segmentos := 12) -> void:
	for i in segmentos:
		var a := TAU*i/segmentos
		var b := TAU*(i+1)/segmentos
		var p0 := posicao+Vector3(cos(a)*externo,0,sin(a)*externo)
		var p1 := posicao+Vector3(cos(b)*externo,0,sin(b)*externo)
		var p2 := posicao+Vector3(cos(b)*interno,0,sin(b)*interno)
		var p3 := posicao+Vector3(cos(a)*interno,0,sin(a)*interno)
		_face(p1,p0,p0+Vector3.UP*altura,p1+Vector3.UP*altura,tipo)
		_face(p3,p2,p2+Vector3.UP*altura,p3+Vector3.UP*altura,tipo)
		_face(p0+Vector3.UP*altura,p3+Vector3.UP*altura,p2+Vector3.UP*altura,p1+Vector3.UP*altura,tipo)

func _extrudar_xy(pontos: PackedVector2Array, z: float, profundidade: float, tipo: String, cor := Color.WHITE) -> void:
	var indices := Geometry2D.triangulate_polygon(pontos)
	for i in range(0,indices.size(),3):
		var a := pontos[indices[i]]
		var b := pontos[indices[i+1]]
		var c := pontos[indices[i+2]]
		_triangulo(Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),tipo,cor)
		_triangulo(Vector3(c.x,c.y,z-profundidade),Vector3(b.x,b.y,z-profundidade),Vector3(a.x,a.y,z-profundidade),tipo,cor)
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i+1)%pontos.size()]
		_face(Vector3(a.x,a.y,z),Vector3(a.x,a.y,z-profundidade),Vector3(b.x,b.y,z-profundidade),Vector3(b.x,b.y,z),tipo,cor)

func _finalizar() -> void:
	for tipo in _superficies:
		var st: SurfaceTool = _superficies[tipo]
		st.generate_normals()
		var instancia := MeshInstance3D.new()
		instancia.name = str(tipo).to_pascal_case()
		instancia.mesh = st.commit()
		instancia.material_override = _material(tipo,0)
		add_child(instancia)
		_instancias[tipo] = instancia
	_superficies.clear()

func _extrudar_biselado_xy(pontos: PackedVector2Array, z: float, profundidade: float, tipo: String, cor := Color.WHITE, bisel := 0.022) -> void:
	var centro := Vector2.ZERO
	for p in pontos: centro += p
	centro /= pontos.size()
	var internos := PackedVector2Array()
	for p in pontos: internos.append(p+(centro-p).normalized()*minf(bisel,p.distance_to(centro)*0.24))
	_extrudar_xy(pontos,z-bisel,profundidade-bisel,tipo,cor)
	var indices := Geometry2D.triangulate_polygon(internos)
	for i in range(0,indices.size(),3):
		var a := internos[indices[i]]
		var b := internos[indices[i+1]]
		var c := internos[indices[i+2]]
		_triangulo(Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),tipo,cor)
	for i in pontos.size():
		var j := (i+1)%pontos.size()
		_face(Vector3(pontos[i].x,pontos[i].y,z-bisel),Vector3(pontos[j].x,pontos[j].y,z-bisel),Vector3(internos[j].x,internos[j].y,z),Vector3(internos[i].x,internos[i].y,z),tipo,cor.lightened(0.07))

func _rebite(p: Vector3, raio := 0.028) -> void:
	var pontos := PackedVector2Array()
	for i in 8: pontos.append(Vector2(p.x+cos(TAU*i/8.0)*raio,p.y+sin(TAU*i/8.0)*raio))
	_extrudar_xy(pontos,p.z+0.018,0.028,"metal_claro")

func _ferragem(p: Vector3, tamanho := Vector2(0.13,0.15)) -> void:
	var hx := tamanho.x*0.5
	var hy := tamanho.y*0.5
	var corte := 0.018
	var pontos := PackedVector2Array([Vector2(-hx+corte,-hy),Vector2(hx-corte,-hy),Vector2(hx,-hy+corte),Vector2(hx,hy-corte),Vector2(hx-corte,hy),Vector2(-hx+corte,hy),Vector2(-hx,hy-corte),Vector2(-hx,-hy+corte)])
	for i in pontos.size(): pontos[i] += Vector2(p.x,p.y)
	_extrudar_xy(pontos,p.z,0.026,"ferro_escuro")
	_rebite(p)

func definir_estacao(estacao: int) -> void:
	for tipo in _instancias:
		_instancias[tipo].material_override = _material(tipo,estacao)
		if tipo == "neve": _instancias[tipo].visible = estacao == 3

static func _material(tipo: String, estacao: int) -> StandardMaterial3D:
	var chave := "%s:%d" % [tipo,estacao]
	if _materiais.has(chave): return _materiais[chave]
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var cores := {"madeira":"a77948","madeira_escura":"62432d","pedra":"aaa08b","pedra_escura":"6a6961","junta":"4e4c46","metal":"60656a","ferro_escuro":"363d43","ouro":"c79a40","telha":"ce6236","telha_borda":"c65b31","fundo":"201c1b","carvao":"342c29","brasa":"eb6b1f","fogo":"ffd154","neve":"e8eceb","vidro":"e9ab45","folha":"557b3d","flor":"de8cb7","cerne":"c99d62","cerne_escuro":"9e733f","metal_claro":"929b9e","cantaria":"e0d8c8"}
	mat.albedo_color = Color(cores.get(tipo,"ffffff"))
	if tipo in ["madeira","madeira_escura","pedra","pedra_escura","cantaria","telha"]:
		mat.albedo_texture = _pintura(tipo)
		mat.albedo_color = Color.WHITE if tipo in ["madeira","pedra","telha","telha_borda","cantaria"] else mat.albedo_color.lightened(0.08)
		if tipo in ["pedra","pedra_escura","cantaria"]:
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE*0.7
	if tipo in ["fogo","brasa","vidro"]:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.7 if tipo == "fogo" else 0.25
	if estacao == 3 and tipo in ["telha","telha_borda","pedra","madeira"]:
		mat.albedo_color = mat.albedo_color.lerp(Color("d9e0e2"),0.12)
	elif estacao in [1,2] and tipo in ["telha","telha_borda","pedra","madeira","madeira_escura"]:
		mat.albedo_color *= Color("fff5e8") if estacao == 1 else Color("efd9bc")
	if tipo == "neve": mat.albedo_color = Color("aebbc0")
	if tipo == "folha": mat.albedo_color = [Color("557b3d"),Color("607b39"),Color("a27435"),Color("8c9386")][estacao]
	if tipo == "flor": mat.albedo_color = [Color("de8cb7"),Color("deb85c"),Color("b76e3c"),Color("d9dedc")][estacao]
	_materiais[chave] = mat
	return mat

static func _pintura(tipo: String) -> Texture2D:
	var categoria := "cantaria" if tipo == "cantaria" else ("madeira" if tipo.begins_with("madeira") else ("pedra" if tipo.begins_with("pedra") else "telha"))
	if _pinturas.has(categoria): return _pinturas[categoria]
	var imagem: Image
	if categoria == "madeira":
		imagem = (load("res://assets/cenario/campanha/moinho_lowpoly/pinturas_pixel_art/madeira.png") as Texture2D).get_image()
	else:
		var atlas := (load("res://assets/cenario/campanha/moinho_lowpoly/pinturas_pixel_art/telhado_pedra_atlas.png") as Texture2D).get_image()
		var painel := atlas.get_width()/2
		# A malha já cria as juntas e os relevos das telhas: a pintura contém só o interior da cerâmica.
		imagem = atlas.get_region(Rect2i(painel,0,painel,atlas.get_height())) if categoria == "pedra" else atlas.get_region(Rect2i(180,200,82,65))
		if categoria == "cantaria": imagem = atlas.get_region(Rect2i(950,55,80,60))
	imagem.resize(64,64,Image.INTERPOLATE_NEAREST)
	if categoria == "madeira":
		for y in imagem.get_height():
			for x in imagem.get_width():
				imagem.set_pixel(x,y,imagem.get_pixel(x,y).lerp(Color("ad7c46"),0.23))
	if categoria in ["pedra","cantaria"]:
		# Retém os agrupamentos pintados do moinho, com argamassa seca da oficina.
		for y in imagem.get_height():
			for x in imagem.get_width():
				var c := imagem.get_pixel(x,y)
				var v := c.get_luminance()
				imagem.set_pixel(x,y,Color(v*1.08,v*1.03,v*0.94,c.a))
	var tex := ImageTexture.create_from_image(imagem)
	_pinturas[categoria] = tex
	return tex

func _telhado(centro: Vector3, largura_cumeeira: float, meia_agua: float, altura: float, frontal: bool) -> void:
	var colunas := ceili(largura_cumeeira/0.235)
	var fileiras := ceili(sqrt(meia_agua*meia_agua+altura*altura)/0.26)
	var passo_x := largura_cumeeira/colunas
	for lado in [-1.0,1.0]:
		for fileira in fileiras:
			var t0 := float(fileira)/fileiras
			var t1 := minf(1.04,float(fileira+1)/fileiras+0.025)
			for coluna in colunas:
				var x0 := -largura_cumeeira*0.5+coluna*passo_x
				var cor := Color.WHITE.darkened(float((coluna*7+fileira*3)%5)*0.022)
				for segmento in 4:
					var s0 := float(segmento)/4.0
					var s1 := float(segmento+1)/4.0
					var p0 := Vector3(x0+passo_x*s0,altura*(1-t0)+sin(PI*s0)*0.026,lado*meia_agua*t0)
					var p1 := Vector3(x0+passo_x*s1,altura*(1-t0)+sin(PI*s1)*0.026,lado*meia_agua*t0)
					var p2 := Vector3(x0+passo_x*s1,altura*(1-t1)+sin(PI*s1)*0.026,lado*meia_agua*t1)
					var p3 := Vector3(x0+passo_x*s0,altura*(1-t1)+sin(PI*s0)*0.026,lado*meia_agua*t1)
					if frontal:
						p0 = Vector3(p0.z,p0.y,p0.x)
						p1 = Vector3(p1.z,p1.y,p1.x)
						p2 = Vector3(p2.z,p2.y,p2.x)
						p3 = Vector3(p3.z,p3.y,p3.x)
					_triangulo(centro+p0,centro+p1,centro+p2,"telha",cor,PackedVector2Array([Vector2(s0,0),Vector2(s1,0),Vector2(s1,1)]))
					_triangulo(centro+p0,centro+p2,centro+p3,"telha",cor,PackedVector2Array([Vector2(s0,0),Vector2(s1,1),Vector2(s0,1)]))
					_face(centro+p3,centro+p2,centro+p2-Vector3.UP*0.035,centro+p3-Vector3.UP*0.035,"telha_borda",cor.darkened(0.14))
					if fileira == 0 or fileira == fileiras-1:
						var inicio_neve := 0.0 if fileira == 0 else 0.72-float(coluna%3)*0.045
						var fim_neve := 0.19+float(coluna%3)*0.05 if fileira == 0 else 1.0
						_face(centro+p0.lerp(p3,inicio_neve)+Vector3.UP*0.025,centro+p1.lerp(p2,inicio_neve)+Vector3.UP*0.025,centro+p1.lerp(p2,fim_neve)+Vector3.UP*0.025,centro+p0.lerp(p3,fim_neve)+Vector3.UP*0.025,"neve")
	# Cumeeira em pequenas capas, apoiadas na junção das duas águas.
	for i in colunas:
		var x := -largura_cumeeira*0.5+(i+0.5)*passo_x
		var pos := centro+Vector3(0,altura+0.02,x) if frontal else centro+Vector3(x,altura+0.02,0)
		_capa_cumeeira(pos,passo_x+0.01,frontal)
	# Vigas sob as bordas sustentam os panos do telhado.
	for lado in [-1.0,1.0]:
		var a := Vector3(-largura_cumeeira*0.5,-0.025,lado*meia_agua)
		var b := Vector3(largura_cumeeira*0.5,-0.025,lado*meia_agua)
		if frontal:
			a = Vector3(a.z,a.y,a.x)
			b = Vector3(b.z,b.y,b.x)
		_viga(centro+a,centro+b,0.11,"madeira_escura")

func _capa_cumeeira(centro: Vector3, comprimento: float, frontal: bool) -> void:
	for i in 6:
		var a := PI*i/6.0
		var b := PI*(i+1)/6.0
		var pontos: Array[Vector3] = [Vector3(-comprimento*0.5,sin(a)*0.085,cos(a)*0.085),Vector3(comprimento*0.5,sin(a)*0.085,cos(a)*0.085),Vector3(comprimento*0.5,sin(b)*0.085,cos(b)*0.085),Vector3(-comprimento*0.5,sin(b)*0.085,cos(b)*0.085)]
		for j in 4:
			if frontal: pontos[j] = Vector3(pontos[j].z,pontos[j].y,pontos[j].x)
			pontos[j] += centro
		_face(pontos[0],pontos[1],pontos[2],pontos[3],"telha")
		if i in [2,3]: _face(pontos[0]+Vector3.UP*0.015,pontos[1]+Vector3.UP*0.015,pontos[2]+Vector3.UP*0.015,pontos[3]+Vector3.UP*0.015,"neve")
		# Lábio cerâmico em cada ponta da capa curva.
		for lado in [-1.0,1.0]:
			var p0 := Vector3(lado*comprimento*0.5,sin(a)*0.085,cos(a)*0.085)
			var p1 := Vector3(lado*comprimento*0.5,sin(b)*0.085,cos(b)*0.085)
			var p2 := Vector3(lado*comprimento*0.5,sin(b)*0.061,cos(b)*0.061)
			var p3 := Vector3(lado*comprimento*0.5,sin(a)*0.061,cos(a)*0.061)
			if frontal:
				p0 = Vector3(p0.z,p0.y,p0.x)
				p1 = Vector3(p1.z,p1.y,p1.x)
				p2 = Vector3(p2.z,p2.y,p2.x)
				p3 = Vector3(p3.z,p3.y,p3.x)
			_face(centro+p0,centro+p1,centro+p2,centro+p3,"telha_borda")

