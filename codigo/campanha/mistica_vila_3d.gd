@tool
extends "res://codigo/campanha/mistica_malha_3d.gd"
## Fachada, torre e trepadeiras têm volume próprio; placa e jardim ficam em cenas separadas.

func _ready() -> void:
	_paredes()
	_porta()
	for x in [-1.12,1.12]: _janela(x)
	_telhado_feiticeira(Vector3(0,2.02,-0.48),3.75,0.96,0.76,false)
	_telhado_feiticeira(Vector3(0,2.10,0.16),2.55,1.30,1.58,true)
	_frontao()
	_torre()
	_trepadeiras()
	_finalizar()
	definir_estacao(0)

func _telhado_feiticeira(centro: Vector3, largura: float, agua: float, altura: float, frontal: bool) -> void:
	# Escamas arredondadas da referência: cada borda sobrepõe a fileira inferior.
	var colunas := ceili(largura/0.25)
	var linhas := ceili(Vector2(agua,altura).length()/0.28)
	var passo := largura/colunas
	var contorno := PackedVector2Array([Vector2(-0.5,0),Vector2(0.5,0),Vector2(0.5,0.78),Vector2(0.39,0.97),Vector2(0.0,1.04),Vector2(-0.39,0.97),Vector2(-0.5,0.78)])
	for lado in [-1.0,1.0]:
		for linha in linhas:
			for coluna in colunas:
				var pontos: Array[Vector3] = []
				var u := -largura*0.5+(coluna+0.5)*passo
				for p in contorno:
					var t: float = (linha+p.y)/linhas
					var local := Vector3(u+p.x*passo,altura*(1-t)+0.025+p.y*0.04,lado*agua*t)
					if frontal: local = Vector3(local.z,local.y,local.x)
					pontos.append(centro+local)
				var cor := Color.WHITE.darkened(float((coluna*7+linha*11)%5)*0.026)
				for i in range(1,pontos.size()-1):
					_triangulo(pontos[0],pontos[i],pontos[i+1],"telha",cor,PackedVector2Array([contorno[0],contorno[i],contorno[i+1]]))
				for i in pontos.size():
					var j := (i+1)%pontos.size()
					_face(pontos[i],pontos[j],pontos[j]-Vector3.UP*0.045,pontos[i]-Vector3.UP*0.045,"telha_borda",cor)
				if linha in [0,linhas-1]:
					var a := pontos[0].lerp(pontos[6],0.22 if linha == 0 else 0.84)+Vector3.UP*0.027
					var b := pontos[1].lerp(pontos[2],0.22 if linha == 0 else 0.84)+Vector3.UP*0.027
					var c := pontos[3]+Vector3.UP*0.027
					var d := pontos[5]+Vector3.UP*0.027
					if linha == 0:
						c = pontos[1]+Vector3.UP*0.027
						d = pontos[0]+Vector3.UP*0.027
					_face(a,b,c,d,"neve")
	for i in colunas:
		var u := -largura*0.5+(i+0.5)*passo
		_capa_cumeeira(centro+(Vector3(0,altura+0.045,u) if frontal else Vector3(u,altura+0.045,0)),passo+0.01,frontal)
	for lado in [-1.0,1.0]:
		var a := Vector3(-largura*0.5,0,lado*agua)
		var b := Vector3(largura*0.5,0,lado*agua)
		if frontal:
			a = Vector3(a.z,a.y,a.x)
			b = Vector3(b.z,b.y,b.x)
		_viga(centro+a,centro+b,0.12,"madeira_escura")

func _paredes() -> void:
	# Vãos reais: laterais, verga e tímpano fecham em torno da porta e das janelas.
	_caixa(Vector3(3.34,1.96,0.16),Vector3(0,1.10,-0.88),"reboco")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.17,1.96,1.76),Vector3(lado*1.62,1.10,-0.04),"reboco")
		_caixa(Vector3(0.24,1.85,0.18),Vector3(lado*0.64,1.10,0.88),"madeira")
		_caixa(Vector3(0.17,1.99,0.20),Vector3(lado*1.66,1.08,0.84),"madeira_escura")
		_caixa(Vector3(0.22,1.80,0.18),Vector3(lado*1.48,1.11,0.85),"reboco")
		_caixa(Vector3(0.20,1.80,0.18),Vector3(lado*0.78,1.11,0.85),"reboco")
		_caixa(Vector3(0.61,0.48,0.17),Vector3(lado*1.12,0.43,0.85),"reboco")
		_caixa(Vector3(0.61,0.61,0.17),Vector3(lado*1.12,1.76,0.85),"reboco")
		_caixa(Vector3(0.24,0.22,0.24),Vector3(lado*0.64,0.22,0.88),"cantaria")
		_ferragem(Vector3(lado*0.64,1.94,1.01),Vector2(0.17,0.16))
	_caixa(Vector3(1.12,0.38,0.18),Vector3(0,1.92,0.86),"reboco")
	_caixa(Vector3(3.46,0.17,0.25),Vector3(0,2.06,0.90),"madeira")
	_caixa(Vector3(3.45,0.14,1.97),Vector3(0,0.13,-0.03),"pedra_escura")
	for lado in [-1.0,1.0]:
		for i in 5: _caixa(Vector3(0.21,0.13,0.14),Vector3(lado*(0.77+i*0.19),0.25,0.96),"cantaria",Color.WHITE.darkened(float(i%2)*0.04))
	for i in 3:
		_caixa(Vector3(1.06+i*0.08,0.105,0.30),Vector3(0,0.26-i*0.085,1.05+i*0.23),"cantaria")
		_caixa(Vector3(1.07+i*0.08,0.028,0.09),Vector3(0,0.328-i*0.085,1.16+i*0.23),"neve")

