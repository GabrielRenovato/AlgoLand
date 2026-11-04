@tool
extends "res://codigo/campanha/enfermaria_malha_3d.gd"
## Enfermaria: entrada fora do centro, ala lateral e chaminé quadrada vazada.

func _ready() -> void:
	_paredes()
	_porta()
	_janela_clinica(Vector3(-1.25,1.10,1.03),0.19)
	_janela_clinica(Vector3(0.29,1.10,1.03),0.19)
	_janela_clinica(Vector3(1.30,1.05,0.53),0.235)
	_telhado(Vector3(0,1.92,-0.47),3.90,1.02,0.74,false)
	_telhado(Vector3(-0.48,1.94,0.25),2.54,1.24,1.15,true)
	_frontao()
	_chamine()
	_jardineiras()
	_lanterna()
	_finalizar()
	definir_estacao(0)

func _paredes() -> void:
	_caixa(Vector3(3.53,1.80,0.16),Vector3(0,1.04,-0.92),"reboco_clinica")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.16,1.80,1.42),Vector3(lado*1.70,1.04,-0.24),"reboco_clinica")
	# A fachada da entrada avança meio metro em relação à ala direita.
	for x in [-1.63,0.67]:
		_caixa(Vector3(0.12,1.80,0.53),Vector3(x,1.04,0.78),"reboco_clinica")
		_caixa(Vector3(0.15,1.80,0.19),Vector3(x,1.05,1.04),"madeira")
		_caixa(Vector3(0.23,0.24,0.24),Vector3(x,0.25,1.04),"cantaria")
		_ferragem(Vector3(x,1.88,1.16),Vector2(0.15,0.13))
	for x in [-1.52,-0.96,0.00,0.58]: _caixa(Vector3(0.19,1.71,0.15),Vector3(x,1.04,1.00),"reboco_clinica")
	for x in [-1.25,0.29]:
		_caixa(Vector3(0.38,0.48,0.16),Vector3(x,0.45,1.00),"reboco_clinica")
		_caixa(Vector3(0.38,0.54,0.16),Vector3(x,1.67,1.00),"reboco_clinica")
	_caixa(Vector3(0.83,0.47,0.16),Vector3(-0.48,1.70,1.00),"reboco_clinica")
	_caixa(Vector3(2.47,0.15,0.22),Vector3(-0.48,1.93,1.06),"madeira")
	# Ala lateral com vão próprio, sem pintar a janela sobre uma parede maciça.
	for x in [0.85,1.67]: _caixa(Vector3(0.20,1.74,0.17),Vector3(x,1.02,0.50),"reboco_clinica")
	_caixa(Vector3(0.58,0.39,0.17),Vector3(1.29,0.42,0.50),"reboco_clinica")
	_caixa(Vector3(0.58,0.60,0.17),Vector3(1.29,1.64,0.50),"reboco_clinica")
	_caixa(Vector3(0.15,1.80,0.19),Vector3(1.76,1.05,0.50),"madeira_escura")
	_caixa(Vector3(1.13,0.13,0.20),Vector3(1.21,1.91,0.51),"madeira")
	_caixa(Vector3(3.58,0.15,1.53),Vector3(0,0.13,-0.20),"pedra_escura")
	_caixa(Vector3(2.45,0.15,0.50),Vector3(-0.48,0.13,0.80),"pedra_escura")
	for linha in 2:
		for coluna in 9:
			var x := -1.60+coluna*0.39
			if x > -0.95 and x < -0.02: continue
			_caixa(Vector3(0.36,0.14,0.16),Vector3(x,0.23+linha*0.15,1.095 if x<0.76 else 0.61),"pedra",Color.WHITE.lightened(float(coluna%3)*0.04))
	for i in 3:
		_caixa(Vector3(1.00+i*0.10,0.11,0.31),Vector3(-0.48,0.26-i*0.085,1.17+i*0.23),"cantaria")
		_caixa(Vector3(1.00+i*0.10,0.025,0.10),Vector3(-0.48,0.327-i*0.085,1.25+i*0.23),"neve")

func _porta() -> void:
	var x := -0.48
	var forma := PackedVector2Array([Vector2(x-0.34,0.30),Vector2(x+0.34,0.30),Vector2(x+0.34,1.06)])
	for i in range(1,13): forma.append(Vector2(x+cos(PI*i/12.0)*0.34,1.06+sin(PI*i/12.0)*0.34))
	_extrudar_xy(forma,1.00,0.12,"madeira_escura")
	for i in 6:
		var xx := -0.275+i*0.11
		var altura := 1.06+sqrt(maxf(0,0.34*0.34-xx*xx))-0.31
		_caixa(Vector3(0.102,altura,0.04),Vector3(x+xx,0.31+altura*0.5,1.04),"madeira",Color.WHITE.darkened(float(i%3)*0.025))
	_arco_clinica(x,1.06,0.36,0.15,1.19)
	for lado in [-1.0,1.0]:
		for i in 4: _caixa(Vector3(0.15,0.18,0.18),Vector3(x+lado*0.435,0.40+i*0.185,1.11),"cantaria",Color("d5c2a0"))
	for y in [0.54,1.04]:
		_caixa(Vector3(0.20,0.045,0.035),Vector3(x-0.20,y,1.08),"ferro_escuro")
		for xx in [-0.26,-0.12]: _rebite(Vector3(x+xx,y,1.11),0.015)
	for i in 12:
		var a := TAU*i/12.0
		var b := TAU*(i+1)/12.0
		var p := Vector3(x+0.13,0.81,1.115)
		_face(p+Vector3(cos(a),sin(a),0)*0.058,p+Vector3(cos(b),sin(b),0)*0.058,p+Vector3(cos(b),sin(b),0)*0.033,p+Vector3(cos(a),sin(a),0)*0.033,"metal")

