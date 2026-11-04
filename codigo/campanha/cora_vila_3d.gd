@tool
extends "res://codigo/campanha/cora_malha_3d.gd"
## Fachada da família Cora na campanha: padaria em tijolos com vitrine e toldo listrado.

func _ready() -> void:
	_paredes()
	_porta()
	_vitrine()
	_toldo()
	_cobertura(Vector3(0,2.88,-0.18),5.18,1.34,0.94,false)
	_volume_central()
	_dormer()
	_chamine()
	_janela(Vector3(1.85,2.47,1.13),0.24,0.36)
	_floreira_cora(Vector3(1.85,2.02,1.28),0.75)
	_janela(Vector3(1.85,1.15,1.13),0.24,0.36)
	_placa()
	_lanterna_parede(Vector3(-0.13,1.44,1.30))
	_trepadeiras()
	_finalizar()
	definir_estacao(0)

func _paredes() -> void:
	_alvenaria(Vector3(0,1.03,-1.07),Vector2(4.65,1.72),Basis(Vector3.UP,PI))
	for lado in [-1.0,1.0]:
		_alvenaria(Vector3(lado*2.30,1.03,-0.02),Vector2(2.10,1.72),Basis(Vector3.UP,lado*PI*0.5))
		_caixa(Vector3(0.16,1.02,2.10),Vector3(lado*2.30,2.37,-0.02),"reboco_clinica")
		for z in [-1.04,1.07]: _caixa(Vector3(0.14,1.12,0.17),Vector3(lado*2.32,2.40,z),"madeira_escura")
		for y in [1.87,2.88]: _caixa(Vector3(0.19,0.13,2.26),Vector3(lado*2.32,y,-0.02),"madeira")
		# Empenas laterais sob o telhado transversal.
		_triangulo(Vector3(lado*2.31,2.88,-1.15),Vector3(lado*2.31,3.78,-0.18),Vector3(lado*2.31,2.88,1.14),"reboco_clinica")
	_caixa(Vector3(4.65,1.02,0.16),Vector3(0,2.37,-1.07),"reboco_clinica")
	_caixa(Vector3(4.65,1.02,0.16),Vector3(0,2.37,1.02),"reboco_clinica")
	for y in [1.87,2.88]: _caixa(Vector3(4.84,0.14,0.20),Vector3(0,y,1.11),"madeira")
	# A abertura da vitrine mantém fundo, laterais e bancada separados da alvenaria.
	_alvenaria(Vector3(-2.28,1.03,1.02),Vector2(0.28,1.72))
	_alvenaria(Vector3(-1.25,0.43,1.02),Vector2(1.78,0.52))
	_alvenaria(Vector3(-1.25,1.79,1.02),Vector2(1.78,0.20))
	_alvenaria(Vector3(-0.19,1.03,1.02),Vector2(0.34,1.72))
	_alvenaria(Vector3(0.62,1.81,1.02),Vector2(1.26,0.16))
	_alvenaria(Vector3(1.27,1.03,1.02),Vector2(0.25,1.72))
	_alvenaria(Vector3(2.27,1.03,1.02),Vector2(0.24,1.72))
	_alvenaria(Vector3(1.85,0.45,1.02),Vector2(0.60,0.56))
	_alvenaria(Vector3(1.85,1.68,1.02),Vector2(0.70,0.40))
	_caixa(Vector3(1.17,1.54,0.10),Vector3(0.62,0.94,0.92),"argamassa")
	_caixa(Vector3(0.86,1.67,0.10),Vector3(1.85,1.03,0.91),"argamassa")
	_caixa(Vector3(4.85,0.16,2.30),Vector3(0,0.12,0),"pedra_escura")
	for i in 16: _caixa(Vector3(0.28,0.19,0.17),Vector3(-2.25+i*0.30,0.23,1.12),"cantaria")
	for i in 2:
		_caixa(Vector3(1.18+i*0.12,0.14,0.35),Vector3(0.62,0.25-i*0.11,1.30+i*0.29),"cantaria")
		_caixa(Vector3(1.18+i*0.12,0.025,0.12),Vector3(0.62,0.34-i*0.11,1.43+i*0.29),"neve")