func _arco(x: float, base: float, raio: float, espessura: float, z: float, tipo: String) -> void:
	for i in 9:
		var a := PI*i/9.0+0.018
		var b := PI*(i+1)/9.0-0.018
		var contorno := PackedVector2Array([Vector2(x+cos(a)*(raio+espessura),base+sin(a)*(raio+espessura)),Vector2(x+cos(b)*(raio+espessura),base+sin(b)*(raio+espessura)),Vector2(x+cos(b)*raio,base+sin(b)*raio),Vector2(x+cos(a)*raio,base+sin(a)*raio)])
		_extrudar_biselado_xy(contorno,z,0.18,tipo,Color.WHITE.lightened(float(i%3)*0.025),0.013)

func _porta() -> void:
	var forma := PackedVector2Array([Vector2(-0.43,0.31),Vector2(0.43,0.31),Vector2(0.43,1.18)])
	for i in range(1,13): forma.append(Vector2(cos(PI*i/12.0)*0.43,1.18+sin(PI*i/12.0)*0.43))
	_extrudar_xy(forma,0.84,0.13,"madeira_escura")
	for i in 7:
		var x := -0.36+i*0.12
		var altura := 1.18+sqrt(maxf(0,0.43*0.43-x*x))-0.33
		_caixa(Vector3(0.111,altura,0.055),Vector3(x,0.33+altura*0.5,0.883),"madeira",Color("d1b2c6").darkened(float(i%3)*0.035))
	_arco(0,1.18,0.45,0.18,1.045,"ametista")
	for lado in [-1.0,1.0]:
		for i in 4: _caixa(Vector3(0.17,0.21,0.18),Vector3(lado*0.535,0.41+i*0.213,0.96),"ametista",Color.WHITE.lightened(float(i%2)*0.065))
	for y in [0.57,1.05]:
		_caixa(Vector3(0.25,0.045,0.036),Vector3(0.26,y,0.93),"ferro_escuro")
		for x in [0.17,0.34]: _rebite(Vector3(x,y,0.955),0.015)
	_gema_da_porta()
	_argola_xy(Vector3(-0.24,0.83,0.95),0.049)

func _gema_da_porta() -> void:
	var p := Vector3(0,1.28,0.96)
	var contorno := PackedVector2Array([Vector2(-0.08,0),Vector2(0,-0.12),Vector2(0.08,0),Vector2(0,0.12)])
	for i in contorno.size(): contorno[i] += Vector2(p.x,p.y)
	_extrudar_biselado_xy(contorno,p.z,0.035,"ouro")
	for i in contorno.size(): contorno[i] = Vector2(p.x,p.y)+(contorno[i]-Vector2(p.x,p.y))*0.71
	_extrudar_biselado_xy(contorno,p.z+0.025,0.03,"gema",Color.WHITE,0.018)

func _argola_xy(p: Vector3, raio: float) -> void:
	for i in 12:
		var a := TAU*i/12.0
		var b := TAU*(i+1)/12.0
		_face(p+Vector3(cos(a),sin(a),0)*raio,p+Vector3(cos(b),sin(b),0)*raio,p+Vector3(cos(b),sin(b),0)*raio*0.63,p+Vector3(cos(a),sin(a),0)*raio*0.63,"ouro")

