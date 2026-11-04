@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
@export_enum("bigorna", "bancada", "barril", "estante", "suporte", "balde") var tipo := "bigorna"

func _ready() -> void:
	match tipo:
		"bigorna": _bigorna()
		"bancada": _bancada()
		"barril": _barril()
		"estante": _estante()
		"suporte": _suporte()
		"balde": _balde()
	_finalizar()
	definir_estacao(0)

func _bigorna() -> void:
	# Peça única de ferro, com cintura, pé alargado, mesa e chifre afunilado.
	_extrudar_biselado_xy(PackedVector2Array([Vector2(-0.28,0.53),Vector2(0.30,0.53),Vector2(0.30,0.41),Vector2(0.13,0.37),Vector2(0.09,0.19),Vector2(0.24,0.11),Vector2(0.24,0.04),Vector2(-0.25,0.04),Vector2(-0.25,0.11),Vector2(-0.10,0.19),Vector2(-0.14,0.38),Vector2(-0.28,0.41)]),0.16,0.32,"metal")
	_extrudar_biselado_xy(PackedVector2Array([Vector2(-0.28,0.52),Vector2(-0.62,0.47),Vector2(-0.43,0.40),Vector2(-0.27,0.40)]),0.11,0.22,"metal")
	_caixa(Vector3(0.62,0.025,0.33),Vector3(0.01,0.54,0),"metal",Color("dadbd7"))
	_caixa(Vector3(0.055,0.009,0.055),Vector3(0.20,0.557,0),"ferro_escuro")
	_caixa(Vector3(0.61,0.06,0.44),Vector3(0,0.03,0),"pedra_escura")

func _bancada() -> void:
	for z in [-0.19,-0.06,0.07,0.20]:
		_caixa(Vector3(0.91,0.075,0.12),Vector3(0,0.57,z),"madeira")
	for x in [-0.34,0.34]:
		for z in [-0.15,0.15]: _caixa(Vector3(0.085,0.52,0.085),Vector3(x,0.27,z),"madeira_escura")
		_caixa(Vector3(0.09,0.08,0.45),Vector3(x,0.19,0),"madeira")
	_caixa(Vector3(0.73,0.08,0.09),Vector3(0,0.15,0),"madeira")
	_cilindro(Vector3(0.13,0.61,-0.04),0.105,0.15,"ferro_escuro",Color.WHITE,8)
	for i in 3:
		var x := 0.08+i*0.045
		_viga(Vector3(x,0.68,-0.04),Vector3(x-0.07+i*0.045,0.95,-0.04),0.025,"madeira")
		_caixa(Vector3(0.12,0.055,0.055),Vector3(x-0.07+i*0.045,0.95,-0.04),"metal")
	_cilindro(Vector3(-0.23,0.61,0.03),0.048,0.13,"vidro",Color.WHITE,6)
	_cilindro(Vector3(-0.23,0.74,0.03),0.02,0.05,"ouro",Color.WHITE,6)
	_caixa(Vector3(0.09,0.06,0.09),Vector3(0.32,0.64,0.08),"ouro")
	_caixa(Vector3(0.23,0.016,0.10),Vector3(-0.33,0.617,0.20),"neve")

func _barril() -> void:
	for i in 12:
		var a := TAU*i/12.0+0.008
		var b := TAU*(i+1)/12.0-0.008
		var cor := Color.WHITE.darkened(float(i%3)*0.05)
		for nivel in 2:
			var r0 := 0.19 if nivel == 0 else 0.23
			var r1 := 0.23 if nivel == 0 else 0.19
			var y0 := nivel*0.27+0.02
			var y1 := y0+0.27
			_face(Vector3(cos(a)*r0,y0,sin(a)*r0),Vector3(cos(b)*r0,y0,sin(b)*r0),Vector3(cos(b)*r1,y1,sin(b)*r1),Vector3(cos(a)*r1,y1,sin(a)*r1),"madeira",cor)
	for y in [0.10,0.43]:
		_anel(Vector3(0,y,0),0.224,0.211,0.055,"metal")
		for x in [-0.12,0.12]: _rebite(Vector3(x,y+0.028,sqrt(0.224*0.224-x*x)+0.008),0.020)
	_cilindro(Vector3(0,0.50,0),0.183,0.03,"madeira_escura")
	for x in [-0.12,-0.04,0.04,0.12]:
		var comprimento := sqrt(0.18*0.18-x*x)*2
		_caixa(Vector3(0.074,0.024,comprimento),Vector3(x,0.55,0),"madeira")
	_anel(Vector3(0,0.535,0),0.199,0.18,0.025,"madeira_escura")
	_anel(Vector3(0,0.56,0),0.197,0.165,0.014,"neve")

