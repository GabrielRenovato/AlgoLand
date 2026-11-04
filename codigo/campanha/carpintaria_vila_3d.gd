@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
## Galpão aberto de marcenaria. Bancada e painel são instâncias independentes na cena.

func _ready() -> void:
	_estrutura()
	_telhado(Vector3(0,1.82,-0.02),2.16,1.42,1.06,true)
	_cobertura_lateral(-1.0,1.12)
	_cobertura_lateral(1.0,0.91)
	_chamine_fina()
	_finalizar()
	definir_estacao(0)

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for filho in get_children():
		if filho.has_method("definir_estacao"): filho.definir_estacao(estacao)

func _estrutura() -> void:
	# Piso estrutural do galpão, apoiado no terreno existente e visível entre os pés da bancada.
	for i in 14:
		_caixa(Vector3(0.17,0.075,1.75),Vector3(-1.105+i*0.17,0.055,0.02),"madeira_escura",Color.WHITE.darkened(float(i%3)*0.02))
	# Placas de fundo e laterais deixam uma área real de trabalho recuada.
	for i in 13:
		var x := -1.2+i*0.20
		_caixa(Vector3(0.19,1.70,0.10),Vector3(x,0.91,-0.83),"madeira_escura",Color.WHITE.lightened(float(i%3)*0.035))
	for y in [0.22,0.95,1.70]:
		_caixa(Vector3(2.62,0.12,0.12),Vector3(0,y,-0.75),"madeira")
	_extrudar_xy(PackedVector2Array([Vector2(-1.28,1.76),Vector2(1.28,1.76),Vector2(0,2.79)]),-0.75,0.12,"madeira_escura")
	for lado in [-1.0,1.0]:
		for z in [-0.79,0.84]:
			_caixa(Vector3(0.18,1.84,0.19),Vector3(lado*1.20,0.98,z),"madeira")
			_caixa(Vector3(0.26,0.19,0.27),Vector3(lado*1.20,0.13,z),"pedra_escura")
		for i in 7:
			var z := -0.73+i*0.23
			_caixa(Vector3(0.10,1.27,0.215),Vector3(lado*1.25,0.70,z),"madeira_escura")
		_viga(Vector3(lado*1.20,1.27,0.88),Vector3(lado*0.76,1.80,0.88),0.14,"madeira")
		_viga(Vector3(lado*1.35,1.84,1.02),Vector3(0,2.82,1.02),0.15,"madeira_escura")
		_viga(Vector3(lado*0.65,1.91,0.96),Vector3(0,2.62,0.96),0.10,"madeira")
		_caixa(Vector3(0.055,0.055,0.025),Vector3(lado*1.20,1.78,1.00),"metal")
		_ferragem(Vector3(lado*1.20,1.82,1.065))
		_caixa(Vector3(0.20,0.08,0.21),Vector3(lado*1.20,0.25,0.84),"ferro_escuro")
		_rebite(Vector3(lado*1.20,0.25,0.96))
	_caixa(Vector3(2.57,0.18,0.20),Vector3(0,1.83,0.95),"madeira")
	_caixa(Vector3(2.40,0.08,0.10),Vector3(0,1.51,0.28),"madeira_escura")
	for x in [-0.58,0.58]: _caixa(Vector3(0.06,0.23,0.07),Vector3(x,1.40,0.28),"madeira_escura")
	_viga(Vector3(0,1.88,0.96),Vector3(0,2.75,0.96),0.12,"madeira")
	# Terças longitudinais visíveis sob o teto, com encaixes nas tesouras.
	for x in [-0.97,0.0,0.97]:
		_viga(Vector3(x,2.0+(1-absf(x))*0.7,-0.94),Vector3(x,2.0+(1-absf(x))*0.7,0.97),0.10,"madeira_escura")
	var ponta := PackedVector2Array()
	for i in 10: ponta.append(Vector2(cos(TAU*i/10.0)*0.095,2.90+sin(TAU*i/10.0)*0.095))
	_extrudar_xy(ponta,1.11,0.07,"ouro")

func _cobertura_lateral(lado: float, alcance: float) -> void:
	var interno := 1.20
	var externo := interno+alcance
	var alto := 1.78
	var baixo := 1.15 if lado < 0 else 1.24
	var angulo := -lado*atan2(alto-baixo,alcance)
	var comprimento := sqrt(alcance*alcance+(alto-baixo)*(alto-baixo))
	var base := Basis(Vector3.BACK,angulo)
	for i in 11:
		var z := -0.82+i*0.18
		var variacao := float((i*7)%4)*0.025
		var centro := Vector3(lado*(interno+alcance*0.5),(alto+baixo)*0.5+float(i%2)*0.012,z)
		_caixa(Vector3(comprimento+0.12+variacao,0.075,0.19),centro,"madeira",Color.WHITE.darkened(float(i%4)*0.022),base)
		# Acúmulo estreito de neve sobre as pontas expostas das tábuas.
		var fracao := 0.24+float(i%3)*0.025
		var centro_neve := centro+Vector3(lado*alcance*(0.5-fracao*0.5),-(alto-baixo)*(0.5-fracao*0.5)+0.055,0)
		_caixa(Vector3(comprimento*fracao,0.022,0.19),centro_neve,"neve",Color.WHITE,base)
	for z in [-0.88,1.02]:
		_viga(Vector3(lado*interno,alto-0.08,z),Vector3(lado*externo,baixo-0.08,z),0.13,"madeira_escura")
		_caixa(Vector3(0.13,baixo-0.12,0.14),Vector3(lado*(externo-0.08),(baixo-0.12)*0.5+0.08,z),"madeira")
		_caixa(Vector3(0.21,0.14,0.22),Vector3(lado*(externo-0.08),0.10,z),"pedra_escura")
		_viga(Vector3(lado*(externo-0.08),baixo-0.43,z),Vector3(lado*(externo-0.39),baixo-0.05,z),0.09,"madeira")
	# Guarda lateral traseira; o acesso frontal ao estoque permanece aberto.
	for y in [0.25,0.66]: _caixa(Vector3(alcance,0.12,0.11),Vector3(lado*(interno+alcance*0.5),y,-0.80),"madeira_escura")

func _chamine_fina() -> void:
	var p := Vector3(1.29,1.44,-0.47)
	_caixa(Vector3(0.21,1.08,0.23),p+Vector3.UP*0.54,"pedra")
	for y in [0.22,0.44,0.66,0.88]:
		_caixa(Vector3(0.22,0.015,0.24),p+Vector3.UP*y,"junta")
	_cilindro(p+Vector3.UP*1.04,0.064,0.67,"metal",Color("ddcbb0"),8)
	for y in [1.16,1.56]: _anel(p+Vector3.UP*y,0.086,0.062,0.075,"metal",8)
	_anel(p+Vector3.UP*1.70,0.081,0.045,0.055,"metal",8)
	_cilindro(p+Vector3.UP*1.69,0.044,0.008,"fundo",Color.WHITE,8)
	_caixa(Vector3(0.21,0.025,0.23),p+Vector3.UP*1.09,"neve")