func _frontao() -> void:
	_extrudar_xy(PackedVector2Array([Vector2(-1.70,1.94),Vector2(0.74,1.94),Vector2(-0.48,3.07)]),1.10,0.16,"reboco_clinica")
	for lado in [-1.0,1.0]: _viga(Vector3(-0.48+lado*1.27,1.94,1.24),Vector3(-0.48,3.13,1.24),0.13,"madeira_escura")
	_cruz(Vector3(-0.48,2.37,1.23),0.52)
	for x in [-1.04,0.08]:
		_folha_erva(Vector3(x,2.15,1.19),Vector3(0.14,0.06,0.07))
		_folha_erva(Vector3(x+0.035,2.20,1.19),Vector3(0.08,0.11,0.065))
	# Fecho arredondado da cumeeira da entrada.
	var ponta := PackedVector2Array()
	for i in 12: ponta.append(Vector2(-0.48+cos(TAU*i/12.0)*0.074,3.15+sin(TAU*i/12.0)*0.074))
	_extrudar_biselado_xy(ponta,1.59,0.065,"ouro",Color.WHITE,0.012)

func _chamine() -> void:
	var p := Vector3(-1.24,2.38,-0.50)
	# Quatro paredes e fundo rebaixado mantêm o topo genuinamente aberto.
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.12,1.00,0.50),p+Vector3(lado*0.22,0.50,0),"pedra")
		_caixa(Vector3(0.34,1.00,0.12),p+Vector3(0,0.50,lado*0.22),"pedra")
	_caixa(Vector3(0.33,0.03,0.33),p+Vector3(0,0.78,0),"fundo")
	for linha in 5:
		var y := 0.10+linha*0.19
		for lado in [-1.0,1.0]:
			_caixa(Vector3(0.56,0.018,0.015),p+Vector3(0,y,lado*0.285),"junta")
			_caixa(Vector3(0.015,0.018,0.56),p+Vector3(lado*0.285,y,0),"junta")
			_caixa(Vector3(0.016,0.17,0.018),p+Vector3((-0.10 if linha%2 else 0.10),y+0.09,lado*0.285),"junta")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.16,0.13,0.65),p+Vector3(lado*0.25,1.015,0),"cantaria")
		_caixa(Vector3(0.36,0.13,0.15),p+Vector3(0,1.015,lado*0.25),"cantaria")
		_caixa(Vector3(0.17,0.035,0.66),p+Vector3(lado*0.25,1.10,0),"neve")
		_caixa(Vector3(0.35,0.035,0.16),p+Vector3(0,1.10,lado*0.25),"neve")

func _jardineiras() -> void:
	for x in [-1.25,0.29]:
		_caixa(Vector3(0.46,0.11,0.22),Vector3(x,0.65,1.20),"madeira_escura")
		for i in 3:
			_folha_erva(Vector3(x-0.14+i*0.14,0.76,1.25),Vector3(0.20,0.10,0.18))
			_flor_jardim(Vector3(x-0.14+i*0.14,0.81,1.30),true,0.068)
	# Caixa de ervas presa ao telhado traseiro, com pés e fundo próprios.
	_caixa(Vector3(0.56,0.17,0.35),Vector3(0.61,2.77,-0.57),"madeira")
	for x in [0.40,0.80]:
		_caixa(Vector3(0.065,0.22,0.33),Vector3(x,2.66,-0.57),"madeira_escura")
	for i in 9:
		var a := TAU*i/9.0
		_folha_erva(Vector3(0.61+cos(a)*0.19,2.91+float(i%3)*0.055,-0.57+sin(a)*0.10),Vector3(0.20,0.13,0.16))
	_caixa(Vector3(0.56,0.023,0.12),Vector3(0.61,2.87,-0.40),"neve")

func _lanterna() -> void:
	var p := Vector3(1.84,1.34,0.48)
	_caixa(Vector3(0.13,0.23,0.13),p,"vidro")
	for x in [-0.08,0.08]:
		for z in [-0.08,0.08]: _caixa(Vector3(0.025,0.25,0.025),p+Vector3(x,0,z),"ferro_escuro")
	_caixa(Vector3(0.21,0.04,0.21),p-Vector3.UP*0.14,"ferro_escuro")
	_cilindro(p+Vector3.UP*0.13,0.15,0.12,"ferro_escuro",Color.WHITE,4,0.035)
	_viga(p+Vector3(0,0.24,0),p+Vector3(-0.15,0.32,-0.04),0.03,"ferro_escuro")