func _estante() -> void:
	for x in [-0.31,0.31]: _caixa(Vector3(0.08,1.30,0.10),Vector3(x,0.66,-0.11),"madeira_escura")
	for y in [0.09,0.47,0.85,1.22]: _caixa(Vector3(0.76,0.065,0.4),Vector3(0,y,0),"madeira")
	for z in [-0.13,0.13]: _caixa(Vector3(0.7,0.16,0.04),Vector3(0,1.22,z),"madeira")
	for x in [-0.22,-0.03,0.17]:
		_viga(Vector3(x,0.94,0.20),Vector3(x,1.15,0.20),0.026,"metal")
		_caixa(Vector3(0.14,0.05,0.045),Vector3(x,0.94,0.20),"metal")
		_caixa(Vector3(0.03,0.1,0.045),Vector3(x-0.055,0.99,0.20),"metal")
		_caixa(Vector3(0.03,0.1,0.045),Vector3(x+0.055,0.99,0.20),"metal")
	for i in 4:
		_caixa(Vector3(0.12,0.11,0.16),Vector3(-0.23+i*0.15,0.56,0),"metal",Color.WHITE.darkened(i*0.06))
	for y in [0.16,0.24,0.32]: _caixa(Vector3(0.53,0.06,0.22),Vector3(0,y,0),"madeira")
	_caixa(Vector3(0.47,0.018,0.12),Vector3(-0.1,1.263,-0.07),"neve")

func _suporte() -> void:
	for x in [-0.22,0.22]: _caixa(Vector3(0.065,1.10,0.07),Vector3(x,0.55,-0.04),"madeira_escura")
	for y in [0.15,0.7,1.04]: _caixa(Vector3(0.58,0.07,0.11),Vector3(0,y,-0.04),"madeira")
	# Tenaz articulada, atiçador com gancho e martelo têm silhuetas distintas.
	for lado in [-1.0,1.0]:
		_viga(Vector3(-0.16+lado*0.055,0.07,0.13),Vector3(-0.16-lado*0.025,0.70,0.12),0.033,"metal")
		_viga(Vector3(-0.16-lado*0.025,0.70,0.12),Vector3(-0.16+lado*0.065,0.89,0.12),0.033,"metal")
		_viga(Vector3(-0.16+lado*0.065,0.89,0.12),Vector3(-0.16+lado*0.035,1.0,0.12),0.033,"metal")
	_rebite(Vector3(-0.16,0.70,0.15),0.023)
	_viga(Vector3(0,0.05,0.12),Vector3(0,0.97,0.12),0.035,"metal")
	_viga(Vector3(0,0.97,0.12),Vector3(0.07,1.01,0.12),0.035,"metal")
	_viga(Vector3(0.07,1.01,0.12),Vector3(0.09,0.96,0.12),0.035,"metal")
	_viga(Vector3(0.19,0.05,0.12),Vector3(0.19,0.92,0.12),0.042,"madeira")
	_caixa(Vector3(0.18,0.09,0.09),Vector3(0.19,0.96,0.12),"metal")
	_caixa(Vector3(0.18,0.012,0.09),Vector3(0.19,1.011,0.12),"metal_claro")
	for x in [-0.22,0.22]: _caixa(Vector3(0.08,0.08,0.35),Vector3(x,0.04,0),"madeira")

func _balde() -> void:
	_cilindro(Vector3.ZERO,0.12,0.24,"madeira",Color.WHITE,10,0.15)
	_anel(Vector3(0,0.23,0),0.157,0.128,0.035,"metal",10)
	_cilindro(Vector3(0,0.245,0),0.125,0.005,"fundo")
	for lado in [-1.0,1.0]: _viga(Vector3(lado*0.15,0.23,0),Vector3(lado*0.1,0.4,0),0.018,"metal")
	_viga(Vector3(-0.1,0.4,0),Vector3(0.1,0.4,0),0.025,"madeira_escura")
