@tool
extends "res://codigo/campanha/enfermaria_malha_3d.gd"
## Cantaria e jardins reutilizados; tecido e emblemas próprios da sede.
static var _materiais_sede: Dictionary = {}
static var _pintura_estandarte: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["estandarte","emblema_branco","pedra_sede","vidro_sede"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_sede.has(chave):
			var mat := _material("cantaria" if tipo == "pedra_sede" else "ouro",estacao).duplicate() as StandardMaterial3D
			mat.albedo_color = {"estandarte":Color("3d67b4"),"emblema_branco":Color("f7f4e9"),"pedra_sede":Color("d5d3c9"),"vidro_sede":Color("526265")}[tipo]
			if tipo == "estandarte":
				if not _pintura_estandarte:
					var imagem := _pintura("madeira").get_image()
					for y in imagem.get_height():
						for x in imagem.get_width():
							var v := 0.85+imagem.get_pixel(x,y).get_luminance()*0.13
							imagem.set_pixel(x,y,Color(v,v,v))
					_pintura_estandarte = ImageTexture.create_from_image(imagem)
				mat.albedo_texture = _pintura_estandarte
			if estacao == 3: mat.albedo_color = mat.albedo_color.lerp(Color("d0d9df"),0.08)
			_materiais_sede[chave] = mat
		_instancias[tipo].material_override = _materiais_sede[chave]

func _emblema(p: Vector3) -> void:
	var folha := PackedVector2Array([Vector2(0,0.19),Vector2(0.052,0.095),Vector2(0.021,0.015),Vector2(-0.021,0.015),Vector2(-0.052,0.095)])
	for i in folha.size(): folha[i] += Vector2(p.x,p.y)
	_extrudar_xy(folha,p.z,0.025,"emblema_branco")
	for lado in [-1.0,1.0]:
		var lateral := PackedVector2Array([Vector2(0.022,0.005),Vector2(0.060,0.071),Vector2(0.115,0.082),Vector2(0.143,0.035),Vector2(0.118,-0.014),Vector2(0.080,-0.008),Vector2(0.098,0.023),Vector2(0.077,0.036),Vector2(0.044,-0.012),Vector2(0.038,-0.056),Vector2(0.079,-0.105),Vector2(0.031,-0.097),Vector2(0.012,-0.065)])
		for i in lateral.size(): lateral[i] = Vector2(p.x+lado*lateral[i].x,p.y+lateral[i].y)
		_extrudar_xy(lateral,p.z,0.025,"emblema_branco")
	_caixa(Vector3(0.032,0.14,0.025),p+Vector3(0,-0.045,-0.012),"emblema_branco")
	_caixa(Vector3(0.11,0.025,0.025),p+Vector3(0,-0.029,-0.008),"emblema_branco")

func _estandarte(p: Vector3) -> void:
	var pontos := PackedVector2Array([Vector2(-0.21,0),Vector2(0.21,0),Vector2(0.21,-1.30),Vector2(0.11,-1.25),Vector2(0,-1.36),Vector2(-0.11,-1.25),Vector2(-0.21,-1.30)])
	for i in pontos.size(): pontos[i] += Vector2(p.x,p.y)
	_extrudar_biselado_xy(pontos,p.z,0.045,"ouro",Color.WHITE,0.009)
	for i in pontos.size(): pontos[i] = Vector2(p.x,p.y-0.66)+(pontos[i]-Vector2(p.x,p.y-0.66))*Vector2(0.84,0.96)
	_extrudar_xy(pontos,p.z+0.025,0.035,"estandarte")
	_emblema(p+Vector3(0,-0.65,0.060))
	_caixa(Vector3(0.59,0.045,0.055),p+Vector3(0,0.055,0.02),"ouro")
	_viga(p+Vector3(0,0.07,-0.48),p+Vector3(0,0.07,-0.02),0.055,"ferro_escuro")
	for lado in [-1.0,1.0]: _cilindro(p+Vector3(lado*0.26,0.045,0.02),0.044,0.085,"ouro",Color.WHITE,8,0.014)
	_cilindro(p+Vector3(0,0.09,-0.025),0.065,0.12,"ouro",Color.WHITE,8,0.0)
	_caixa(Vector3(0.59,0.022,0.06),p+Vector3(0,0.092,0.02),"neve")

func _poste_sede() -> void:
	_caixa(Vector3(0.29,0.14,0.29),Vector3(0,0.075,0),"pedra_sede")
	_cilindro(Vector3(0,0.14,0),0.095,0.13,"ferro_escuro",Color.WHITE,8,0.055)
	_cilindro(Vector3(0,0.27,0),0.038,1.03,"ferro_escuro",Color.WHITE,8)
	for y in [0.33,1.21]: _anel(Vector3(0,y,0),0.063,0.035,0.035,"metal",8)
	var p := Vector3(0,1.45,0)
	_caixa(Vector3(0.19,0.25,0.18),p,"vidro")
	for lado in [-1.0,1.0]:
		for z in [-1.0,1.0]: _viga(p+Vector3(lado*0.09,-0.15,z*0.08),p+Vector3(lado*0.14,0.14,z*0.13),0.028,"ferro_escuro")
	_caixa(Vector3(0.25,0.045,0.23),p-Vector3.UP*0.16,"ferro_escuro")
	_cilindro(p+Vector3.UP*0.14,0.21,0.16,"ferro_escuro",Color.WHITE,4,0.04)
	_cilindro(p+Vector3.UP*0.30,0.035,0.10,"ferro_escuro",Color.WHITE,8,0.0)
