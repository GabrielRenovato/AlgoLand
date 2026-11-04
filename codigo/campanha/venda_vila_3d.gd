@tool
extends "res://codigo/campanha/venda_malha_3d.gd"
## Loja aberta com toldo volumétrico e entrada lateral; bancas em cenas independentes.

func _ready() -> void:
	_paredes()
	_interior()
	_porta_lateral()
	_janela(Vector3(-1.76,1.11,0.61),0.20)
	_telhado(Vector3(0,1.99,-0.45),4.42,1.03,0.73,false)
	_telhado(Vector3(-0.10,2.09,0.18),2.60,1.37,1.29,true)
	_frontao()
	_toldo()
	_chamine()
	_finalizar()
	definir_estacao(0)

func _paredes() -> void:
	_caixa(Vector3(4.05,1.86,0.16),Vector3(0,1.08,-0.91),"reboco_venda")
	for lado in [-1.0,1.0]: _caixa(Vector3(0.14,1.86,1.55),Vector3(lado*2.00,1.08,-0.20),"reboco_venda")
	# Ala esquerda de alvenaria e janela; abertura central tem paredes internas e fundo reais.
	for x in [-2.03,-1.47]: _caixa(Vector3(0.15,1.83,0.15),Vector3(x,1.08,0.59),"pedra")
	_caixa(Vector3(0.41,0.51,0.14),Vector3(-1.75,0.43,0.59),"reboco_venda")
	_caixa(Vector3(0.41,0.64,0.14),Vector3(-1.75,1.68,0.59),"reboco_venda")
	for x in [-1.37,1.17]:
		_caixa(Vector3(0.17,1.91,0.22),Vector3(x,1.10,1.03),"madeira")
		_caixa(Vector3(0.26,0.31,0.29),Vector3(x,0.24,1.03),"cantaria")
		_caixa(Vector3(0.18,1.72,0.62),Vector3(x,1.12,0.70),"madeira_escura")
		_ferragem(Vector3(x,1.99,1.17),Vector2(0.17,0.14))
	_caixa(Vector3(2.74,0.17,0.24),Vector3(-0.1,2.03,1.03),"madeira")
	_caixa(Vector3(2.36,0.12,0.80),Vector3(-0.1,0.16,0.63),"madeira_escura")
	for i in 12:
		_caixa(Vector3(0.185,0.065,0.77),Vector3(-1.19+i*0.198,0.23,0.64),"madeira")
	# Porta lateral em anexo de tábuas, recuado em relação ao balcão.
	for i in 9:
		var x := 1.23+i*0.092
		if x > 1.24 and x < 1.90: continue
		_caixa(Vector3(0.085,1.80,0.16),Vector3(x,1.05,0.60),"madeira")
	_caixa(Vector3(0.84,0.40,0.16),Vector3(1.62,1.80,0.60),"madeira")
	for x in [1.18,2.05]: _caixa(Vector3(0.13,1.83,0.18),Vector3(x,1.06,0.62),"madeira_escura")
	_caixa(Vector3(0.89,0.12,0.23),Vector3(1.62,1.98,0.62),"madeira_escura")
	_caixa(Vector3(4.18,0.15,1.66),Vector3(0,0.12,-0.17),"pedra_escura")
	for i in 3: _caixa(Vector3(0.88+i*0.05,0.10,0.29),Vector3(1.59,0.25-i*0.08,0.86+i*0.23),"cantaria")
	for i in 11:
		var x := -1.94+i*0.39
		if absf(x+0.10)<1.21 or absf(x-1.59)<0.42: continue
		for y in [0.23,0.39]: _caixa(Vector3(0.36,0.14,0.17),Vector3(x,y,0.69),"pedra")

func _interior() -> void:
	# O recuo entre os pilares e as prateleiras pode ser inspecionado pelas laterais.
	for i in 12: _caixa(Vector3(0.192,1.63,0.075),Vector3(-1.19+i*0.198,1.09,0.32),"madeira_escura",Color.WHITE.darkened(float(i%3)*0.025))
	for y in [0.49,0.95,1.40]:
		_caixa(Vector3(2.28,0.07,0.33),Vector3(-0.10,y,0.64),"madeira")
		for i in 6:
			var x := -1.04+i*0.37
			_pote(Vector3(x,y+0.04,0.78),["vidro_azul","vidro","saco"][i%3])
	for x in [-1.22,0.31,1.02]: _caixa(Vector3(0.075,1.40,0.10),Vector3(x,1.04,0.32),"madeira")

