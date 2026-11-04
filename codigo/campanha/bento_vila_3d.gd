@tool
extends "res://codigo/campanha/bento_malha_3d.gd"
## Casa do Bento: porta verde à direita e janela com floreira à esquerda da fachada original.

func _ready() -> void:
	_paredes()
	_porta()
	_janela(Vector3(-0.76,1.31,1.10),0.28,0.40)
	_floreira()
	_subcobertura(Vector3(-1.20,2.10,-0.56),1.46,0.88,0.59,false)
	_telhado(Vector3(-1.20,2.10,-0.56),1.46,0.88,0.59,false)
	_subcobertura(Vector3(0,2.14,0),2.76,1.79,1.46,true)
	_telhado(Vector3(0,2.14,0),2.76,1.79,1.46,true)
	_empena()
	_chamine()
	_lanterna_parede(Vector3(1.30,1.43,1.29))
	_finalizar()
	definir_estacao(0)

func _paredes() -> void:
	_caixa(Vector3(3.03,2.02,0.15),Vector3(0,1.15,-1.09),"reboco_clinica")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.15,2.14,2.10),Vector3(lado*1.47,1.21,-0.02),"reboco_clinica")
		_extrudar_xy(PackedVector2Array([Vector2(lado*1.395,2.28),Vector2(lado*1.545,2.28),Vector2(lado*1.545,2.30),Vector2(lado*1.395,2.422)]),1.03,2.10,"reboco_clinica")
		_caixa(Vector3(0.15,2.14,0.18),Vector3(lado*1.50,1.20,1.10),"madeira")
		_caixa(Vector3(0.17,2.12,0.18),Vector3(lado*1.50,1.13,-1.08),"madeira_escura")
		for i in 7:
			_caixa(Vector3(0.15,0.20,0.29),Vector3(lado*1.51,0.20,-0.92+i*0.30),"pedra_bento")
	# Vãos abertos na malha: nenhum painel de reboco fica atrás dos vidros ou da porta.
	for faixa in [Vector2(-1.42,-1.04),Vector2(-0.48,0.28),Vector2(1.04,1.42)]:
		_caixa(Vector3(faixa.y-faixa.x,1.98,0.14),Vector3((faixa.x+faixa.y)*0.5,1.15,1.04),"reboco_clinica")
	_caixa(Vector3(0.56,0.72,0.14),Vector3(-0.76,0.52,1.04),"reboco_clinica")
	_sobre_arco(-0.76,1.31,0.28,2.14)
	_sobre_arco(0.66,1.30,0.38,2.14)
	_caixa(Vector3(3.20,0.15,2.32),Vector3(0,0.12,0),"pedra_escura")
	for x in [-1.32,-1.03,-0.74,-0.45,-0.16,0.13,1.26]:
		_caixa(Vector3(0.27,0.20,0.20),Vector3(x,0.23,1.13),"cantaria")
	_caixa(Vector3(3.15,0.14,0.20),Vector3(0,2.10,1.12),"madeira")
	# Pequena ala traseira esquerda, coberta pelo telhado transversal baixo.
	_caixa(Vector3(0.31,1.98,1.24),Vector3(-1.64,1.10,-0.64),"reboco_clinica")
	_triangulo(Vector3(-1.80,2.09,-1.40),Vector3(-1.80,2.67,-0.56),Vector3(-1.80,2.09,0.29),"reboco_clinica")
	_caixa(Vector3(0.13,2.04,0.14),Vector3(-1.83,1.11,-0.01),"madeira")
	for i in 3:
		_caixa(Vector3(0.98+i*0.08,0.13,0.32),Vector3(0.66,0.32-i*0.095,1.23+i*0.25),"cantaria")
		_caixa(Vector3(0.98+i*0.08,0.023,0.11),Vector3(0.66,0.405-i*0.095,1.34+i*0.25),"neve")

