@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
## Materiais e ornamentos próprios da casa da feiticeira, compartilhados pelos acessórios.
static var _materiais_misticos: Dictionary = {}
static var _ceramica_roxa: Texture2D

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in _instancias:
		if tipo in ["telha","telha_borda","reboco","ametista","gema","lavanda","folha"]:
			_instancias[tipo].material_override = _material_mistico(tipo,estacao)

static func _material_mistico(tipo: String, estacao: int) -> StandardMaterial3D:
	var chave := "%s:%d" % [tipo,estacao]
	if _materiais_misticos.has(chave): return _materiais_misticos[chave]
	var mat := _material("cantaria" if tipo == "reboco" else ("folha" if tipo == "folha" else "ouro"),estacao).duplicate() as StandardMaterial3D
	var cores := {"telha":"c58ae6","telha_borda":"80539e","reboco":"f4d9a6","ametista":"7541a1","gema":"528eff","lavanda":"ba85de","folha":"648c3e"}
	mat.albedo_color = Color(cores[tipo])
	if tipo == "telha":
		if not _ceramica_roxa:
			var imagem := _pintura("telha").get_image()
			for y in imagem.get_height():
				for x in imagem.get_width():
					var v := clampf(0.48+imagem.get_pixel(x,y).get_luminance()*0.65,0.66,0.97)
					imagem.set_pixel(x,y,Color(v,v,v))
			_ceramica_roxa = ImageTexture.create_from_image(imagem)
		mat.albedo_texture = _ceramica_roxa
	if tipo == "gema":
		mat.emission_enabled = true
		mat.emission = Color("315dff")
		mat.emission_energy_multiplier = 0.7
	if tipo == "lavanda": mat.albedo_color = [Color("ba85de"),Color("aa76cb"),Color("cb8249"),Color("a7a4b0")][estacao]
	if tipo == "folha": mat.albedo_color = [Color("648c3e"),Color("577a34"),Color("a47938"),Color("796b55")][estacao]
	if estacao == 3 and tipo in ["telha","telha_borda","reboco"]: mat.albedo_color = mat.albedo_color.lerp(Color("cbd3df"),0.10)
	_materiais_misticos[chave] = mat
	return mat

func _disco_xy(p: Vector3, raio: float, tipo: String, profundidade := 0.055) -> void:
	var contorno := PackedVector2Array()
	for i in 24: contorno.append(Vector2(p.x+cos(TAU*i/24.0)*raio,p.y+sin(TAU*i/24.0)*raio))
	_extrudar_biselado_xy(contorno,p.z,profundidade,tipo,Color.WHITE,0.014)

func _lua(p: Vector3, raio: float) -> void:
	# Contorno côncavo extrudado: o recorte da lua permanece vazado em qualquer vista.
	var contorno := PackedVector2Array()
	for i in 25:
		var a := deg_to_rad(55.0+250.0*i/24.0)
		contorno.append(Vector2(p.x+cos(a)*raio,p.y+sin(a)*raio))
	var ponta := Vector2(cos(deg_to_rad(55.0)),sin(deg_to_rad(55.0)))
	var centro_interno := 0.45
	var raio_interno := Vector2(ponta.x-centro_interno,ponta.y).length()
	var angulo := atan2(ponta.y,ponta.x-centro_interno)
	for i in range(1,24):
		var a := lerpf(-angulo,-TAU+angulo,float(i)/24.0)
		contorno.append(Vector2(p.x+(centro_interno+cos(a)*raio_interno)*raio,p.y+sin(a)*raio_interno*raio))
	_extrudar_xy(contorno,p.z,0.055,"ouro")

func _folha_volume(p: Vector3, tamanho: Vector3, tipo := "folha", cor := Color.WHITE) -> void:
	var topo := p+Vector3.UP*tamanho.y*0.5
	var base := p-Vector3.UP*tamanho.y*0.5
	var meio := [p+Vector3(tamanho.x*0.5,0,0),p+Vector3(0,0,tamanho.z*0.5),p-Vector3(tamanho.x*0.5,0,0),p-Vector3(0,0,tamanho.z*0.5)]
	for i in 4:
		_triangulo(topo,meio[i],meio[(i+1)%4],tipo,cor)
		_triangulo(base,meio[(i+1)%4],meio[i],tipo,cor.darkened(0.10))

func _cacho(p: Vector3, comprimento := 0.34) -> void:
	_viga(p,p-Vector3.UP*comprimento,0.018,"madeira_escura")
	for i in 5:
		var t := float(i)/5.0
		for lado in [-1.0,1.0]:
			_folha_volume(p+Vector3(lado*(0.048-t*0.026),-t*comprimento,0.024),Vector3(0.115-t*0.058,0.105,0.085),"lavanda",Color.WHITE.lightened(float(i%2)*0.12))

func _ramo(p: Vector3, altura: float) -> void:
	_viga(p,p+Vector3(0.035,altura,0),0.016,"folha")
	for i in 4:
		var t := float(i+1)/5.0
		_folha_volume(p+Vector3(0.035*t,altura*t,0),Vector3(0.14*(1-t*0.45),0.14,0.12),"lavanda")
