@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
## Pinturas, tecido e mercadorias compartilhados pela venda e seus objetos.
static var _materiais_venda: Dictionary = {}
static var _pintura_tecido: Texture2D
static var _pintura_reboco: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo not in ["reboco_venda","tecido_azul","tecido_claro","maca","legume","citrico","vidro_azul","saco","placa_verde"]: continue
		var chave := "%s:%d" % [tipo,estacao]
		if not _materiais_venda.has(chave):
			var mat := _material("ouro",estacao).duplicate() as StandardMaterial3D
			var cores := {"reboco_venda":"eed9b6","tecido_azul":"477fa5","tecido_claro":"e8dec5","maca":"c35637","legume":"78a84a","citrico":"edb84e","vidro_azul":"6b9597","saco":"b6a281","placa_verde":"48613a"}
			mat.albedo_color = Color(cores[tipo])
			if tipo.begins_with("tecido"):
				if not _pintura_tecido: _pintura_tecido = _pintura_suave("madeira",0.84,0.15)
				mat.albedo_texture = _pintura_tecido
				if estacao == 3: mat.albedo_color = mat.albedo_color.lerp(Color("ced8df"),0.08)
			if tipo == "reboco_venda":
				if not _pintura_reboco: _pintura_reboco = _pintura_suave("cantaria",0.74,0.23)
				mat.albedo_texture = _pintura_reboco
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3.ONE*0.7
				mat.albedo_color *= [Color.WHITE,Color("fff4df"),Color("eed6b9"),Color("d9e0e3")][estacao]
			_materiais_venda[chave] = mat
		_instancias[tipo].material_override = _materiais_venda[chave]

static func _pintura_suave(origem: String, base: float, contraste: float) -> Texture2D:
	var imagem := _pintura(origem).get_image()
	for y in imagem.get_height():
		for x in imagem.get_width():
			var v := base+imagem.get_pixel(x,y).get_luminance()*contraste
			imagem.set_pixel(x,y,Color(v,v,v))
	return ImageTexture.create_from_image(imagem)

func _volume_mercadoria(p: Vector3, tamanho: Vector3, tipo: String) -> void:
	# Frutos facetados com topo e fundo fechados; tamanho é o diâmetro de cada eixo.
	for linha in 4:
		var a := -PI*0.5+PI*linha/4.0
		var b := -PI*0.5+PI*(linha+1)/4.0
		for i in 8:
			var u := TAU*i/8.0
			var v := TAU*(i+1)/8.0
			var p0 := p+Vector3(cos(u)*cos(a),sin(a),sin(u)*cos(a))*tamanho*0.5
			var p1 := p+Vector3(cos(v)*cos(a),sin(a),sin(v)*cos(a))*tamanho*0.5
			var p2 := p+Vector3(cos(v)*cos(b),sin(b),sin(v)*cos(b))*tamanho*0.5
			var p3 := p+Vector3(cos(u)*cos(b),sin(b),sin(u)*cos(b))*tamanho*0.5
			_face(p0,p1,p2,p3,tipo,Color.WHITE.lightened(float((i+linha)%3)*0.025))

func _folha_produto(p: Vector3, tamanho := Vector3(0.12,0.06,0.075), tipo := "folha") -> void:
	var lados := [p+Vector3(tamanho.x*0.5,0,0),p+Vector3(0,0,tamanho.z*0.5),p-Vector3(tamanho.x*0.5,0,0),p-Vector3(0,0,tamanho.z*0.5)]
	for i in 4:
		_triangulo(p+Vector3.UP*tamanho.y*0.5,lados[i],lados[(i+1)%4],tipo)
		_triangulo(p-Vector3.UP*tamanho.y*0.5,lados[(i+1)%4],lados[i],tipo,Color.WHITE.darkened(0.08))

func _pote(p: Vector3, tipo := "vidro_azul") -> void:
	_cilindro(p,0.085,0.15,tipo,Color.WHITE,8,0.095)
	_cilindro(p+Vector3.UP*0.15,0.095,0.06,tipo,Color.WHITE,8,0.055)
	_cilindro(p+Vector3.UP*0.21,0.065,0.035,"madeira",Color.WHITE,8)

func _espiga(p: Vector3, altura: float) -> void:
	_viga(p,p+Vector3(0.025,altura,0),0.018,"ouro")
	for i in 4:
		var y := altura*(0.38+i*0.14)
		for lado in [-1.0,1.0]:
			_folha_produto(p+Vector3(lado*0.044,y,0.016),Vector3(0.09,0.075,0.04),"ouro")
