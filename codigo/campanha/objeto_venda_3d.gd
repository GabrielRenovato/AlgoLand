@tool
extends "res://codigo/campanha/venda_malha_3d.gd"
@export_enum("banca_frutas","banca_verduras","caixas_estoque","cesto_colheita","placa_espiga") var tipo := "banca_frutas"

func _ready() -> void:
	match tipo:
		"banca_frutas": _banca(false)
		"banca_verduras": _banca(true)
		"caixas_estoque": _estoque()
		"cesto_colheita": _cesto()
		"placa_espiga": _placa()
	_finalizar()
	definir_estacao(0)

func _caixote(p: Vector3, tamanho: Vector3) -> void:
	_caixa(Vector3(tamanho.x-0.04,0.045,tamanho.z),p+Vector3.UP*0.035,"madeira_escura")
	for lado in [-1.0,1.0]:
		for i in 3:
			_caixa(Vector3(tamanho.x, tamanho.y*0.27,0.045),p+Vector3(0,tamanho.y*(0.19+i*0.30),lado*(tamanho.z-0.045)*0.5),"madeira")
			_caixa(Vector3(0.045,tamanho.y*0.27,tamanho.z-0.06),p+Vector3(lado*(tamanho.x-0.045)*0.5,tamanho.y*(0.19+i*0.30),0),"madeira")
		for z in [-1.0,1.0]: _caixa(Vector3(0.06,tamanho.y+0.035,0.065),p+Vector3(lado*(tamanho.x-0.05)*0.5,tamanho.y*0.5,z*(tamanho.z-0.05)*0.5),"madeira_escura")

func _banca(verduras: bool) -> void:
	for x in [-0.43,0.43]:
		for z in [-0.22,0.23]: _caixa(Vector3(0.075,0.61,0.075),Vector3(x,0.31,z),"madeira_escura")
	for y in [0.17,0.39]: _caixa(Vector3(0.90,0.085,0.055),Vector3(0,y,0.23),"madeira")
	_caixa(Vector3(0.96,0.085,0.52),Vector3(0,0.59,0),"madeira")
	_viga(Vector3(-0.42,0.21,0.265),Vector3(0.42,0.50,0.265),0.045,"madeira_escura")
	for x in [-0.43,0.43]: _rebite(Vector3(x,0.40,0.28),0.018)
	# Duas bandejas em alturas distintas: a borda dianteira fica à frente dos produtos.
	for linha in 2:
		var z := 0.16-linha*0.27
		var y := 0.64+linha*0.15
		_caixote(Vector3(0,y-0.08,z),Vector3(0.98,0.18,0.30))
		_caixa(Vector3(0.045,0.17,0.29),Vector3(0,y+0.015,z),"madeira_escura")
		for i in 6:
			var x := -0.38+i*0.15
			var tipo_fruto: String = ("legume" if linha == 1 else "maca") if verduras else ("maca" if linha == 1 else "citrico")
			var p := Vector3(x,y+0.075,z)
			_volume_mercadoria(p,Vector3(0.15,0.14,0.15),tipo_fruto)
			if verduras and linha == 1:
				for lado in [-1.0,1.0]: _folha_produto(p+Vector3(lado*0.045,0.067,0),Vector3(0.13,0.065,0.10))
			else:
				_caixa(Vector3(0.017,0.045,0.018),p+Vector3.UP*0.082,"madeira_escura")
				if linha == 1: _folha_produto(p+Vector3(0.034,0.083,0),Vector3(0.075,0.025,0.04))
		for x in [-0.29,0.23]: _volume_mercadoria(Vector3(x,y+0.14,z-0.03),Vector3(0.15,0.14,0.15),"legume" if verduras else "maca")

func _estoque() -> void:
	_caixote(Vector3(0,0.02,0),Vector3(0.65,0.39,0.52))
	_caixote(Vector3(0.03,0.43,-0.025),Vector3(0.59,0.33,0.47))
	for i in 5: _volume_mercadoria(Vector3(-0.20+i*0.10,0.78,-0.025),Vector3(0.13,0.13,0.13),"citrico")
	_caixa(Vector3(0.24,0.075,0.025),Vector3(0,0.23,0.28),"madeira_escura")
	_caixa(Vector3(0.52,0.018,0.10),Vector3(0.03,0.79,0.17),"neve")

func _cesto() -> void:
	_cilindro(Vector3(0,0.025,0),0.18,0.25,"madeira",Color("d6b270"),12,0.24)
	for y in [0.07,0.13,0.19,0.25]: _anel(Vector3(0,y,0),0.19+y*0.20,0.18+y*0.20,0.018,"madeira_escura",12)
	_anel(Vector3(0,0.27,0),0.25,0.205,0.045,"madeira",12)
	for i in 7:
		var a := TAU*i/7.0
		_volume_mercadoria(Vector3(cos(a)*0.14,0.30+float(i%2)*0.035,sin(a)*0.13),Vector3(0.12,0.12,0.12),"maca" if i%2 else "citrico")
	var arco := PackedVector2Array()
	for i in 17:
		var a := PI*i/16.0
		arco.append(Vector2(cos(a)*0.23,0.29+sin(a)*0.30))
	for i in range(16,-1,-1):
		var a := PI*i/16.0
		arco.append(Vector2(cos(a)*0.20,0.29+sin(a)*0.26))
	_extrudar_xy(arco,-0.015,0.035,"madeira_escura")

func _placa() -> void:
	_caixa(Vector3(0.12,1.93,0.13),Vector3(0.30,0.97,0),"madeira_escura")
	_caixa(Vector3(0.21,0.17,0.22),Vector3(0.30,0.10,0),"cantaria")
	_caixa(Vector3(0.87,0.11,0.14),Vector3(-0.04,1.87,0),"madeira")
	_viga(Vector3(0.30,1.44,0),Vector3(-0.09,1.82,0),0.06,"madeira_escura")
	for x in [-0.29,0.12]:
		_viga(Vector3(x,1.82,0),Vector3(x,1.61,0),0.022,"ouro")
		_rebite(Vector3(x,1.88,0.09),0.024)
	var forma := PackedVector2Array([Vector2(-0.42,1.62),Vector2(0.25,1.62),Vector2(0.25,1.13),Vector2(-0.085,0.99),Vector2(-0.42,1.13)])
	_extrudar_biselado_xy(forma,0.07,0.11,"madeira")
	for i in forma.size(): forma[i] = Vector2(-0.085,1.33)+(forma[i]-Vector2(-0.085,1.33))*0.85
	_extrudar_xy(forma,0.10,0.045,"placa_verde")
	_espiga(Vector3(-0.085,1.10,0.145),0.39)
	_espiga(Vector3(-0.22,1.16,0.14),0.25)
	_espiga(Vector3(0.05,1.16,0.14),0.25)
	_caixa(Vector3(0.87,0.025,0.14),Vector3(-0.04,1.95,0),"neve")
