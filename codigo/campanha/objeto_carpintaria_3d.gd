@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
@export_enum("bancada_marceneiro", "painel_ferramentas", "toras", "pilha_tabuas", "cavalete", "estante_carpinteiro") var tipo := "cavalete"
@export var abrigado := false

func _ready() -> void:
	match tipo:
		"bancada_marceneiro": _bancada()
		"painel_ferramentas": _painel()
		"toras": _toras()
		"pilha_tabuas": _tabuas()
		"cavalete": _cavalete()
		"estante_carpinteiro": _estante()
	_finalizar()
	definir_estacao(0)

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	if abrigado and _instancias.has("neve"): _instancias["neve"].visible = false

func _bancada() -> void:
	for z in [-0.20,0.0,0.20]:
		_caixa(Vector3(1.30,0.09,0.19),Vector3(0,0.69,z),"madeira")
	for x in [-0.49,0.49]:
		for z in [-0.20,0.20]:
			_caixa(Vector3(0.13,0.64,0.14),Vector3(x,0.34,z),"madeira")
		_caixa(Vector3(0.15,0.12,0.55),Vector3(x,0.19,0),"madeira_escura")
	_caixa(Vector3(1.08,0.10,0.12),Vector3(0,0.22,0),"madeira_escura")
	_caixa(Vector3(0.16,0.22,0.33),Vector3(0.68,0.59,0.09),"madeira_escura")
	_viga(Vector3(0.81,0.48,0.09),Vector3(0.81,0.75,0.09),0.03,"metal")
	# Plaina e peça de madeira apoiadas no tampo.
	_caixa(Vector3(0.24,0.065,0.12),Vector3(-0.11,0.77,0.05),"madeira_escura")
	_caixa(Vector3(0.08,0.12,0.08),Vector3(-0.10,0.84,0.05),"metal",Color.WHITE,Basis(Vector3.BACK,-0.30))
	_tora(Vector3(-0.35,0.84,-0.03),0.11,0.20)
	_caixa(Vector3(0.18,0.018,0.12),Vector3(0.44,0.748,0.22),"neve")

func _painel() -> void:
	for y in [0.91,1.12,1.33]:
		_caixa(Vector3(1.29,0.20,0.07),Vector3(0,y,0),"madeira_escura")
	for x in [-0.58,0.58]: _caixa(Vector3(0.055,0.64,0.09),Vector3(x,1.12,0.02),"madeira")
	# Serrote com lâmina dentada e cabo vazado em madeira.
	_extrudar_xy(PackedVector2Array([Vector2(-0.52,1.38),Vector2(-0.29,1.38),Vector2(-0.29,1.32),Vector2(-0.45,1.32),Vector2(-0.45,1.20),Vector2(-0.29,1.20),Vector2(-0.29,1.14),Vector2(-0.52,1.14)]),0.11,0.045,"madeira")
	var lamina := PackedVector2Array([Vector2(-0.29,1.35),Vector2(0.15,1.30),Vector2(0.15,1.25)])
	for i in 8:
		var x := 0.15-i*0.055
		lamina.append(Vector2(x,1.25-i*0.008))
		lamina.append(Vector2(x-0.027,1.22-i*0.008))
	lamina.append(Vector2(-0.29,1.17))
	_extrudar_xy(lamina,0.12,0.02,"metal")
	for i in 3:
		var x := 0.26+i*0.12
		_caixa(Vector3(0.065,0.17,0.06),Vector3(x,1.31,0.10),"madeira")
		_caixa(Vector3(0.050,0.22,0.025),Vector3(x,1.115,0.10),"metal")
	_viga(Vector3(-0.36,0.88,0.11),Vector3(-0.36,1.10,0.11),0.04,"madeira")
	_caixa(Vector3(0.18,0.07,0.075),Vector3(-0.36,1.10,0.11),"metal")
	_caixa(Vector3(0.14,0.04,0.11),Vector3(0,0.88,0.11),"madeira")