func _sobre_arco(x: float, linha: float, raio: float, topo: float) -> void:
	for i in 12:
		var a := -raio+2.0*raio*i/12.0
		var b := -raio+2.0*raio*(i+1)/12.0
		var ya := linha+sqrt(maxf(0,raio*raio-a*a))
		var yb := linha+sqrt(maxf(0,raio*raio-b*b))
		_extrudar_xy(PackedVector2Array([Vector2(x+a,ya),Vector2(x+b,yb),Vector2(x+b,topo),Vector2(x+a,topo)]),1.11,0.14,"reboco_clinica")

func _porta() -> void:
	var x := 0.66
	var forma := PackedVector2Array([Vector2(x-0.38,0.39),Vector2(x+0.38,0.39),Vector2(x+0.38,1.30)])
	for i in range(1,13): forma.append(Vector2(x+cos(PI*i/12.0)*0.38,1.30+sin(PI*i/12.0)*0.38))
	_extrudar_xy(forma,1.10,0.13,"verde_rebaixo")
	for i in 7:
		var u := -0.324+i*0.108
		var altura := 1.30+sqrt(maxf(0,0.38*0.38-u*u))-0.41
		_caixa(Vector3(0.100,altura,0.045),Vector3(x+u,0.41+altura*0.5,1.12),"madeira_verde",Color.WHITE.lightened(float(i%2)*0.035))
	_arco_bento(Vector3(x,1.30,1.25),0.39,0.14,"pedra_bento")
	for lado in [-1.0,1.0]:
		for i in 4: _caixa(Vector3(0.14,0.23,0.18),Vector3(x+lado*0.46,0.50+i*0.235,1.17),"pedra_bento")
		_caixa(Vector3(0.035,0.90,0.027),Vector3(x+lado*0.30,0.88,1.16),"madeira_verde")
	for y in [0.46,0.80,1.29]: _caixa(Vector3(0.63,0.040,0.03),Vector3(x,y,1.16),"madeira_verde")
	_caixa(Vector3(0.04,0.77,0.03),Vector3(x+0.055,0.86,1.16),"madeira_verde")
	_caixa(Vector3(0.038,0.20,0.04),Vector3(x-0.22,1.00,1.20),"ouro")
	for y in [0.90,1.10]: _rebite(Vector3(x-0.22,y,1.23),0.022)
	for y in [0.62,1.19]:
		_caixa(Vector3(0.11,0.035,0.025),Vector3(x+0.28,y,1.20),"ferro_escuro")
		_rebite(Vector3(x+0.31,y,1.22),0.014)

func _janela(p: Vector3, raio: float, altura: float, vidro := "vidro") -> void:
	var forma := PackedVector2Array([Vector2(p.x-raio,p.y-altura),Vector2(p.x+raio,p.y-altura),Vector2(p.x+raio,p.y)])
	for i in range(1,11): forma.append(Vector2(p.x+cos(PI*i/10.0)*raio,p.y+sin(PI*i/10.0)*raio))
	_extrudar_xy(forma,p.z,0.08,vidro)
	_arco_bento(p+Vector3(0,0,0.12),raio,0.09,"madeira")
	for lado in [-1.0,1.0]: _caixa(Vector3(0.085,altura,0.12),p+Vector3(lado*(raio+0.04),-altura*0.5,0.05),"madeira")
	_caixa(Vector3(0.035,altura+raio,0.04),p+Vector3(0,(raio-altura)*0.5,0.06),"madeira_escura")
	_caixa(Vector3(raio*2,0.035,0.04),p+Vector3(0,-0.03,0.06),"madeira")
	_caixa(Vector3(raio*2+0.24,0.085,0.23),p+Vector3(0,-altura-0.03,0.08),"madeira")
	_caixa(Vector3(raio*2+0.24,0.021,0.12),p+Vector3(0,-altura+0.023,0.14),"neve")