func _porta() -> void:
	var forma := PackedVector2Array([Vector2(0.20,0.32),Vector2(1.04,0.32),Vector2(1.04,1.15)])
	for i in range(1,13): forma.append(Vector2(0.62+cos(PI*i/12.0)*0.42,1.15+sin(PI*i/12.0)*0.42))
	_extrudar_xy(forma,1.10,0.14,"madeira_escura")
	for i in 7:
		var x := -0.36+i*0.12
		var altura := 1.15+sqrt(maxf(0,0.42*0.42-x*x))-0.34
		_caixa(Vector3(0.111,altura,0.04),Vector3(0.62+x,0.34+altura*0.5,1.12),"madeira")
	_arco_bento(Vector3(0.62,1.15,1.29),0.44,0.16,"pedra_bento")
	for lado in [-1.0,1.0]:
		for i in 4: _caixa(Vector3(0.16,0.20,0.21),Vector3(0.62+lado*0.52,0.41+i*0.205,1.20),"pedra_bento")
	var vidro := PackedVector2Array([Vector2(0.38,1.02),Vector2(0.86,1.02),Vector2(0.86,1.24)])
	for i in range(1,11): vidro.append(Vector2(0.62+cos(PI*i/10.0)*0.24,1.24+sin(PI*i/10.0)*0.24))
	_extrudar_xy(vidro,1.17,0.03,"vidro")
	_arco_bento(Vector3(0.62,1.24,1.22),0.25,0.045,"madeira")
	for x in [0.35,0.62,0.89]: _caixa(Vector3(0.035,0.40,0.035),Vector3(x,1.23,1.21),"madeira_escura")
	_caixa(Vector3(0.55,0.04,0.035),Vector3(0.62,1.01,1.21),"madeira")
	_caixa(Vector3(0.64,0.05,0.035),Vector3(0.62,0.90,1.20),"madeira_escura")
	for i in 12:
		var a := TAU*i/12.0
		var b := TAU*(i+1)/12.0
		var p := Vector3(0.62,0.77,1.23)
		_face(p+Vector3(cos(a),sin(a),0)*0.060,p+Vector3(cos(b),sin(b),0)*0.060,p+Vector3(cos(b),sin(b),0)*0.037,p+Vector3(cos(a),sin(a),0)*0.037,"ouro")

func _janela(p: Vector3, raio: float, altura: float) -> void:
	var forma := PackedVector2Array([Vector2(p.x-raio,p.y-altura),Vector2(p.x+raio,p.y-altura),Vector2(p.x+raio,p.y)])
	for i in range(1,11): forma.append(Vector2(p.x+cos(PI*i/10.0)*raio,p.y+sin(PI*i/10.0)*raio))
	_extrudar_xy(forma,p.z+0.015,0.06,"vidro")
	_arco_bento(p+Vector3(0,0,0.13),raio,0.08,"madeira")
	for lado in [-1.0,1.0]: _caixa(Vector3(0.08,altura,0.12),p+Vector3(lado*(raio+0.04),-altura*0.5,0.07),"madeira")
	_caixa(Vector3(0.035,altura+raio,0.035),p+Vector3(0,(raio-altura)*0.5,0.08),"madeira_escura")
	_caixa(Vector3(raio*2,0.035,0.035),p+Vector3(0,-0.07,0.08),"madeira")
	_caixa(Vector3(raio*2+0.22,0.07,0.23),p+Vector3(0,-altura-0.03,0.09),"madeira")

func _vitrine() -> void:
	_caixa(Vector3(1.76,1.03,0.08),Vector3(-1.25,1.18,0.66),"madeira_escura")
	for x in [-2.10,-0.39]: _caixa(Vector3(0.10,1.12,0.47),Vector3(x,1.18,0.90),"madeira")
	for y in [0.69,1.67]: _caixa(Vector3(1.81,0.12,0.45),Vector3(-1.25,y,0.93),"madeira")
	for i in 3:
		var x := -1.80+i*0.55
		_caixa(Vector3(0.43,0.39,0.035),Vector3(x,1.39,0.72),"vidro")
		for lado in [-1.0,1.0]: _caixa(Vector3(0.04,0.47,0.05),Vector3(x+lado*0.24,1.39,0.76),"madeira")
		_caixa(Vector3(0.43,0.035,0.05),Vector3(x,1.38,0.76),"madeira")
	_caixa(Vector3(1.88,0.09,0.70),Vector3(-1.25,0.76,1.05),"cantaria")
	for cesta in 2:
		var x := -1.68+cesta*0.85
		_caixa(Vector3(0.72,0.11,0.44),Vector3(x,0.86,1.06),"madeira_escura")
		for y in [0.84,0.89]: _caixa(Vector3(0.74,0.025,0.035),Vector3(x,y,1.29),"madeira")
		for i in 3: _pao(Vector3(x-0.22+i*0.22,0.99+float(i%2)*0.045,1.06),Vector3(0.29,0.20,0.27))
		_pao(Vector3(x,1.10,1.01),Vector3(0.38,0.20,0.24))