func _toras() -> void:
	for x in [-0.36,0.0,0.36]: _tora(Vector3(x,0.18,0.49),0.17,1.0)
	for x in [-0.18,0.18]: _tora(Vector3(x,0.48,0.46),0.17,1.03)
	_caixa(Vector3(0.32,0.025,0.21),Vector3(0.12,0.77,-0.22),"neve")

func _tora(p: Vector3, raio: float, comprimento: float) -> void:
	var fim := p+Vector3(0.025,comprimento*0.11,-comprimento)
	for i in 10:
		var a := TAU*i/10.0
		var b := TAU*(i+1)/10.0
		var va := Vector3(cos(a)*raio,sin(a)*raio,0)
		var vb := Vector3(cos(b)*raio,sin(b)*raio,0)
		_face(p+va,p+vb,fim+vb*0.95,fim+va*0.95,"madeira",Color("ba9463").darkened(float(i%3)*0.025))
		_triangulo(p,p+va,p+vb,"cerne")
		_triangulo(fim,fim+vb*0.95,fim+va*0.95,"cerne",Color("d1b27d"))
		var r0 := raio*0.35
		var r1 := raio*0.62
		_face(p+Vector3(cos(a)*r0,sin(a)*r0,0.008),p+Vector3(cos(b)*r0,sin(b)*r0,0.008),p+Vector3(cos(b)*r1,sin(b)*r1,0.008),p+Vector3(cos(a)*r1,sin(a)*r1,0.008),"cerne_escuro")

func _tabuas() -> void:
	for camada in 4:
		var y := 0.10+camada*0.13
		for z in [-0.25,-0.08,0.09,0.26]:
			_caixa(Vector3(1.03+float(camada%2)*0.07,0.08,0.16),Vector3(float(camada%3)*0.025,y,z),"madeira",Color.WHITE.darkened(camada*0.018))
		for x in [-0.35,0.35]: _caixa(Vector3(0.07,0.045,0.57),Vector3(x,y+0.062,0),"madeira_escura")
	_caixa(Vector3(0.33,0.018,0.45),Vector3(-0.32,0.547,0.03),"neve")

func _cavalete() -> void:
	for x in [-0.57,0.57]:
		for lado in [-1.0,1.0]:
			_viga(Vector3(x+lado*0.08,0.05,lado*0.28),Vector3(x,0.61,0),0.115,"madeira")
		_caixa(Vector3(0.16,0.07,0.53),Vector3(x,0.19,0),"madeira_escura")
	_caixa(Vector3(1.77,0.14,0.31),Vector3(0,0.62,0),"madeira")
	_caixa(Vector3(1.65,0.11,0.22),Vector3(0,0.745,0),"madeira")
	for x in [-0.55,0.55]:
		_caixa(Vector3(0.07,0.17,0.06),Vector3(x,0.76,0.14),"metal")
		_caixa(Vector3(0.10,0.065,0.29),Vector3(x,0.84,0),"metal")
		_rebite(Vector3(x,0.77,0.18),0.026)
	_caixa(Vector3(0.34,0.018,0.19),Vector3(0.15,0.809,-0.01),"neve")

func _estante() -> void:
	for x in [-0.27,0.27]: _caixa(Vector3(0.07,1.04,0.08),Vector3(x,0.53,-0.06),"madeira_escura")
	for y in [0.10,0.48,0.92]: _caixa(Vector3(0.67,0.065,0.39),Vector3(0,y,0),"madeira")
	_caixa(Vector3(0.43,0.23,0.28),Vector3(0,0.25,0),"madeira")
	_caixa(Vector3(0.15,0.07,0.30),Vector3(-0.12,0.54,0),"madeira_escura")
	_caixa(Vector3(0.08,0.14,0.10),Vector3(-0.12,0.62,0),"metal",Color.WHITE,Basis(Vector3.BACK,-0.3))
	_caixa(Vector3(0.11,0.09,0.32),Vector3(0.18,0.55,0),"madeira")
	_viga(Vector3(-0.16,0.97,-0.05),Vector3(0.17,0.97,-0.05),0.07,"madeira_escura")
	_caixa(Vector3(0.27,0.018,0.14),Vector3(-0.17,0.961,-0.06),"neve")