func _forma_arco(p: Vector3, raio: float, base_y: float, tipo: String) -> void:
	var forma := PackedVector2Array([Vector2(p.x-raio,base_y),Vector2(p.x+raio,base_y),Vector2(p.x+raio,p.y)])
	for i in range(1,13): forma.append(Vector2(p.x+cos(PI*i/12.0)*raio,p.y+sin(PI*i/12.0)*raio))
	_extrudar_xy(forma,p.z,0.07,tipo)

func _arco_madeira(p: Vector3, raio: float) -> void:
	for i in 9:
		var a := PI*i/9.0+0.018
		var b := PI*(i+1)/9.0-0.018
		_extrudar_biselado_xy(PackedVector2Array([Vector2(p.x+cos(a)*(raio+0.09),p.y+sin(a)*(raio+0.09)),Vector2(p.x+cos(b)*(raio+0.09),p.y+sin(b)*(raio+0.09)),Vector2(p.x+cos(b)*raio,p.y+sin(b)*raio),Vector2(p.x+cos(a)*raio,p.y+sin(a)*raio)]),p.z,0.12,"madeira",Color.WHITE,0.012)

func _janela(p: Vector3, raio: float) -> void:
	_forma_arco(p,raio,p.y-0.34,"vidro")
	_arco_madeira(p+Vector3(0,0,0.10),raio)
	for lado in [-1.0,1.0]: _caixa(Vector3(0.09,0.35,0.14),p+Vector3(lado*(raio+0.045),-0.175,0.045),"madeira")
	_caixa(Vector3(raio*2+0.22,0.10,0.24),p+Vector3(0,-0.39,0.07),"cantaria")
	_caixa(Vector3(0.035,0.34+raio,0.045),p+Vector3(0,(raio-0.34)*0.5,0.08),"madeira_escura")
	_caixa(Vector3(raio*2,0.033,0.045),p+Vector3(0,-0.06,0.08),"madeira_escura")
	for i in 3:
		_folha_produto(p+Vector3(-0.13+i*0.13,-0.32,0.16),Vector3(0.17,0.09,0.12))
		_volume_mercadoria(p+Vector3(-0.13+i*0.13,-0.27,0.17),Vector3(0.055,0.055,0.045),"flor")
	_caixa(Vector3(0.52,0.023,0.10),p+Vector3(0,-0.325,0.13),"neve")

func _porta_lateral() -> void:
	var p := Vector3(1.59,1.13,0.62)
	_forma_arco(p,0.29,0.30,"madeira_escura")
	for i in 5:
		var x := -0.23+i*0.115
		var altura := 1.13+sqrt(maxf(0,0.29*0.29-x*x))-0.31
		_caixa(Vector3(0.106,altura,0.04),Vector3(p.x+x,0.31+altura*0.5,0.67),"madeira")
	_arco_madeira(p+Vector3(0,0,0.13),0.31)
	for lado in [-1.0,1.0]: _caixa(Vector3(0.10,0.84,0.14),Vector3(p.x+lado*0.36,0.72,0.69),"madeira_escura")
	_forma_arco(Vector3(p.x,1.12,0.71),0.19,0.98,"vidro_azul")
	_caixa(Vector3(0.035,0.34,0.035),Vector3(p.x,1.15,0.75),"madeira")
	_caixa(Vector3(0.38,0.033,0.035),Vector3(p.x,1.12,0.75),"madeira")
	_caixa(Vector3(0.065,0.065,0.04),Vector3(p.x+0.16,0.78,0.73),"ouro")
	for y in [0.51,0.91]:
		_caixa(Vector3(0.17,0.035,0.025),Vector3(p.x-0.18,y,0.72),"ferro_escuro")
		_rebite(Vector3(p.x-0.21,y,0.75),0.014)
	# Portinhola de armazenamento sobre a entrada lateral.
	for i in 5: _caixa(Vector3(0.115,0.39,0.07),Vector3(1.35+i*0.12,1.92,0.74),"madeira")
	for y in [1.73,2.11]: _caixa(Vector3(0.65,0.055,0.09),Vector3(1.59,y,0.80),"madeira_escura")

