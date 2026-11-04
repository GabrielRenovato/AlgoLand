@tool
extends "res://codigo/campanha/pousada_malha_3d.gd"
@export_enum("placa_chave","jardineira_chao","vaso_pousada") var tipo := "placa_chave"

func _ready() -> void:
	match tipo:
		"placa_chave": _placa()
		"jardineira_chao": _floreira()
		"vaso_pousada": _vaso()
	_finalizar()
	definir_estacao(0)

func _placa() -> void:
	_caixa(Vector3(0.13,2.92,0.14),Vector3(0.29,1.46,0),"madeira_escura")
	_caixa(Vector3(0.24,0.20,0.25),Vector3(0.29,0.12,0),"cantaria")
	_caixa(Vector3(1.02,0.12,0.14),Vector3(-0.08,2.84,0),"madeira")
	_viga(Vector3(0.29,2.40,0),Vector3(-0.14,2.78,0),0.07,"madeira_escura")
	for x in [-0.38,0.12]:
		_viga(Vector3(x,2.78,0),Vector3(x,2.55,0),0.022,"ouro")
		_rebite(Vector3(x,2.84,0.09),0.024)
	var contorno := PackedVector2Array([Vector2(-0.50,2.57),Vector2(0.25,2.57),Vector2(0.25,1.67),Vector2(-0.125,1.51),Vector2(-0.50,1.67)])
	_extrudar_biselado_xy(contorno,0.10,0.12,"ouro")
	for i in contorno.size(): contorno[i] = Vector2(-0.125,2.08)+(contorno[i]-Vector2(-0.125,2.08))*0.88
	_extrudar_xy(contorno,0.13,0.055,"veneziana")
	# Argola vazada e dentes da chave modelados à frente da placa.
	var centro := Vector3(-0.125,2.31,0.19)
	for i in 20:
		var a := TAU*i/20.0
		var b := TAU*(i+1)/20.0
		var pontos := PackedVector2Array([Vector2(centro.x+cos(a)*0.12,centro.y+sin(a)*0.12),Vector2(centro.x+cos(b)*0.12,centro.y+sin(b)*0.12),Vector2(centro.x+cos(b)*0.075,centro.y+sin(b)*0.075),Vector2(centro.x+cos(a)*0.075,centro.y+sin(a)*0.075)])
		_extrudar_xy(pontos,centro.z,0.035,"ouro")
	_caixa(Vector3(0.045,0.45,0.045),Vector3(-0.125,1.99,0.17),"ouro")
	for y in [1.80,1.91]: _caixa(Vector3(0.13,0.045,0.045),Vector3(-0.17,y,0.17),"ouro")
	_caixa(Vector3(1.02,0.027,0.14),Vector3(-0.08,2.92,0),"neve")

func _floreira() -> void:
	for i in 3: _caixa(Vector3(0.94,0.095,0.045),Vector3(0,0.12+i*0.10,0.24),"madeira")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.065,0.36,0.53),Vector3(lado*0.45,0.20,0),"madeira_escura")
		_caixa(Vector3(0.92,0.34,0.04),Vector3(0,0.21,lado*0.24),"madeira_escura")
	_caixa(Vector3(0.84,0.06,0.44),Vector3(0,0.32,0),"madeira_escura")
	for i in 4: _moita(Vector3(-0.30+i*0.20,0.34,0),0.38,true)
	for x in [-0.34,0.34]: _caixa(Vector3(0.10,0.10,0.43),Vector3(x,0.055,0),"madeira_escura")
	_caixa(Vector3(0.93,0.027,0.10),Vector3(0,0.39,0.23),"neve")

func _vaso() -> void:
	_cilindro(Vector3(0,0.02,0),0.12,0.24,"madeira",Color.WHITE,10,0.18)
	_anel(Vector3(0,0.25,0),0.19,0.15,0.055,"madeira_escura",10)
	_moita(Vector3(0,0.29,0),0.40,true)
	_anel(Vector3(0,0.31,0),0.19,0.15,0.025,"neve",10)