func _janela(x: float) -> void:
	var forma := PackedVector2Array([Vector2(x-0.245,0.69),Vector2(x+0.245,0.69),Vector2(x+0.245,1.07)])
	for i in range(1,9): forma.append(Vector2(x+cos(PI*i/8.0)*0.245,1.07+sin(PI*i/8.0)*0.245))
	_extrudar_xy(forma,0.86,0.09,"vidro")
	_arco(x,1.07,0.25,0.105,0.99,"cantaria")
	for lado in [-1.0,1.0]: _caixa(Vector3(0.10,0.40,0.14),Vector3(x+lado*0.30,0.88,0.94),"cantaria")
	_caixa(Vector3(0.71,0.12,0.30),Vector3(x,0.66,0.98),"cantaria")
	_caixa(Vector3(0.045,0.64,0.05),Vector3(x,1.00,0.93),"madeira_escura")
	_caixa(Vector3(0.51,0.046,0.05),Vector3(x,1.04,0.93),"madeira_escura")
	_caixa(Vector3(0.71,0.023,0.12),Vector3(x,0.73,1.05),"neve")

func _frontao() -> void:
	_extrudar_xy(PackedVector2Array([Vector2(-1.26,2.10),Vector2(1.26,2.10),Vector2(0,3.64)]),1.01,0.15,"reboco")
	for lado in [-1.0,1.0]:
		_viga(Vector3(lado*1.31,2.11,1.15),Vector3(0,3.70,1.15),0.15,"madeira_escura")
		_viga(Vector3(lado*0.79,2.14,1.10),Vector3(lado*0.20,2.74,1.10),0.085,"madeira")
	_caixa(Vector3(0.11,0.38,0.12),Vector3(0,3.28,1.11),"madeira")
	_argola_xy(Vector3(0,2.65,1.15),0.43)
	_disco_xy(Vector3(0,2.65,1.14),0.405,"ouro")
	_disco_xy(Vector3(0,2.65,1.18),0.352,"ametista")
	_lua(Vector3(0,2.65,1.24),0.285)

func _torre() -> void:
	var p := Vector3(-1.49,1.68,0.06)
	_cilindro(p,0.27,1.43,"pedra",Color.WHITE,12)
	for i in 7: _anel(p+Vector3.UP*(0.12+i*0.20),0.276,0.261,0.02,"junta",12)
	_caixa(Vector3(0.18,0.29,0.025),p+Vector3(0,1.07,0.264),"vidro")
	for x in [-0.11,0.11]: _caixa(Vector3(0.045,0.34,0.05),p+Vector3(x,1.07,0.28),"madeira_escura")
	_caixa(Vector3(0.028,0.32,0.05),p+Vector3(0,1.07,0.30),"madeira_escura")
	for i in 7:
		var y := 1.43+i*0.145
		var raio := 0.41*(1-float(i)/7.0)+0.018
		_cilindro(p+Vector3.UP*y,raio,0.165,"telha",Color.WHITE.lightened(float(i%2)*0.05),12,maxf(0.01,raio-0.061))
		_anel(p+Vector3.UP*y,raio+0.01,raio-0.015,0.025,"telha_borda",12)
	_cilindro(p+Vector3.UP*2.46,0.085,0.15,"ouro",Color.WHITE,8,0.015)
	_cilindro(p+Vector3.UP*2.60,0.035,0.16,"ouro",Color.WHITE,8,0.0)
	_anel(p+Vector3.UP*1.43,0.43,0.35,0.035,"neve",12)

func _trepadeiras() -> void:
	for lado in [-1.0,1.0]:
		var anterior := Vector3(lado*1.54,0.25,1.02)
		for i in 15:
			var y := 0.39+i*0.17
			var x: float = lado*(1.54-maxf(0,y-2.1)*0.70)+sin(i*1.8)*0.06
			var p := Vector3(x,y,1.065)
			_viga(anterior,p,0.034,"madeira_escura")
			_folha_volume(p+Vector3(lado*0.08,0.025,0.025),Vector3(0.19,0.095,0.07),"folha",Color.WHITE.lightened(float(i%3)*0.045))
			if i%3 == 1: _cacho(p+Vector3(lado*0.07,-0.055,0.045),0.29+float(i%2)*0.09)
			anterior = p
		# Ramos sobre a cerâmica, com apoios no plano inclinado do telhado frontal.
		var ultimo := Vector3(lado*1.25,2.23,1.47)
		for i in 9:
			var x: float = lado*(1.24-i*0.078)
			var y := 2.10+1.58*(1-absf(x)/1.30)+0.06
			var p := Vector3(x,y,1.47)
			_viga(ultimo,p,0.03,"madeira_escura")
			for sentido in [-1.0,1.0]: _folha_volume(p+Vector3(sentido*0.06,0.025,0.02),Vector3(0.16,0.085,0.075))
			if i%3 == 0: _cacho(p+Vector3(lado*0.07,-0.04,0.055),0.26)
			ultimo = p
