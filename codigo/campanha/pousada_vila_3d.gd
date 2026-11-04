@tool
extends "res://codigo/campanha/pousada_malha_3d.gd"
## Pousada de Mara: dois andares, cobertura de quatro águas, três empenas e varanda lateral.

func _ready() -> void:
	_paredes()
	_porta()
	for x in [-1.92,1.92]: _janela_pousada(Vector3(x,1.06,1.02),0.28)
	for x in [-1.92,0.0,1.92]: _janela_pousada(Vector3(x,2.62,1.04 if x != 0.0 else 1.48),0.28,true)
	_telhado_principal()
	_empena_central()
	for lado in [-1.0,1.0]:
		_dormer(lado*1.87)
		_chamine(lado*2.38)
	_varanda()
	_trepadeiras()
	for x in [-0.91,0.91]: _lanterna_pousada(Vector3(x,1.06,1.23))
	_finalizar()
	definir_estacao(0)

func _paredes() -> void:
	_caixa(Vector3(5.50,3.09,0.18),Vector3(0,1.70,-1.08),"reboco_clinica")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.18,1.52,2.1),Vector3(lado*2.68,0.92,-0.05),"pedra")
		_caixa(Vector3(0.16,1.51,2.1),Vector3(lado*2.68,2.45,-0.05),"reboco_clinica")
		for intervalo in [[0.68,1.43],[2.37,2.78]]:
			var largura: float = intervalo[1]-intervalo[0]
			_caixa(Vector3(largura,1.49,0.17),Vector3(lado*(intervalo[0]+intervalo[1])*0.5,0.91,0.99),"pedra")
		_caixa(Vector3(0.80,0.44,0.18),Vector3(lado*1.92,0.42,0.99),"pedra")
		_caixa(Vector3(0.80,0.30,0.18),Vector3(lado*1.92,1.53,0.99),"pedra")
		for x in [0.94,2.68]:
			_caixa(Vector3(0.15,1.63,0.22),Vector3(lado*x,2.45,1.04),"madeira_escura")
		for x in [1.27,2.48]: _caixa(Vector3(0.35,1.49,0.17),Vector3(lado*x,2.45,0.99),"reboco_clinica")
		_caixa(Vector3(0.82,0.42,0.17),Vector3(lado*1.92,1.99,0.99),"reboco_clinica")
		_caixa(Vector3(0.82,0.28,0.17),Vector3(lado*1.92,3.08,0.99),"reboco_clinica")
	_caixa(Vector3(1.76,0.36,0.20),Vector3(0,1.61,1.01),"pedra")
	# Volume central avançado no andar superior, conservando vão para a janela.
	for x in [-0.68,0.68]: _caixa(Vector3(0.40,1.48,0.18),Vector3(x,2.45,1.39),"reboco_clinica")
	_caixa(Vector3(0.82,0.42,0.18),Vector3(0,1.99,1.39),"reboco_clinica")
	_caixa(Vector3(0.82,0.28,0.18),Vector3(0,3.08,1.39),"reboco_clinica")
	for y in [1.70,3.22]: _caixa(Vector3(5.66,0.17,0.25),Vector3(0,y,1.06),"madeira")
	for x in [-0.95,0.95]:
		_caixa(Vector3(0.17,1.66,0.20),Vector3(x,2.46,1.23),"madeira")
		_ferragem(Vector3(x,1.73,1.36),Vector2(0.20,0.18))
	_caixa(Vector3(5.68,0.16,2.30),Vector3(0,0.13,-0.02),"pedra_escura")
	for i in 3:
		_caixa(Vector3(1.32+i*0.12,0.12,0.33),Vector3(0,0.29-i*0.09,1.22+i*0.25),"cantaria")
		_caixa(Vector3(1.32+i*0.12,0.025,0.10),Vector3(0,0.365-i*0.09,1.33+i*0.25),"neve")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.21,0.43,0.31),Vector3(lado*0.82,0.28,1.44),"cantaria")

