@tool
extends "res://codigo/campanha/sede_malha_3d.gd"
## Sede cívica: portal central elevado, alas de alvenaria, estandartes e escadaria larga.

func _ready() -> void:
	_estrutura()
	_portal()
	_telhado(Vector3(0,2.24,-0.36),5.84,1.06,0.70,false)
	_telhado(Vector3(0,2.76,0.19),2.72,1.32,1.72,true)
	_empena()
	for x in [-0.99,0.99]: _estandarte(Vector3(x,2.56,1.68))
	for x in [-2.33,-1.65,2.03]: _janela_sede(Vector3(x,1.49,0.75),0.18 if x<0 else 0.22)
	_finalizar()
	definir_estacao(0)

func _estrutura() -> void:
	_caixa(Vector3(5.50,2.08,0.16),Vector3(0,1.28,-0.95),"pedra_sede")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.17,2.08,1.75),Vector3(lado*2.70,1.28,-0.10),"pedra_sede")
		_caixa(Vector3(0.17,2.49,1.00),Vector3(lado*1.20,1.51,0.61),"reboco_clinica")
		# Blocos separados respeitam os três vãos das janelas das alas.
		for linha in 9:
			for coluna in 5:
				var x: float = lado*(1.43+coluna*0.29)
				var y := 0.38+linha*0.21
				var abrir := false
				for janela in [-2.33,-1.65,2.03]:
					if absf(x-janela)<0.27 and y>1.03 and y<1.81: abrir = true
				if abrir: continue
				_caixa(Vector3(0.278,0.197,0.15),Vector3(x,y,0.67),"pedra_sede",Color.WHITE.darkened(float((linha+coluna)%3)*0.025))
		for i in 10:
			_caixa(Vector3(0.19,0.22,0.24),Vector3(lado*1.26,0.37+i*0.235,1.10),"pedra_sede")
		for i in 9: _caixa(Vector3(0.23,0.22,0.22),Vector3(lado*2.72,0.36+i*0.23,0.71),"cantaria")
	_caixa(Vector3(2.38,0.40,0.18),Vector3(0,2.57,1.08),"reboco_clinica")
	for x in [-0.90,0.90]: _caixa(Vector3(0.44,1.99,0.17),Vector3(x,1.43,1.08),"reboco_clinica")
	_caixa(Vector3(5.65,0.15,1.90),Vector3(0,0.19,-0.09),"pedra_escura")
	_caixa(Vector3(2.58,0.15,0.53),Vector3(0,0.19,0.98),"pedra_escura")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(1.47,0.12,0.20),Vector3(lado*2.00,2.23,0.77),"madeira_escura")
		for x in [1.50,2.00,2.50]: _caixa(Vector3(0.09,0.15,0.24),Vector3(lado*x,2.22,0.76),"madeira")
	for i in 4:
		var y := 0.48-i*0.115
		var z := 1.26+i*0.285
		_caixa(Vector3(1.66+i*0.10,0.14,0.35),Vector3(0,y,z),"cantaria")
		_caixa(Vector3(1.66+i*0.10,0.025,0.10),Vector3(0,y+0.085,z+0.12),"neve")
	for lado in [-1.0,1.0]:
		for i in 4:
			var y := 0.65-i*0.105
			var z := 1.26+i*0.285
			_caixa(Vector3(0.19,0.29,0.29),Vector3(lado*(0.94+i*0.045),y-0.10,z),"pedra_sede")
			_caixa(Vector3(0.23,0.07,0.33),Vector3(lado*(0.94+i*0.045),y+0.08,z),"cantaria")
			_caixa(Vector3(0.23,0.022,0.25),Vector3(lado*(0.94+i*0.045),y+0.131,z),"neve")

func _portal() -> void:
	var forma := PackedVector2Array([Vector2(-0.54,0.56),Vector2(0.54,0.56),Vector2(0.54,1.66)])
	for i in range(1,13): forma.append(Vector2(cos(PI*i/12.0)*0.54,1.66+sin(PI*i/12.0)*0.54))
	_extrudar_xy(forma,1.06,0.12,"madeira_escura")
	for i in 8:
		var x := -0.47+i*0.134
		var altura := 1.66+sqrt(maxf(0,0.54*0.54-x*x))-0.57
		_caixa(Vector3(0.125,altura,0.045),Vector3(x,0.57+altura*0.5,1.10),"madeira")
	_arco_clinica(0,1.66,0.56,0.19,1.28)
	for lado in [-1.0,1.0]:
		for i in 5: _caixa(Vector3(0.18,0.21,0.22),Vector3(lado*0.65,0.67+i*0.22,1.18),"pedra_sede")
		for y in [0.82,1.40]:
			_caixa(Vector3(0.23,0.045,0.03),Vector3(lado*0.36,y,1.15),"ferro_escuro")
			_rebite(Vector3(lado*0.43,y,1.18),0.016)
		for i in 12:
			var a := TAU*i/12.0
			var b := TAU*(i+1)/12.0
			var p := Vector3(lado*0.11,1.22,1.17)
			_face(p+Vector3(cos(a),sin(a),0)*0.055,p+Vector3(cos(b),sin(b),0)*0.055,p+Vector3(cos(b),sin(b),0)*0.032,p+Vector3(cos(a),sin(a),0)*0.032,"metal")

func _janela_sede(p: Vector3, raio: float) -> void:
	var forma := PackedVector2Array([Vector2(p.x-raio,p.y-0.34),Vector2(p.x+raio,p.y-0.34),Vector2(p.x+raio,p.y)])
	for i in range(1,9): forma.append(Vector2(p.x+cos(PI*i/8.0)*raio,p.y+sin(PI*i/8.0)*raio))
	_extrudar_xy(forma,p.z,0.08,"vidro_sede")
	_arco_clinica(p.x,p.y,raio,0.08,p.z+0.13)
	for lado in [-1.0,1.0]: _caixa(Vector3(0.08,0.35,0.14),p+Vector3(lado*(raio+0.04),-0.17,0.05),"pedra_sede")
	_caixa(Vector3(raio*2+0.23,0.09,0.25),p+Vector3(0,-0.39,0.10),"cantaria")
	_caixa(Vector3(0.035,raio+0.33,0.045),p+Vector3(0,(raio-0.33)*0.5,0.06),"madeira")
	_caixa(Vector3(raio*2,0.03,0.045),p+Vector3(0,-0.07,0.06),"madeira")
	_caixa(Vector3(raio*2+0.23,0.022,0.11),p+Vector3(0,-0.33,0.16),"neve")

func _empena() -> void:
	_extrudar_xy(PackedVector2Array([Vector2(-1.27,2.76),Vector2(1.27,2.76),Vector2(0,4.46)]),1.12,0.17,"reboco_clinica")
	for lado in [-1.0,1.0]: _viga(Vector3(lado*1.36,2.76,1.57),Vector3(0,4.54,1.57),0.12,"madeira_escura")
	_janela_sede(Vector3(0,3.28,1.16),0.19)
	for x in [-0.52,0.52]:
		_folha_erva(Vector3(x,3.23,1.19),Vector3(0.18,0.08,0.10))
		_folha_erva(Vector3(x,3.29,1.18),Vector3(0.09,0.14,0.07))
	var fim := PackedVector2Array()
	for i in 12: fim.append(Vector2(cos(TAU*i/12.0)*0.09,4.55+sin(TAU*i/12.0)*0.09))
	_extrudar_biselado_xy(fim,1.64,0.065,"ouro",Color.WHITE,0.012)
