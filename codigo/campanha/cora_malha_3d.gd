@tool
extends "res://codigo/campanha/bento_malha_3d.gd"
## Pinturas e peças da padaria: alvenaria, tecido e pães modelados.
static var _materiais_cora: Dictionary = {}
static var _pintura_cora: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["tijolo_cora","argamassa","toldo_vermelho","toldo_creme","pao","corte_pao"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_cora.has(chave):
			var mat := _material("cantaria" if tipo == "tijolo_cora" else "ouro",estacao).duplicate() as StandardMaterial3D
			mat.albedo_color = {"tijolo_cora":Color("b85d43"),"argamassa":Color("b39b7e"),"toldo_vermelho":Color("b94e3d"),"toldo_creme":Color("f1e1ba"),"pao":Color("dda04b"),"corte_pao":Color("f1cf84")}[tipo]
			if tipo in ["toldo_vermelho","toldo_creme","pao"]:
				if not _pintura_cora:
					var imagem := _pintura("madeira").get_image()
					for y in imagem.get_height():
						for x in imagem.get_width():
							var v := 0.85+imagem.get_pixel(x,y).get_luminance()*0.13
							imagem.set_pixel(x,y,Color(v,v,v))
					_pintura_cora = ImageTexture.create_from_image(imagem)
				mat.albedo_texture = _pintura_cora
			if estacao == 3 and tipo != "corte_pao": mat.albedo_color = mat.albedo_color.lerp(Color("d6dde1"),0.07)
			_materiais_cora[chave] = mat
		_instancias[tipo].material_override = _materiais_cora[chave]

func _alvenaria(p: Vector3, tamanho: Vector2, base := Basis.IDENTITY) -> void:
	_caixa(Vector3(tamanho.x,tamanho.y,0.14),p,"argamassa",Color.WHITE,base)
	var linhas := ceili(tamanho.y/0.16)
	var passo := tamanho.y/linhas
	for linha in linhas:
		var x := -tamanho.x*0.5-(0.14 if linha%2 else 0.0)
		while x<tamanho.x*0.5:
			var a := maxf(x,-tamanho.x*0.5)
			var b := minf(x+0.28,tamanho.x*0.5)
			if b-a>0.025:
				_caixa(Vector3(b-a-0.014,passo-0.014,0.045),p+base*Vector3((a+b)*0.5,-tamanho.y*0.5+(linha+0.5)*passo,0.087),"tijolo_cora",Color.WHITE.darkened(float((linha+roundi(x*11))%3)*0.025),base)
			x += 0.28

func _pao(p: Vector3, tamanho: Vector3) -> void:
	for linha in 4:
		var a := -PI*0.5+PI*linha/4.0
		var b := -PI*0.5+PI*(linha+1)/4.0
		for i in 10:
			var u := TAU*i/10.0
			var v := TAU*(i+1)/10.0
			_face(p+Vector3(cos(u)*cos(a),sin(a),sin(u)*cos(a))*tamanho*0.5,p+Vector3(cos(v)*cos(a),sin(a),sin(v)*cos(a))*tamanho*0.5,p+Vector3(cos(v)*cos(b),sin(b),sin(v)*cos(b))*tamanho*0.5,p+Vector3(cos(u)*cos(b),sin(b),sin(u)*cos(b))*tamanho*0.5,"pao",Color.WHITE.lightened(float((linha+i)%3)*0.025))
	for i in 3:
		var x := (i-1)*tamanho.x*0.22
		_viga(p+Vector3(x-0.035,tamanho.y*0.26,tamanho.z*0.36),p+Vector3(x+0.025,tamanho.y*0.44,tamanho.z*0.12),0.022,"corte_pao")

func _floreira_cora(p: Vector3, largura: float) -> void:
	_caixa(Vector3(largura,0.18,0.28),p,"madeira_escura")
	for i in 2: _caixa(Vector3(largura+0.04,0.065,0.035),p+Vector3(0,-0.035+i*0.085,0.15),"madeira")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.06,0.20,0.31),p+Vector3(lado*largura*0.45,0,0),"madeira")
		_viga(p+Vector3(lado*largura*0.30,-0.14,0.06),p+Vector3(lado*largura*0.30,-0.23,-0.17),0.07,"madeira_escura")
	var quantidade := ceili(largura/0.24)
	for i in quantidade: _moita(p+Vector3(-largura*0.40+i*largura*0.80/maxf(1,quantidade-1),0.11,0.035),0.34,i%2 == 0)
	_caixa(Vector3(largura+0.04,0.025,0.10),p+Vector3(0,0.14,0.13),"neve")
