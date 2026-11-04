@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
## Ornamentos e materiais da enfermaria, compartilhados pelo edifício e pelo jardim.
static var _materiais_clinica: Dictionary = {}
static var _pintura_reboco: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["reboco_clinica","verde_cruz","verde_borda","flor_clara","miolo"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_clinica.has(chave):
			var mat := _material("cantaria" if tipo == "reboco_clinica" else "ouro",estacao).duplicate() as StandardMaterial3D
			var cores := {"reboco_clinica":"f5e5c8","verde_cruz":"477f39","verde_borda":"2d5932","flor_clara":"fff3dc","miolo":"d9aa43"}
			mat.albedo_color = Color(cores[tipo])
			if tipo == "reboco_clinica":
				if not _pintura_reboco:
					var imagem := _pintura("cantaria").get_image()
					for y in imagem.get_height():
						for x in imagem.get_width():
							var v := 0.74+imagem.get_pixel(x,y).get_luminance()*0.23
							imagem.set_pixel(x,y,Color(v,v,v))
					_pintura_reboco = ImageTexture.create_from_image(imagem)
				mat.albedo_texture = _pintura_reboco
				mat.albedo_color *= [Color.WHITE,Color("fff6e6"),Color("f2dec0"),Color("dce2e5")][estacao]
			if tipo == "flor_clara" and estacao == 2: mat.albedo_color = Color("e7bd71")
			_materiais_clinica[chave] = mat
		_instancias[tipo].material_override = _materiais_clinica[chave]

func _cruz(p: Vector3, tamanho: float) -> void:
	var a := tamanho*0.5
	var b := tamanho*0.17
	var contorno := PackedVector2Array([Vector2(-b,-a),Vector2(b,-a),Vector2(b,-b),Vector2(a,-b),Vector2(a,b),Vector2(b,b),Vector2(b,a),Vector2(-b,a),Vector2(-b,b),Vector2(-a,b),Vector2(-a,-b),Vector2(-b,-b)])
	for i in contorno.size(): contorno[i] += Vector2(p.x,p.y)
	_extrudar_xy(contorno,p.z-0.022,0.075,"verde_borda")
	for i in contorno.size(): contorno[i] = Vector2(p.x,p.y)+(contorno[i]-Vector2(p.x,p.y))*0.89
	_extrudar_biselado_xy(contorno,p.z+0.018,0.055,"verde_cruz",Color.WHITE,0.012)

func _folha_erva(p: Vector3, tamanho: Vector3, tipo := "folha", cor := Color.WHITE) -> void:
	var pontos := [p+Vector3(tamanho.x*0.5,0,0),p+Vector3(0,0,tamanho.z*0.5),p-Vector3(tamanho.x*0.5,0,0),p-Vector3(0,0,tamanho.z*0.5)]
	for i in 4:
		_triangulo(p+Vector3.UP*tamanho.y*0.5,pontos[i],pontos[(i+1)%4],tipo,cor)
		_triangulo(p-Vector3.UP*tamanho.y*0.5,pontos[(i+1)%4],pontos[i],tipo,cor.darkened(0.10))

func _flor_jardim(p: Vector3, rosa := false, raio := 0.13) -> void:
	# Pétalas largas em geometria, com o miolo à frente e acima das folhas.
	for i in 6:
		var a := TAU*i/6.0
		_folha_erva(p+Vector3(cos(a)*raio*0.53,sin(a)*raio*0.42,0),Vector3(raio*0.77,raio*0.72,0.045),"flor" if rosa else "flor_clara")
	_folha_erva(p+Vector3(0,0,0.035),Vector3(raio*0.49,raio*0.49,0.055),"miolo")

func _moita(p: Vector3, largura: float, rosa := false) -> void:
	for i in 7:
		var a := TAU*i/7.0
		var ponto := p+Vector3(cos(a)*largura*0.29,0.12+float(i%3)*0.055,sin(a)*largura*0.20)
		_folha_erva(ponto,Vector3(largura*0.46,0.12,largura*0.30),"folha",Color.WHITE.lightened(float(i%3)*0.035))
		if i%2 == 0: _flor_jardim(ponto+Vector3(0,0.12,0.055),rosa,0.10)

func _arco_clinica(x: float, y: float, raio: float, borda: float, z: float) -> void:
	for i in 9:
		var a := PI*i/9.0+0.019
		var b := PI*(i+1)/9.0-0.019
		var contorno := PackedVector2Array([Vector2(x+cos(a)*(raio+borda),y+sin(a)*(raio+borda)),Vector2(x+cos(b)*(raio+borda),y+sin(b)*(raio+borda)),Vector2(x+cos(b)*raio,y+sin(b)*raio),Vector2(x+cos(a)*raio,y+sin(a)*raio)])
		_extrudar_biselado_xy(contorno,z,0.17,"cantaria",Color("d5c2a0").lightened(float(i%3)*0.025),0.015)

func _janela_clinica(p: Vector3, raio: float) -> void:
	var forma := PackedVector2Array([Vector2(p.x-raio,p.y-0.35),Vector2(p.x+raio,p.y-0.35),Vector2(p.x+raio,p.y)])
	for i in range(1,9): forma.append(Vector2(p.x+cos(PI*i/8.0)*raio,p.y+sin(PI*i/8.0)*raio))
	_extrudar_xy(forma,p.z,0.07,"vidro")
	_arco_clinica(p.x,p.y,raio,0.095,p.z+0.12)
	for lado in [-1.0,1.0]: _caixa(Vector3(0.095,0.36,0.15),p+Vector3(lado*(raio+0.05),-0.18,0.045),"cantaria")
	_caixa(Vector3(raio*2+0.30,0.10,0.27),p+Vector3(0,-0.40,0.08),"cantaria")
	_caixa(Vector3(0.035,0.35+raio,0.04),p+Vector3(0,(raio-0.35)*0.5,0.07),"madeira_escura")
	_caixa(Vector3(raio*2,0.036,0.04),p+Vector3(0,-0.05,0.07),"madeira_escura")
	_caixa(Vector3(raio*2+0.24,0.023,0.12),p+Vector3(0,-0.337,0.14),"neve")
