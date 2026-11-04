@tool
extends "res://codigo/campanha/enfermaria_malha_3d.gd"
## A casa pequena reutiliza pinturas do moinho e flores; a porta tem madeira verde própria.
static var _materiais_bento: Dictionary = {}
static var _pintura_verde: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["madeira_verde","verde_rebaixo","pedra_bento","vidro_bento"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_bento.has(chave):
			var mat := _material("cantaria" if tipo == "pedra_bento" else "ouro",estacao).duplicate() as StandardMaterial3D
			mat.albedo_color = {"madeira_verde":Color("397849"),"verde_rebaixo":Color("284f34"),"pedra_bento":Color("b8b7ab"),"vidro_bento":Color("52676b")}[tipo]
			if tipo in ["madeira_verde","verde_rebaixo"]:
				if not _pintura_verde:
					var imagem := _pintura("madeira").get_image()
					for y in imagem.get_height():
						for x in imagem.get_width():
							var v := 0.69+imagem.get_pixel(x,y).get_luminance()*0.30
							imagem.set_pixel(x,y,Color(v,v,v))
					_pintura_verde = ImageTexture.create_from_image(imagem)
				mat.albedo_texture = _pintura_verde
			if estacao == 3: mat.albedo_color = mat.albedo_color.lerp(Color("ced6d8"),0.06)
			_materiais_bento[chave] = mat
		_instancias[tipo].material_override = _materiais_bento[chave]

func _arco_bento(p: Vector3, raio: float, borda: float, tipo: String) -> void:
	for i in 9:
		var a := PI*i/9.0+0.015
		var b := PI*(i+1)/9.0-0.015
		var forma := PackedVector2Array([Vector2(p.x+cos(a)*(raio+borda),p.y+sin(a)*(raio+borda)),Vector2(p.x+cos(b)*(raio+borda),p.y+sin(b)*(raio+borda)),Vector2(p.x+cos(b)*raio,p.y+sin(b)*raio),Vector2(p.x+cos(a)*raio,p.y+sin(a)*raio)])
		_extrudar_biselado_xy(forma,p.z,0.14,tipo,Color.WHITE.lightened(float(i%3)*0.025),0.012)

func _flores_bento(p: Vector3, largura: float) -> void:
	# Folhagem e flores facetadas; cada agrupamento conserva leitura na grade final.
	for i in 5:
		var a := TAU*i/5.0
		_moita(p+Vector3(cos(a)*largura*0.23,0.04+float(i%2)*0.07,sin(a)*largura*0.14),largura*0.52,i%2 == 0)

func _lanterna_parede(p: Vector3) -> void:
	_caixa(Vector3(0.09,0.29,0.04),p+Vector3(0,0.16,-0.20),"ferro_escuro")
	_viga(p+Vector3(0,0.28,-0.19),p+Vector3(0,0.28,0.015),0.035,"ferro_escuro")
	_caixa(Vector3(0.18,0.24,0.16),p,"vidro")
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]: _viga(p+Vector3(x*0.08,-0.13,z*0.07),p+Vector3(x*0.11,0.13,z*0.10),0.023,"ferro_escuro")
	_caixa(Vector3(0.23,0.035,0.22),p-Vector3.UP*0.14,"ferro_escuro")
	_cilindro(p+Vector3.UP*0.13,0.18,0.12,"ferro_escuro",Color.WHITE,4,0.035)
	_cilindro(p+Vector3.UP*0.25,0.03,0.055,"ouro",Color.WHITE,8,0.01)
	_cilindro(p-Vector3.UP*0.21,0.025,0.055,"ferro_escuro",Color.WHITE,8,0.055)