func _floreira() -> void:
	var p := Vector3(-0.76,0.78,1.27)
	_caixa(Vector3(0.78,0.19,0.30),p,"madeira_escura")
	_caixa(Vector3(0.82,0.045,0.33),p+Vector3.UP*0.105,"madeira")
	for x in [-0.30,-0.10,0.10,0.30]: _caixa(Vector3(0.18,0.16,0.025),p+Vector3(x,0,0.16),"madeira")
	for x in [-0.26,0,0.26]: _moita(p+Vector3(x,0.10,0.03),0.30,x == 0)
	for x in [-0.25,0.25]: _viga(p+Vector3(x,-0.14,0.08),p+Vector3(x,-0.25,-0.17),0.065,"madeira_escura")
	_caixa(Vector3(0.82,0.022,0.10),p+Vector3(0,0.14,0.12),"neve")

func _empena() -> void:
	var contorno := PackedVector2Array([Vector2(-1.54,2.14),Vector2(1.54,2.14),Vector2(1.54,2.34),Vector2(0,3.60),Vector2(-1.54,2.34)])
	_extrudar_xy(contorno,1.12,0.15,"reboco_clinica")
	_extrudar_xy(contorno,-1.03,0.15,"reboco_clinica")
	for lado in [-1.0,1.0]:
		_viga(Vector3(lado*1.72,2.13,1.40),Vector3(0,3.64,1.40),0.12,"madeira_escura")
		_viga(Vector3(lado*0.96,2.19,1.23),Vector3(lado*0.25,2.86,1.23),0.075,"madeira")
	_caixa(Vector3(0.10,0.22,0.13),Vector3(0,3.40,1.23),"madeira")
	_janela(Vector3(0,2.79,1.23),0.19,0.30,"vidro_bento")
	var disco := PackedVector2Array()
	for i in 12: disco.append(Vector2(cos(TAU*i/12.0)*0.083,3.66+sin(TAU*i/12.0)*0.083))
	_extrudar_biselado_xy(disco,1.46,0.055,"ouro",Color.WHITE,0.014)

func _chamine() -> void:
	# Paredes e interior separados, boca vazada acima do telhado.
	var p := Vector3(1.02,2.63,-0.55)
	_caixa(Vector3(0.46,0.93,0.42),p+Vector3.UP*0.45,"pedra_escura")
	for i in 5:
		var y := p.y+0.12+i*0.20
		for lado in [-1.0,1.0]:
			for j in 2:
				_caixa(Vector3(0.215,0.18,0.075),Vector3(p.x-0.12+j*0.24,y,p.z+lado*0.245),"pedra_bento",Color.WHITE.darkened(float((i+j)%3)*0.035))
			_caixa(Vector3(0.07,0.18,0.40),Vector3(p.x+lado*0.245,y,p.z),"pedra_bento")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.46,0.18,0.07),p+Vector3(0,1.03,lado*0.205),"pedra_bento")
		_caixa(Vector3(0.07,0.18,0.34),p+Vector3(lado*0.205,1.03,0),"pedra_bento")
		_caixa(Vector3(0.60,0.11,0.11),p+Vector3(0,1.13,lado*0.245),"cantaria")
		_caixa(Vector3(0.11,0.11,0.38),p+Vector3(lado*0.245,1.13,0),"cantaria")
		_caixa(Vector3(0.60,0.025,0.10),p+Vector3(0,1.20,lado*0.245),"neve")
		_caixa(Vector3(0.10,0.025,0.38),p+Vector3(lado*0.245,1.20,0),"neve")
	_caixa(Vector3(0.37,0.02,0.35),p+Vector3.UP*0.99,"fundo")

func _subcobertura(centro: Vector3, largura: float, agua: float, altura: float, frontal: bool) -> void:
	# Planos contínuos sob as telhas; o interior não aparece nas junções nem na vista lateral.
	for lado in [-1.0,1.0]:
		var pontos: Array[Vector3] = [Vector3(-largura*0.5,altura-0.02,0),Vector3(largura*0.5,altura-0.02,0),Vector3(largura*0.5,-0.025,lado*agua),Vector3(-largura*0.5,-0.025,lado*agua)]
		for i in 4:
			if frontal: pontos[i] = Vector3(pontos[i].z,pontos[i].y,pontos[i].x)
			pontos[i] += centro
		_face(pontos[0],pontos[1],pontos[2],pontos[3],"madeira_escura")
