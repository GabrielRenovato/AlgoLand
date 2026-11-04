@tool
extends "res://codigo/campanha/enfermaria_malha_3d.gd"
## Reutiliza cantaria, janelas e flores; a pousada tem ardósia e venezianas próprias.
static var _materiais_pousada: Dictionary = {}
static var _ardosia: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["telha","telha_borda","veneziana"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_pousada.has(chave):
			var mat := _material("ouro",estacao).duplicate() as StandardMaterial3D
			mat.albedo_color = Color("7395bb") if tipo == "telha" else (Color("3c587b") if tipo == "telha_borda" else Color("4a8988"))
			if tipo == "telha":
				if not _ardosia:
					var imagem := _pintura("telha").get_image()
					for y in imagem.get_height():
						for x in imagem.get_width():
							var v := 0.62+imagem.get_pixel(x,y).get_luminance()*0.48
							imagem.set_pixel(x,y,Color(v,v,v))
					_ardosia = ImageTexture.create_from_image(imagem)
				mat.albedo_texture = _ardosia
			if estacao == 3: mat.albedo_color = mat.albedo_color.lerp(Color("cad5de"),0.10)
			_materiais_pousada[chave] = mat
		_instancias[tipo].material_override = _materiais_pousada[chave]

func _jardineira(p: Vector3, largura := 0.68) -> void:
	_caixa(Vector3(largura,0.14,0.27),p,"madeira_escura")
	_caixa(Vector3(largura+0.04,0.045,0.29),p+Vector3.UP*0.07,"madeira")
	for i in 5:
		var x := -largura*0.39+i*largura*0.195
		_folha_erva(p+Vector3(x,0.13,0.04),Vector3(0.23,0.12,0.21))
		_flor_jardim(p+Vector3(x,0.21+float(i%2)*0.035,0.12),true,0.075)
	_caixa(Vector3(largura,0.025,0.11),p+Vector3(0,0.11,0.12),"neve")

func _janela_pousada(p: Vector3, raio: float, venezianas := false) -> void:
	_janela_clinica(p,raio)
	if venezianas:
		for lado in [-1.0,1.0]:
			var x: float = p.x+lado*(raio+0.23)
			for i in 3: _caixa(Vector3(0.07,0.57,0.065),Vector3(x-0.075+i*0.075,p.y-0.075,p.z+0.015),"veneziana",Color.WHITE.lightened(float(i%2)*0.035))
			for y in [-0.27,0.12]: _caixa(Vector3(0.25,0.035,0.035),Vector3(x,p.y+y,p.z+0.065),"madeira_escura")
	_jardineira(p+Vector3(0,-0.44,0.18),raio*2+0.16)

func _lanterna_pousada(p: Vector3) -> void:
	_caixa(Vector3(0.13,0.23,0.12),p,"vidro")
	for x in [-0.08,0.08]:
		for z in [-0.07,0.07]: _caixa(Vector3(0.024,0.25,0.024),p+Vector3(x,0,z),"ferro_escuro")
	_caixa(Vector3(0.19,0.035,0.18),p-Vector3.UP*0.14,"ferro_escuro")
	_cilindro(p+Vector3.UP*0.13,0.14,0.11,"ferro_escuro",Color.WHITE,4,0.035)
	_viga(p+Vector3.UP*0.24,p+Vector3(0,0.32,-0.12),0.025,"ferro_escuro")