func _frontao() -> void:
	_extrudar_xy(PackedVector2Array([Vector2(-1.45,2.09),Vector2(1.25,2.09),Vector2(-0.10,3.35)]),1.07,0.15,"reboco_venda")
	for lado in [-1.0,1.0]:
		_viga(Vector3(-0.10+lado*1.40,2.09,1.23),Vector3(-0.10,3.42,1.23),0.13,"madeira_escura")
		_viga(Vector3(-0.10+lado*0.87,2.16,1.14),Vector3(-0.10+lado*0.31,2.72,1.14),0.075,"madeira")
	_forma_arco(Vector3(-0.10,2.65,1.12),0.215,2.33,"vidro_azul")
	_arco_madeira(Vector3(-0.10,2.65,1.24),0.225)
	for lado in [-1.0,1.0]: _caixa(Vector3(0.075,0.33,0.12),Vector3(-0.10+lado*0.255,2.49,1.19),"madeira")
	_caixa(Vector3(0.03,0.54,0.04),Vector3(-0.10,2.59,1.19),"madeira")
	_caixa(Vector3(0.45,0.03,0.04),Vector3(-0.10,2.60,1.19),"madeira")
	_caixa(Vector3(0.61,0.075,0.20),Vector3(-0.10,2.30,1.20),"madeira")

func _toldo() -> void:
	var largura := 2.56
	var faixas := 9
	var passo := largura/faixas
	for i in faixas:
		var x := -0.10-largura*0.5+i*passo
		var tipo := "tecido_azul" if i%2 == 0 else "tecido_claro"
		for j in 5:
			var t0 := float(j)/5.0
			var t1 := float(j+1)/5.0
			var a := Vector3(x,2.04-0.12*t0-0.045*sin(PI*t0),1.10+t0*0.77)
			var b := Vector3(x+passo, a.y,a.z)
			var d := Vector3(x,2.04-0.12*t1-0.045*sin(PI*t1),1.10+t1*0.77)
			var c := Vector3(x+passo,d.y,d.z)
			_face(a,b,c,d,tipo,Color.WHITE.darkened(float(j%3)*0.012))
			_face(a-Vector3.UP*0.025,d-Vector3.UP*0.025,c-Vector3.UP*0.025,b-Vector3.UP*0.025,tipo,Color.WHITE.darkened(0.13))
			if j == 0: _face(a+Vector3.UP*0.025,b+Vector3.UP*0.025,b.lerp(c,0.24)+Vector3.UP*0.025,a.lerp(d,0.24)+Vector3.UP*0.025,"neve")
		# Cada faixa termina em uma aba arredondada, extrudada e independente das cores vizinhas.
		var aba := PackedVector2Array([Vector2(x,1.93),Vector2(x+passo,1.93),Vector2(x+passo,1.82)])
		for j in range(1,9): aba.append(Vector2(x+passo*0.5+cos(PI*j/8.0)*passo*0.5,1.82-sin(PI*j/8.0)*0.10))
		_extrudar_xy(aba,1.89,0.035,tipo)
	for x in [-1.41,1.21]:
		_caixa(Vector3(0.075,1.94,0.085),Vector3(x,0.99,1.84),"madeira_escura")
		_viga(Vector3(x,1.98,1.03),Vector3(x,1.91,1.88),0.06,"madeira")
		_caixa(Vector3(0.15,0.12,0.16),Vector3(x,0.09,1.84),"cantaria")
	_caixa(Vector3(2.69,0.055,0.055),Vector3(-0.10,1.90,1.86),"madeira_escura")

func _chamine() -> void:
	var p := Vector3(1.25,2.40,-0.50)
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.11,1.05,0.43),p+Vector3(lado*0.19,0.525,0),"pedra")
		_caixa(Vector3(0.28,1.05,0.11),p+Vector3(0,0.525,lado*0.19),"pedra")
	_caixa(Vector3(0.27,0.02,0.27),p+Vector3.UP*0.78,"fundo")
	for linha in 5:
		for lado in [-1.0,1.0]:
			_caixa(Vector3(0.49,0.018,0.016),p+Vector3(0,0.12+linha*0.19,lado*0.25),"junta")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.14,0.12,0.57),p+Vector3(lado*0.22,1.06,0),"cantaria")
		_caixa(Vector3(0.30,0.12,0.14),p+Vector3(0,1.06,lado*0.22),"cantaria")
		_caixa(Vector3(0.15,0.025,0.58),p+Vector3(lado*0.22,1.14,0),"neve")
		_caixa(Vector3(0.30,0.025,0.15),p+Vector3(0,1.14,lado*0.22),"neve")
