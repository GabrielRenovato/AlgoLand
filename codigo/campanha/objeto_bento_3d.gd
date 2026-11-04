@tool
extends "res://codigo/campanha/bento_malha_3d.gd"
@export_enum("canteiro_bento","vaso_bento") var tipo := "canteiro_bento"

func _ready() -> void:
	if tipo == "canteiro_bento":
		_canteiro()
	else:
		_vaso()
	_finalizar()
	definir_estacao(0)

func _canteiro() -> void:
	# Pedras baixas acompanham a base da moita, sem transformar o jardim em piso.
	for i in 10:
		var a := TAU*i/10.0
		_caixa(Vector3(0.20,0.09,0.16),Vector3(cos(a)*0.51,0.045,sin(a)*0.30),"pedra",Color.WHITE.darkened(float(i%3)*0.04))
	_flores_bento(Vector3(0,0.06,0),1.05)
	_moita(Vector3(0,0.12,0.04),0.45,true)
	for i in 5:
		var a := PI+PI*i/4.0
		_caixa(Vector3(0.18,0.022,0.10),Vector3(cos(a)*0.51,0.103,sin(a)*0.30),"neve")

func _vaso() -> void:
	_cilindro(Vector3(0,0.02,0),0.18,0.33,"madeira",Color.WHITE,12,0.23)
	for y in [0.07,0.29]: _anel(Vector3(0,y,0),0.235 if y>0.1 else 0.205,0.175,0.035,"metal",12)
	_anel(Vector3(0,0.34,0),0.245,0.195,0.055,"madeira",12)
	_cilindro(Vector3(0,0.34,0),0.19,0.02,"madeira_escura",Color.WHITE,12)
	_flores_bento(Vector3(0,0.36,0),0.54)
	_anel(Vector3(0,0.405,0),0.24,0.19,0.023,"neve",12)
