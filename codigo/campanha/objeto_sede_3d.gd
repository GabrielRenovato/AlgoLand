@tool
extends "res://codigo/campanha/sede_malha_3d.gd"
@export_enum("jardim_sede","luminaria_sede","vaso_pedestal") var tipo := "jardim_sede"

func _ready() -> void:
	match tipo:
		"jardim_sede": _jardim()
		"luminaria_sede": _poste_sede()
		"vaso_pedestal": _vaso()
	_finalizar()
	definir_estacao(0)

func _jardim() -> void:
	# Elipse fechada: blocos e plantas são peças próprias, nunca piso pintado no mapa.
	for i in 16:
		var a := TAU*i/16.0
		var b := TAU*(i+1)/16.0
		_triangulo(Vector3(0,0.18,0),Vector3(cos(a)*0.65,0.18,sin(a)*0.38),Vector3(cos(b)*0.65,0.18,sin(b)*0.38),"madeira_escura")
	for i in 16:
		var a := TAU*i/16.0
		var b := TAU*(i+1)/16.0-0.025
		var p0 := Vector3(cos(a)*0.79,0.04,sin(a)*0.52)
		var p1 := Vector3(cos(b)*0.79,0.04,sin(b)*0.52)
		var p2 := Vector3(cos(b)*0.65,0.04,sin(b)*0.38)
		var p3 := Vector3(cos(a)*0.65,0.04,sin(a)*0.38)
		_face(p0,p1,p1+Vector3.UP*0.25,p0+Vector3.UP*0.25,"pedra_sede")
		_face(p3,p2,p2+Vector3.UP*0.25,p3+Vector3.UP*0.25,"pedra_sede")
		_face(p0+Vector3.UP*0.25,p1+Vector3.UP*0.25,p2+Vector3.UP*0.25,p3+Vector3.UP*0.25,"cantaria")
		_face(p0+Vector3.UP*0.28,p1+Vector3.UP*0.28,p2+Vector3.UP*0.28,p3+Vector3.UP*0.28,"neve")
	for i in 9:
		var a := TAU*i/9.0
		_moita(Vector3(cos(a)*0.45,0.17,sin(a)*0.25),0.45,i%2 == 0)
	_moita(Vector3(0,0.28,-0.03),0.56,true)

func _vaso() -> void:
	_caixa(Vector3(0.30,0.11,0.30),Vector3(0,0.06,0),"pedra_sede")
	_cilindro(Vector3(0,0.11,0),0.10,0.27,"cantaria",Color.WHITE,8)
	_cilindro(Vector3(0,0.37,0),0.14,0.17,"pedra_sede",Color.WHITE,10,0.20)
	_anel(Vector3(0,0.53,0),0.22,0.17,0.055,"cantaria",10)
	_moita(Vector3(0,0.56,0),0.47,true)
	_anel(Vector3(0,0.59,0),0.22,0.17,0.025,"neve",10)