func _toldo() -> void:
	# Tecido curvo em faixas largas, sustentado por braços e haste frontal.
	for i in 8:
		var a := -2.20+i*0.24
		var b := a+0.24
		var tipo := "toldo_vermelho" if i%2 == 0 else "toldo_creme"
		for j in 4:
			var t := float(j)/4.0
			var u := float(j+1)/4.0
			var ya := 2.33-0.22*t-0.065*sin(PI*t)
			var yb := 2.33-0.22*u-0.065*sin(PI*u)
			_face(Vector3(a,ya,1.12+t*0.71),Vector3(b,ya,1.12+t*0.71),Vector3(b,yb,1.12+u*0.71),Vector3(a,yb,1.12+u*0.71),tipo)
			if j == 3: _face(Vector3(a,ya+0.025,1.12+t*0.71),Vector3(b,ya+0.025,1.12+t*0.71),Vector3(b,yb+0.025,1.12+u*0.71),Vector3(a,yb+0.025,1.12+u*0.71),"neve")
		var aba := PackedVector2Array([Vector2(a,2.12),Vector2(b,2.12),Vector2(b,1.98),Vector2(b-0.035,1.94),Vector2(a+0.035,1.94),Vector2(a,1.98)])
		_extrudar_xy(aba,1.85,0.025,tipo)
	for x in [-2.15,-0.35]: _viga(Vector3(x,1.73,1.12),Vector3(x,2.09,1.81),0.045,"ferro_escuro")
	_viga(Vector3(-2.21,2.10,1.81),Vector3(-0.27,2.10,1.81),0.045,"ferro_escuro")

func _cobertura(p: Vector3, largura: float, agua: float, altura: float, frontal: bool) -> void:
	for lado in [-1.0,1.0]:
		var pontos: Array[Vector3] = [Vector3(-largura*0.5,altura-0.02,0),Vector3(largura*0.5,altura-0.02,0),Vector3(largura*0.5,-0.02,lado*agua),Vector3(-largura*0.5,-0.02,lado*agua)]
		for i in 4:
			if frontal: pontos[i] = Vector3(pontos[i].z,pontos[i].y,pontos[i].x)
			pontos[i] += p
		_face(pontos[0],pontos[1],pontos[2],pontos[3],"madeira_escura")
	_telhado(p,largura,agua,altura,frontal)

func _volume_central() -> void:
	_caixa(Vector3(1.83,1.04,0.18),Vector3(0.42,2.40,1.39),"reboco_clinica")
	for x in [-0.53,1.37]:
		_caixa(Vector3(0.12,1.09,0.44),Vector3(x,2.43,1.24),"madeira")
		_caixa(Vector3(0.22,0.25,0.28),Vector3(x,1.88,1.30),"madeira_escura")
	_caixa(Vector3(2.02,0.15,0.35),Vector3(0.42,1.96,1.41),"madeira")
	_extrudar_xy(PackedVector2Array([Vector2(-0.53,2.93),Vector2(1.37,2.93),Vector2(0.42,4.08)]),1.48,0.18,"reboco_clinica")
	_cobertura(Vector3(0.42,2.93,0.82),1.92,1.03,1.18,true)
	for lado in [-1.0,1.0]: _viga(Vector3(0.42+lado*1.06,2.93,1.80),Vector3(0.42,4.17,1.80),0.12,"madeira_escura")
	_janela(Vector3(0.42,2.88,1.50),0.28,0.38)
	_floreira_cora(Vector3(0.42,2.43,1.67),1.08)
	var disco := PackedVector2Array()
	for i in 12: disco.append(Vector2(0.42+cos(TAU*i/12.0)*0.08,4.18+sin(TAU*i/12.0)*0.08))
	_extrudar_biselado_xy(disco,1.84,0.06,"ouro",Color.WHITE,0.012)

