@tool
extends "res://codigo/campanha/mistica_malha_3d.gd"
@export_enum("placa_lua","canteiro_lavanda","vaso_ervas","barril_ingredientes") var tipo := "placa_lua"

func _ready() -> void:
	match tipo:
		"placa_lua": _placa()
		"canteiro_lavanda": _canteiro()
		"vaso_ervas": _vaso()
		"barril_ingredientes": _barril()
	_finalizar()
	definir_estacao(0)

func _placa() -> void:
	_caixa(Vector3(0.13,1.90,0.14),Vector3(-0.35,0.95,0),"madeira")
	_caixa(Vector3(0.23,0.17,0.24),Vector3(-0.35,0.11,0),"cantaria")
	_caixa(Vector3(0.92,0.11,0.14),Vector3(0,1.83,0),"madeira")
	_viga(Vector3(-0.35,1.36,0),Vector3(0.04,1.78,0),0.07,"madeira_escura")
	for x in [-0.17,0.27]:
		_viga(Vector3(x,1.77,0),Vector3(x,1.52,0),0.024,"ouro")
		_rebite(Vector3(x,1.80,0.09),0.028)
	var forma := PackedVector2Array([Vector2(-0.30,0.88),Vector2(0.39,0.88),Vector2(0.43,0.94),Vector2(0.43,1.48),Vector2(0.37,1.54),Vector2(-0.28,1.54),Vector2(-0.34,1.48),Vector2(-0.34,0.94)])
	_extrudar_biselado_xy(forma,0.08,0.12,"madeira_escura")
	_caixa(Vector3(0.64,0.54,0.045),Vector3(0.045,1.21,0.10),"ametista")
	for y in [0.92,1.50]: _caixa(Vector3(0.68,0.035,0.035),Vector3(0.045,y,0.14),"ouro")
	_lua(Vector3(0.045,1.21,0.16),0.20)
	_caixa(Vector3(0.91,0.035,0.14),Vector3(0,1.91,0),"neve")

func _canteiro() -> void:
	_caixa(Vector3(1.16,0.10,0.48),Vector3(0,0.07,0),"pedra_escura")
	_caixa(Vector3(1.05,0.055,0.38),Vector3(0,0.14,0),"madeira_escura")
	for lado in [-1.0,1.0]:
		for i in 6: _caixa(Vector3(0.185,0.16,0.12),Vector3(-0.49+i*0.196,0.13,lado*0.24),"cantaria",Color.WHITE.darkened(float(i%3)*0.025))
	for x in [-0.58,0.58]: _caixa(Vector3(0.12,0.16,0.40),Vector3(x,0.13,0),"cantaria")
	for i in 11:
		var p := Vector3(-0.46+float(i%6)*0.18,0.17,-0.12+float(i/6)*0.21)
		_ramo(p,0.37+float((i*7)%4)*0.075)
		for lado in [-1.0,1.0]: _folha_volume(p+Vector3(lado*0.035,0.09,0),Vector3(0.16,0.055,0.10))
	for i in 5:
		_folha_volume(Vector3(-0.40+i*0.20,0.20,0.22),Vector3(0.11,0.055,0.10),"flor")
	_caixa(Vector3(1.16,0.027,0.10),Vector3(0,0.23,0.25),"neve")

func _vaso() -> void:
	_cilindro(Vector3(0,0.02,0),0.14,0.27,"telha_borda",Color("c7a383"),10,0.20)
	_anel(Vector3(0,0.26,0),0.215,0.17,0.065,"telha_borda",10)
	_cilindro(Vector3(0,0.27,0),0.168,0.025,"madeira_escura",Color.WHITE,10)
	for i in 9:
		var a := TAU*i/9.0
		var p := Vector3(cos(a)*0.14,0.46+float(i%3)*0.055,sin(a)*0.13)
		_viga(Vector3(0,0.29,0),p,0.02,"folha")
		_folha_volume(p,Vector3(0.19,0.10,0.13))
	_anel(Vector3(0,0.33,0),0.205,0.165,0.02,"neve",10)

func _barril() -> void:
	for i in 12:
		var a := TAU*i/12.0
		var b := TAU*(i+1)/12.0-0.025
		for j in 3:
			var y := j*0.18
			var r0 := 0.22+sin(float(j)*PI/3.0)*0.035
			var r1 := 0.22+sin(float(j+1)*PI/3.0)*0.035
			_face(Vector3(cos(a)*r0,y,sin(a)*r0),Vector3(cos(b)*r0,y,sin(b)*r0),Vector3(cos(b)*r1,y+0.18,sin(b)*r1),Vector3(cos(a)*r1,y+0.18,sin(a)*r1),"madeira",Color.WHITE.darkened(float(i%3)*0.03))
	for y in [0.06,0.43]: _anel(Vector3(0,y,0),0.26,0.235,0.05,"ouro",12)
	_anel(Vector3(0,0.53,0),0.235,0.192,0.045,"madeira",12)
	_cilindro(Vector3(0,0.48,0),0.192,0.015,"fundo",Color.WHITE,12)
	for i in 8:
		var a := TAU*i/8.0
		_folha_volume(Vector3(cos(a)*0.13,0.52+float(i%2)*0.025,sin(a)*0.12),Vector3(0.075,0.07,0.065),"lavanda")
	_anel(Vector3(0,0.58,0),0.23,0.185,0.018,"neve",12)