func _porta() -> void:
	var forma := PackedVector2Array([Vector2(-0.49,0.35),Vector2(0.49,0.35),Vector2(0.49,1.08)])
	for i in range(1,13): forma.append(Vector2(cos(PI*i/12.0)*0.49,1.08+sin(PI*i/12.0)*0.49))
	_extrudar_xy(forma,1.01,0.14,"madeira_escura")
	for i in 8:
		var x := -0.425+i*0.1214
		var altura := 1.08+sqrt(maxf(0,0.49*0.49-x*x))-0.35
		_caixa(Vector3(0.113,altura,0.045),Vector3(x,0.35+altura*0.5,1.06),"madeira")
	_arco_clinica(0,1.08,0.51,0.18,1.23)
	for lado in [-1.0,1.0]:
		for i in 4: _caixa(Vector3(0.18,0.18,0.21),Vector3(lado*0.60,0.45+i*0.19,1.13),"cantaria")
		for i in 12:
			var a := TAU*i/12.0
			var b := TAU*(i+1)/12.0
			var p := Vector3(lado*0.10,0.85,1.12)
			_face(p+Vector3(cos(a),sin(a),0)*0.058,p+Vector3(cos(b),sin(b),0)*0.058,p+Vector3(cos(b),sin(b),0)*0.036,p+Vector3(cos(a),sin(a),0)*0.036,"ouro")

func _ponto_cobertura(lado: int, u: float, v: float) -> Vector3:
	var altura := 4.73-1.46*v
	if lado < 2: return Vector3(u*lerpf(1.40,2.96,v),altura,-0.15+(1.53 if lado == 0 else -1.28)*v)
	return Vector3((1.40+1.56*v)*(1 if lado == 2 else -1),altura,-0.15+u*(1.53 if u >= 0 else 1.28)*v)

func _telhado_principal() -> void:
	# Quatro panos fecham as quinas; as telhas têm borda e sobreposição reais.
	for lado in 4:
		# Subcobertura contínua impede que frestas entre telhas revelem o reboco.
		var a_base := _ponto_cobertura(lado,-1.0,0.0)-Vector3.UP*0.025
		var b_base := _ponto_cobertura(lado,1.0,0.0)-Vector3.UP*0.025
		var c_base := _ponto_cobertura(lado,1.0,1.03)-Vector3.UP*0.025
		var d_base := _ponto_cobertura(lado,-1.0,1.03)-Vector3.UP*0.025
		if lado < 2: _face(a_base,b_base,c_base,d_base,"telha_borda")
		else: _triangulo(a_base,c_base,d_base,"telha_borda")
		var colunas := 23 if lado < 2 else 12
		for linha in 7:
			for coluna in colunas:
				var u0 := -1.0+2.0*coluna/colunas
				var u1 := -1.0+2.0*(coluna+1)/colunas-0.003
				var v0 := float(linha)/7.0
				var v1 := minf(1.025,float(linha+1)/7.0+0.018)
				var a := _ponto_cobertura(lado,u0,v0)+Vector3.UP*0.018
				var b := _ponto_cobertura(lado,u1,v0)+Vector3.UP*0.018
				var c := _ponto_cobertura(lado,u1,v1)+Vector3.UP*0.045
				var d := _ponto_cobertura(lado,u0,v1)+Vector3.UP*0.045
				var cor := Color.WHITE.darkened(float((linha*7+coluna*11)%5)*0.024)
				_face(a,b,c,d,"telha",cor)
				_face(d,c,c-Vector3.UP*0.035,d-Vector3.UP*0.035,"telha_borda",cor)
				if linha in [0,6]:
					var t := 0.75 if linha == 6 else 0.12
					_face(a.lerp(d,t)+Vector3.UP*0.024,b.lerp(c,t)+Vector3.UP*0.024,c+Vector3.UP*0.024 if linha == 6 else b+Vector3.UP*0.024,d+Vector3.UP*0.024 if linha == 6 else a+Vector3.UP*0.024,"neve")
	for i in 12: _capa_cumeeira(Vector3(-1.4+(i+0.5)*2.8/12.0,4.77,-0.15),0.24,false)
	for lado in [-1.0,1.0]:
		for fim in [-1.0,1.0]:
			_viga(Vector3(lado*1.40,4.75,-0.15),Vector3(lado*2.97,3.29,-0.15+fim*(1.53 if fim>0 else 1.28)),0.06,"telha_borda")
		_viga(Vector3(-2.97,3.23,-0.15+lado*(1.53 if lado>0 else 1.28)),Vector3(2.97,3.23,-0.15+lado*(1.53 if lado>0 else 1.28)),0.12,"madeira_escura")

