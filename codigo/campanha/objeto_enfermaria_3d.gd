@tool
extends "res://codigo/campanha/enfermaria_malha_3d.gd"
@export_enum("placa_cruz","canteiro_rosas","canteiro_margaridas","vaso_medicinal") var tipo := "placa_cruz"

func _ready() -> void:
	match tipo:
		"placa_cruz": _placa()
		"canteiro_rosas": _canteiro(true)
		"canteiro_margaridas": _canteiro(false)
		"vaso_medicinal": _vaso()
	_finalizar()
	definir_estacao(0)

func _placa() -> void:
	_caixa(Vector3(0.14,1.77,0.15),Vector3(0.33,0.90,0),"madeira")
	_caixa(Vector3(0.23,0.17,0.24),Vector3(0.33,0.10,0),"cantaria")
	_caixa(Vector3(0.91,0.13,0.16),Vector3(0,1.73,0),"madeira")
	_viga(Vector3(0.33,1.29,0),Vector3(-0.05,1.69,0),0.075,"madeira_escura")
	for x in [-0.25,0.15]:
		_viga(Vector3(x,1.68,0),Vector3(x,1.45,0),0.022,"metal")
		_rebite(Vector3(x,1.74,0.09),0.027)
	_caixa(Vector3(0.70,0.65,0.105),Vector3(-0.06,1.12,0.035),"madeira_escura")
	_caixa(Vector3(0.58,0.53,0.025),Vector3(-0.06,1.12,0.10),"reboco_clinica")
	_cruz(Vector3(-0.06,1.12,0.145),0.34)
	for x in [-0.36,0.24]:
		for y in [0.85,1.39]: _rebite(Vector3(x,y,0.10),0.019)
	_caixa(Vector3(0.91,0.026,0.16),Vector3(0,1.81,0),"neve")

func _canteiro(rosa: bool) -> void:
	# Borda acompanha os cantos; o canteiro é um objeto removível sobre o chão real.
	_caixa(Vector3(1.12,0.09,0.55),Vector3(0,0.07,0),"pedra_escura")
	_caixa(Vector3(0.98,0.06,0.45),Vector3(0,0.13,0),"madeira_escura")
	for lado in [-1.0,1.0]:
		for i in 6: _caixa(Vector3(0.18,0.18,0.13),Vector3(-0.49+i*0.196,0.13,lado*0.275),"pedra",Color.WHITE.lightened(float(i%3)*0.04))
	for x in [-0.57,0.57]: _caixa(Vector3(0.12,0.18,0.45),Vector3(x,0.13,0),"cantaria")
	for i in 5:
		_moita(Vector3(-0.39+i*0.195,0.15,-0.03+float(i%2)*0.15),0.40,rosa)
	_caixa(Vector3(1.16,0.027,0.11),Vector3(0,0.24,0.27),"neve")

func _vaso() -> void:
	_cilindro(Vector3(0,0.02,0),0.13,0.25,"telha_borda",Color("c19c7a"),10,0.18)
	_anel(Vector3(0,0.25,0),0.195,0.155,0.065,"telha_borda",10)
	_cilindro(Vector3(0,0.27,0),0.153,0.017,"madeira_escura",Color.WHITE,10)
	for i in 5:
		var a := TAU*i/5.0
		var inicio := Vector3(cos(a)*0.065,0.29,sin(a)*0.065)
		var fim := inicio+Vector3(cos(a)*0.07,0.33+float(i%2)*0.09,sin(a)*0.07)
		_viga(inicio,fim,0.018,"folha")
		for j in 3:
			var p := inicio.lerp(fim,0.33+j*0.22)
			for lado in [-1.0,1.0]: _folha_erva(p+Vector3(lado*0.05,0,0),Vector3(0.12,0.055,0.085))
	_anel(Vector3(0,0.32,0),0.19,0.15,0.02,"neve",10)