func _dormer() -> void:
	_caixa(Vector3(0.65,0.57,0.40),Vector3(-1.64,3.18,1.08),"reboco_clinica")
	_extrudar_xy(PackedVector2Array([Vector2(-2.00,3.46),Vector2(-1.28,3.46),Vector2(-1.64,3.89)]),1.30,0.38,"reboco_clinica")
	_cobertura(Vector3(-1.64,3.45,0.99),0.92,0.44,0.46,true)
	for lado in [-1.0,1.0]: _viga(Vector3(-1.64+lado*0.46,3.44,1.48),Vector3(-1.64,3.94,1.48),0.07,"madeira")
	_janela(Vector3(-1.64,3.25,1.31),0.17,0.28)
	_floreira_cora(Vector3(-1.64,2.95,1.43),0.66)

func _chamine() -> void:
	var p := Vector3(-2.08,3.24,-0.30)
	for lado in [-1.0,1.0]:
		_alvenaria(p+Vector3(0,0.54,lado*0.22),Vector2(0.45,1.08),Basis(Vector3.UP,0 if lado>0 else PI))
		_alvenaria(p+Vector3(lado*0.22,0.54,0),Vector2(0.36,1.08),Basis(Vector3.UP,lado*PI*0.5))
		_caixa(Vector3(0.15,0.13,0.61),p+Vector3(lado*0.23,1.10,0),"cantaria")
		_caixa(Vector3(0.31,0.13,0.15),p+Vector3(0,1.10,lado*0.23),"cantaria")
		_caixa(Vector3(0.15,0.023,0.61),p+Vector3(lado*0.23,1.19,0),"neve")
		_caixa(Vector3(0.31,0.023,0.15),p+Vector3(0,1.19,lado*0.23),"neve")
	_caixa(Vector3(0.27,0.02,0.27),p+Vector3.UP*0.91,"fundo")
	_cilindro(p+Vector3(0.07,1.17,-0.04),0.075,0.16,"metal",Color.WHITE,10)
	_anel(p+Vector3(0.07,1.33,-0.04),0.089,0.055,0.03,"metal",10)

func _placa() -> void:
	_viga(Vector3(-2.31,2.28,1.06),Vector3(-3.27,2.28,1.06),0.10,"madeira")
	for x in [-3.15,-2.68]:
		_viga(Vector3(x,2.25,1.06),Vector3(x,2.03,1.06),0.022,"ferro_escuro")
		_rebite(Vector3(x,2.29,1.13),0.026)
	var forma := PackedVector2Array([Vector2(-3.27,2.04),Vector2(-2.58,2.04),Vector2(-2.50,1.97),Vector2(-2.50,1.54),Vector2(-2.58,1.47),Vector2(-3.27,1.47),Vector2(-3.34,1.54),Vector2(-3.34,1.97)])
	_extrudar_biselado_xy(forma,1.15,0.12,"madeira_escura")
	for i in forma.size(): forma[i] = Vector2(-2.92,1.76)+(forma[i]-Vector2(-2.92,1.76))*0.85
	_extrudar_xy(forma,1.18,0.07,"madeira")
	_pao(Vector3(-2.92,1.76,1.23),Vector3(0.54,0.24,0.16))
	_caixa(Vector3(0.98,0.025,0.10),Vector3(-2.81,2.35,1.06),"neve")

func _trepadeiras() -> void:
	for x in [-2.31,1.20]:
		var ultimo := Vector3(x,0.32,1.20)
		for i in 14:
			var p := ultimo+Vector3(sin(i*2.0)*0.05,0.18,0)
			_viga(ultimo,p,0.025,"madeira_escura")
			for lado in [-1.0,1.0]: _folha_erva(p+Vector3(lado*0.055,0.03,0.025),Vector3(0.14,0.08,0.09))
			if i%3 == 1: _flor_jardim(p+Vector3(0,0.07,0.06),true,0.075)
			ultimo = p