func _empena_central() -> void:
	_extrudar_xy(PackedVector2Array([Vector2(-0.97,3.22),Vector2(0.97,3.22),Vector2(0,4.40)]),1.49,0.20,"reboco_clinica")
	_telhado(Vector3(0,3.23,0.90),1.65,1.04,1.19,true)
	for lado in [-1.0,1.0]: _viga(Vector3(lado*1.08,3.23,1.76),Vector3(0,4.47,1.76),0.14,"madeira_escura")
	_viga(Vector3(-0.65,3.25,1.53),Vector3(0,4.02,1.53),0.10,"madeira")
	_viga(Vector3(0.65,3.25,1.53),Vector3(0,4.02,1.53),0.10,"madeira")

func _dormer(x: float) -> void:
	_caixa(Vector3(0.66,0.52,0.36),Vector3(x,3.73,0.91),"reboco_clinica")
	_extrudar_xy(PackedVector2Array([Vector2(x-0.36,3.96),Vector2(x+0.36,3.96),Vector2(x,4.42)]),1.11,0.30,"reboco_clinica")
	_janela_clinica(Vector3(x,3.79,1.12),0.15)
	_telhado(Vector3(x,3.97,0.79),0.84,0.47,0.47,true)
	for lado in [-1.0,1.0]: _viga(Vector3(x+lado*0.49,3.95,1.24),Vector3(x,4.49,1.24),0.08,"madeira")

func _chamine(x: float) -> void:
	var p := Vector3(x,3.55,-0.72)
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.11,1.18,0.42),p+Vector3(lado*0.19,0.59,0),"pedra")
		_caixa(Vector3(0.29,1.18,0.11),p+Vector3(0,0.59,lado*0.19),"pedra")
	for i in 5:
		for lado in [-1.0,1.0]: _caixa(Vector3(0.49,0.018,0.015),p+Vector3(0,0.13+i*0.22,lado*0.25),"junta")
	_caixa(Vector3(0.28,0.025,0.28),p+Vector3.UP*0.99,"fundo")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.15,0.11,0.58),p+Vector3(lado*0.22,1.19,0),"cantaria")
		_caixa(Vector3(0.31,0.11,0.14),p+Vector3(0,1.19,lado*0.22),"cantaria")
		_caixa(Vector3(0.15,0.025,0.59),p+Vector3(lado*0.22,1.27,0),"neve")
		_caixa(Vector3(0.30,0.025,0.15),p+Vector3(0,1.27,lado*0.22),"neve")

func _varanda() -> void:
	for i in 9: _caixa(Vector3(0.15,0.08,1.74),Vector3(-3.47+i*0.15,0.25,0.10),"madeira")
	for x in [-3.49,-2.78]:
		_caixa(Vector3(0.13,1.78,0.14),Vector3(x,1.10,0.97),"madeira")
		_caixa(Vector3(0.24,0.24,0.24),Vector3(x,0.13,0.97),"cantaria")
	for y in [0.44,0.98]: _caixa(Vector3(0.84,0.09,0.12),Vector3(-3.13,y,1.00),"madeira")
	for i in 5: _caixa(Vector3(0.055,0.48,0.075),Vector3(-3.44+i*0.15,0.70,1.00),"madeira_escura")
	for y in [0.44,0.98]: _caixa(Vector3(0.10,0.09,1.72),Vector3(-3.49,y,0.10),"madeira")
	for i in 8: _caixa(Vector3(0.075,0.48,0.055),Vector3(-3.49,0.70,-0.70+i*0.21),"madeira_escura")
	for i in 7:
		var x := -3.49+i*0.12
		_caixa(Vector3(0.13,0.07,1.94),Vector3(x,1.97+(x+3.49)*0.19,0.10),"telha_borda")
	_caixa(Vector3(0.11,0.34,0.60),Vector3(-2.72,0.99,-0.33),"madeira_escura")
	_lanterna_pousada(Vector3(-3.12,1.40,0.85))

func _trepadeiras() -> void:
	for x in [-1.02,1.02,-3.49]:
		var ultimo := Vector3(x,0.30,1.37 if x>-2 else 1.08)
		for i in 13:
			var p := ultimo+Vector3(sin(i*1.9)*0.055,0.19,0)
			_viga(ultimo,p,0.024,"madeira_escura")
			for lado in [-1.0,1.0]: _folha_erva(p+Vector3(lado*0.06,0,0.025),Vector3(0.18,0.10,0.10))
			if i%2 == 0: _flor_jardim(p+Vector3(0,0.05,0.075),true,0.085)
			ultimo = p
