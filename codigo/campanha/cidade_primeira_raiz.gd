extends "res://codigo/campanha/terreno_campanha.gd"

## Composição medida na referência1536×1024, com prédios e jardim em peças sazonais.
const ARTE := {
	"sede":["sede_pousada",0,320.0],"pousada":["sede_pousada",1,330.0],
	"forja":["oficinas",0,256.0],"carpintaria":["oficinas",1,280.0],
	"enfermaria":["enfermaria_mistica",0,240.0],"mistica":["enfermaria_mistica",1,240.0],
	"carvalho_praca":["arvore_portaria",0,320.0],"portaria":["arvore_portaria",1,112.0],
	"venda":["venda_casa",0,240.0],"casa_bento":["venda_casa",1,208.0],"casa_jogador":["venda_casa",1,192.0]}
## As construções ficavam grandes demais perto do jogador; a escala vale para fachada, colisão e base.
const ESCALA_CASAS := 0.8
var setores: Dictionary = {}
var _barracas: Array[Sprite2D] = []
var _pecas_referencia: Array[Dictionary] = []
var _fontes_arte: Dictionary = {}
var _fachadas_familias: Array[Node2D] = []
## Casas que ficam translúcidas quando um jogador passa por trás delas.
var _casas: Array[Node2D] = []
const ALFA_ATRAS := 0.45

func _process(delta: float) -> void:
	var jogadores := get_tree().get_nodes_in_group("jogadores")
	for casa in _casas:
		if not is_instance_valid(casa): continue
		var atras := false
		var area := _area_visivel(casa)
		for j in jogadores:
			var p: Vector2 = (j as Node2D).global_position
			if p.y < casa.global_position.y and area.has_point(p):
				atras = true
				break
		casa.modulate.a = move_toward(casa.modulate.a, ALFA_ATRAS if atras else 1.0, delta*4.0)

func _area_visivel(casa: Node2D) -> Rect2:
	for filho in casa.get_children():
		if filho is Sprite2D and filho.texture != null:
			return filho.get_global_transform() * filho.get_rect()
	return Rect2(casa.global_position, Vector2.ZERO)

## Chão no padrão modular da chegada e da estrada: tiles por cantos de 16 px e texturas contínuas por estação.
const RAIZ_MODULAR := "res://assets/cenario/campanha/clareiras_modulares/"
const GRAMA_MODULAR := 0
const PEDRA_MODULAR := 2
var _material_chao: ShaderMaterial
var _grama_3d: Node2D

func _ready() -> void:
	super._ready()
	var grama := preload("res://codigo/cenario/grama_3d_no_mapa.gd").new()
	grama.name = "Grama3D"
	grama.terreno = self
	grama.consultar_grama = func(p: Vector2) -> float:
		return grama.peso_modular(p,_tipo_modular)
	add_child(grama)
	_grama_3d = grama
	grama.definir_estacao(estacao_atual)
	for item in _sazonais:
		if item.get("peca","") in ["carvalho","pinheiro","jovem"]:
			grama._montar_frente_base({"tipo":"arbustos","ponto":item.sprite.position,"sprite":item.sprite})

var _tipos_modulares: Dictionary = {}

func _tipo_modular(canto: Vector2i) -> int:
	# A grama consulta os mesmos cantos centenas de milhares de vezes; o mapa da vila não muda.
	if not _tipos_modulares.has(canto):
		_tipos_modulares[canto] = PEDRA_MODULAR if _terreno(Vector2(canto*16))=="pedra" else GRAMA_MODULAR
	return _tipos_modulares[canto]

func _montar_chao() -> void:
	chao = TileMapLayer.new()
	chao.name = "Chao"
	chao.z_index = Profundidade.Z_CHAO
	chao.scale = Vector2.ONE/4
	chao.tile_set = load(RAIZ_MODULAR+"tileset.tres").duplicate(true)
	_material_chao = ShaderMaterial.new()
	_material_chao.shader = preload("res://codigo/campanha/terreno_modular.gdshader")
	_material_chao.set_shader_parameter("origem",limites.position)
	_material_chao.set_shader_parameter("tamanho",limites.size)
	_material_chao.set_shader_parameter("pedra_nitida",true)
	_material_chao.set_shader_parameter("mapa_raizes",ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_L8)))
	chao.material = _material_chao
	chao.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(chao)
	var inicio := Vector2i((limites.position/16).floor())
	var fim := Vector2i((limites.end/16).ceil())
	var tipos: Dictionary = {}
	for y in range(inicio.y,fim.y+1):
		for x in range(inicio.x,fim.x+1): tipos[Vector2i(x,y)] = _tipo_modular(Vector2i(x,y))
	for y in range(inicio.y,fim.y):
		for x in range(inicio.x,fim.x):
			var indice: int = tipos[Vector2i(x,y)]+(tipos[Vector2i(x+1,y)]<<2)+(tipos[Vector2i(x,y+1)]<<4)+(tipos[Vector2i(x+1,y+1)]<<6)
			chao.set_cell(Vector2i(x,y),0,Vector2i(indice%16,indice/16))

func _aplicar_chao_estacao() -> void:
	var nome: String = NOMES[estacao_atual]
	for tipo in ["grama","pedra","agua"]:
		_material_chao.set_shader_parameter(tipo,load(RAIZ_MODULAR+nome+"/"+tipo+".png"))
	_material_chao.set_shader_parameter("raizes",load(RAIZ_MODULAR+nome+"/terra_raizes.png"))
	_material_chao.set_shader_parameter("terra",load("res://assets/cenario/fazenda/natureza_detalhada/%s/terra.png" % nome))

func _paisagem() -> void:
	setores={"praca":Vector2(0,-32),"mercado":Vector2(-464,-120),"oficinas":Vector2(-368,200),"moradias":Vector2(512,-192),"enfermaria":Vector2(346,182),"entrada":Vector2(0,400)}
	_arte("carvalho_praca",Vector2(-7,-38))
	# O polígono acompanha a base da mureta; a colisão anterior cobria apenas o tronco.
	_colisao_poligono(PackedVector2Array([
		Vector2(-7,-94),Vector2(42,-90),Vector2(86,-82),Vector2(116,-70),
		Vector2(128,-58),Vector2(119,-49),Vector2(92,-42),Vector2(47,-38),
		Vector2(-7,-37),Vector2(-59,-39),Vector2(-101,-46),Vector2(-127,-56),
		Vector2(-131,-67),Vector2(-113,-77),Vector2(-82,-86),Vector2(-43,-92)
	]))
	_enfeite("construcoes/fonte_anim",Vector2(0,46),Vector2(64,30))
	_arte("portaria",Vector2(-134,373))
	_arte("portaria",Vector2(146,373)).flip_h=true
	for x in [-134,146]:_colisao(Rect2(x-36,337,72,38))
	for p in [Vector2(-208,-72),Vector2(208,-72),Vector2(-176,24),Vector2(176,24),Vector2(-160,80),Vector2(160,80),Vector2(-72,144),Vector2(72,144),Vector2(-80,288),Vector2(80,288),Vector2(-88,376),Vector2(88,376),Vector2(-640,-16),Vector2(640,-16),Vector2(-48,-456),Vector2(48,-456)]:
		_enfeite("mobiliario/poste_luz",p,Vector2(8,6))
	for i in 3:_barraca(Vector2(-560+i*104,-112),i)
	for p in [Vector2(-512,-272),Vector2(-560,-272),Vector2(584,-208),Vector2(584,-144),Vector2(-600,176),Vector2(-600,224),Vector2(624,192)]:
		_enfeite("mobiliario/horta",p,Vector2(48,10))
	# O estoque das oficinas agora está nas cenas independentes de toras e tábuas da carpintaria.
	for p in [Vector2(256,-192),Vector2(280,-144)]:
		_enfeite("mobiliario/mesa_piquenique",p,Vector2(40,12))
	_enfeite("mobiliario/mural",Vector2(-104,112),Vector2(34,8))
	_jardins()
	for trecho in [[-672,-200,-432],[176,640,-432],[-640,-192,368],[192,672,368],[400,656,-104],[400,656,-256]]:
		_cerca_horizontal(trecho[0],trecho[1],trecho[2])
	for trecho in [[400,-256,-192],[656,-256,-104],[-640,128,304],[656,112,336]]:
		_cerca_vertical(trecho[0],trecho[1],trecho[2])
	_floresta()

func _casa(id: String,p: Vector2) -> void:
	# Cora compartilha o id de moradia, mas conserva fachada e modelo próprios.
	var modelo_id := "cora" if id=="casa_jogador" and p.x<0 else id
	# Conversão individual: cada edifício só troca a arte quando recebe modelo próprio.
	if modelo_id in ["forja","carpintaria","mistica","enfermaria","venda","pousada","sede","casa_bento","cora","casa_jogador"]:
		var fachada := preload("res://codigo/campanha/casa_vila_3d.gd").new()
		fachada.id=modelo_id
		fachada.largura=float(ARTE[id][2])*ESCALA_CASAS
		# O pivô original inclui a peça mais à frente: bigorna, cavalete ou degrau.
		var medidas: Vector3 = fachada.MEDIDAS[modelo_id]
		var profundidade_frente: float = {"forja":1.54,"carpintaria":1.55,"mistica":1.64,"enfermaria":1.79,"venda":1.94,"pousada":1.90,"sede":2.29,"casa_bento":1.91,"cora":1.80,"casa_jogador":1.91}[modelo_id]
		var frente := fachada.largura/medidas.x*profundidade_frente*sin(atan2(7.0,10.0))
		var eixo_porta := 0.62 if modelo_id=="cora" else 0.0
		fachada.position=p-Vector2(eixo_porta*fachada.largura/medidas.x,frente)
		fachada.z_index=Profundidade.z_de(fachada.position.y)
		add_child(fachada)
		_casas.append(fachada)
		if fachada.contorno_chao.size() >= 3:
			var base_casa := PackedVector2Array()
			for ponto in fachada.contorno_chao: base_casa.append(fachada.position+ponto)
			_colisao_poligono(base_casa)
			return
	else:
		var familia := "mara" if id=="pousada" else ("rosa" if id=="enfermaria" else ("cora" if id=="casa_jogador" and p.x<0 else ""))
		if familia.is_empty():
			_arte(id,p)
		else:
			var fachada=preload("res://codigo/cidade/familias/exterior_familia.gd").new()
			fachada.id=familia
			fachada.largura=float(ARTE[id][2])*ESCALA_CASAS
			fachada.position=p
			fachada.name=id.to_pascal_case()
			fachada.z_index=Profundidade.z_de(p.y)
			add_child(fachada)
			_fachadas_familias.append(fachada)
			_casas.append(fachada)
	var base:float=float(ARTE[id][2])*ESCALA_CASAS*0.65
	_colisao(Rect2(p-Vector2(base/2,38),Vector2(base,40)))

func _arte(id: String,p: Vector2) -> Sprite2D:
	var dados: Array=ARTE[id]
	var chave: String=dados[0]
	var quadros: Array[Texture2D]=[]
	var recorte:=Rect2i()
	if not _fontes_arte.has(chave):
		var textura:Texture2D=load("res://assets/cenario/campanha/cidade_fiel/%s.png" % chave)
		var imagem:=textura.get_image()
		if not imagem.has_mipmaps():imagem.generate_mipmaps()
		_fontes_arte[chave]=ImageTexture.create_from_image(imagem)
	var atlas:Texture2D=_fontes_arte[chave]
	var inicio_x:=0 if int(dados[1])==0 else (534 if chave=="arvore_portaria" else atlas.get_width()/2)
	var largura_celula:=534 if chave=="arvore_portaria" and int(dados[1])==0 else atlas.get_width()-inicio_x
	if chave!="arvore_portaria":largura_celula=atlas.get_width()/2
	var celula:=Vector2i(largura_celula,atlas.get_height()/4)
	for estacao in 4:
		var origem:=Vector2i(inicio_x,roundi(estacao*atlas.get_height()/4.0))
		var trecho:=Rect2i(origem,celula)
		var usado:=_limites_peca(atlas.get_image().get_region(trecho))
		recorte=usado if estacao==0 else recorte.merge(usado)
		var quadro:=AtlasTexture.new()
		quadro.atlas=atlas
		quadro.region=Rect2(Vector2(origem+usado.position),Vector2(usado.size))
		quadro.filter_clip=true
		quadros.append(quadro)
	var sprite:=Sprite2D.new()
	sprite.name=id.to_pascal_case()
	sprite.centered=false
	sprite.offset=Vector2(-recorte.size.x/2.0,-recorte.size.y)
	sprite.scale=Vector2.ONE*float(dados[2])/recorte.size.x
	if id=="carvalho_praca":sprite.scale.y*=0.85
	if id=="pousada":sprite.scale.y*=0.82
	sprite.position=p
	sprite.z_index=Profundidade.z_de(p.y)
	# As fachadas são pinturas de alta resolução reduzidas no mapa; filtragem linear evita serrilhado.
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_pecas_referencia.append({"sprite":sprite,"quadros":quadros})
	return sprite

func _limites_peca(imagem: Image) -> Rect2i:
	# O atlas gerado não tem gutters: descarta fragmentos isolados do quadro vizinho.
	var mascara:=BitMap.new()
	mascara.create_from_image_alpha(imagem,0.2)
	var contornos:=mascara.opaque_to_polygons(Rect2i(Vector2i.ZERO,imagem.get_size()),1.0)
	var maior:=0.0
	var limites_peca:=imagem.get_used_rect()
	for poligono in contornos:
		var area:=0.0
		var ret:=Rect2(poligono[0],Vector2.ZERO)
		for i in poligono.size():
			area+=poligono[i].cross(poligono[(i+1)%poligono.size()])
			ret=ret.expand(poligono[i])
		if absf(area)>maior:
			maior=absf(area)
			limites_peca=Rect2i(ret.grow(1)).intersection(Rect2i(Vector2i.ZERO,imagem.get_size()))
	return limites_peca

func _jardins() -> void:
	# Flores baixas acompanham o arco da praça sem bloquear os quatro acessos.
	for i in 60:
		var a:=TAU*i/60
		var p:=Vector2(cos(a)*230,-42+sin(a)*174)
		if absf(p.y+48)<48 or (p.y>64 and absf(p.x)<68):continue
		_miudo("vegetacao/flores",p,44)
	# Jardins de cada bairro: intervalos e bases medidos na referência.
	for bloco in [[Vector2(-580,-280),6],[Vector2(512,-256),5],[Vector2(-608,144),5],[Vector2(384,248),4],[Vector2(488,336),5]]:
		for i in int(bloco[1]):
			_miudo("vegetacao/flores",bloco[0]+Vector2(i*26,0),40)
	for p in [Vector2(-620,-320),Vector2(-620,-256),Vector2(-280,-200),Vector2(320,-192),Vector2(344,-144),Vector2(-608,256),Vector2(-360,304),Vector2(224,288),Vector2(192,336),Vector2(656,272),Vector2(592,336),Vector2(-128,256)]:
		_miudo("vegetacao/arbusto",p,44)
	var rng:=RandomNumberGenerator.new()
	rng.seed=6490
	for centro in [Vector2(-576,-320),Vector2(-352,-352),Vector2(400,-304),Vector2(560,-208),Vector2(176,224),Vector2(368,48),Vector2(-576,240),Vector2(-352,312),Vector2(592,160)]:
		for i in 14:
			var p:Vector2=centro+Vector2(rng.randf_range(-48,48),rng.randf_range(-30,30))
			if _terreno(p)!="grama":continue
			# A vegetação solta do bairro não cobre a porta e os degraus da moradia leste.
			if Rect2(480,-226,68,94).has_point(p):continue
			_miudo("vegetacao/arbusto" if i%3==0 else "vegetacao/flores",p,36)
	for p in [Vector2(-128,112),Vector2(128,112)]:
		_enfeite("mobiliario/banco_piquenique_esquerdo",p,Vector2(10,8))

func _miudo(id: String,p: Vector2,largura: float) -> void:
	var detalhes:=preload("res://codigo/cidade/enfeites_detalhados.gd").dados(id)
	var sprite:=Sprite2D.new()
	var tamanho:=Vector2(detalhes.canvas_logico[0],detalhes.canvas_logico[1])
	sprite.position=p
	sprite.centered=false
	sprite.offset=Vector2(-tamanho.x/2,-tamanho.y)*4
	sprite.scale=Vector2.ONE*largura/(tamanho.x*4)
	sprite.z_index=Profundidade.z_de(p.y)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_sazonais.append({"sprite":sprite,"texturas":detalhes.texturas})

func _floresta() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=44081
	var plantadas: Array[Vector2]=[]
	for i in 900:
		var p:=Vector2(rng.randf_range(-752,752),rng.randf_range(-488,504))
		if absf(p.x)<664 and absf(p.y)<408:continue
		if _terreno(p)!="grama" or _perto_de_casa(p):continue
		var ocupada:=false
		for outra in plantadas:
			if p.distance_to(outra)<40:ocupada=true;break
		if ocupada:continue
		plantadas.append(p)
		_natureza("pinheiro" if rng.randf()<0.2 else "carvalho",p)
		var sprite:Sprite2D=_sazonais[-1].sprite
		sprite.scale*=rng.randf_range(0.85,1.1)
	for p in [Vector2(-608,-352),Vector2(-304,-336),Vector2(352,-320),Vector2(672,-320),Vector2(656,32),Vector2(-672,64),Vector2(-608,64),Vector2(-352,352),Vector2(-192,352),Vector2(240,272),Vector2(256,336),Vector2(672,336)]:
		_natureza("carvalho",p)

func _perto_de_casa(p: Vector2) -> bool:
	for casa in dados.casas:
		var base:=_ponto(casa[1])
		if Rect2(base-Vector2(144,224),Vector2(288,248)).has_point(p):return true
	return false

func _enfeite(id: String,p: Vector2,base: Vector2) -> void:
	var detalhes:=preload("res://codigo/cidade/enfeites_detalhados.gd").dados(id)
	var sprite:=Sprite2D.new()
	sprite.name=id.get_file().to_pascal_case()
	sprite.position=p
	sprite.centered=false
	var tamanho:=Vector2(detalhes.canvas_logico[0],detalhes.canvas_logico[1])
	sprite.offset=Vector2(-tamanho.x/2,-tamanho.y)*4
	sprite.scale=Vector2.ONE/4
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index=Profundidade.z_de(p.y)
	add_child(sprite)
	_sazonais.append({"sprite":sprite,"texturas":detalhes.texturas})
	_colisao(Rect2(p-Vector2(base.x/2,base.y),base))

func _barraca(p: Vector2,indice: int) -> void:
	var sprite:=Sprite2D.new()
	sprite.name="BarracaMercado"
	sprite.texture=preload("res://assets/cenario/cidade/objetos/barraca.png")
	sprite.centered=false
	sprite.position=p
	sprite.scale=Vector2.ONE*(96.0/1536)
	sprite.offset=Vector2(-768,-1024)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index=Profundidade.z_de(p.y)
	add_child(sprite)
	_barracas.append(sprite)
	if indice>0:
		var material:=ShaderMaterial.new()
		material.shader=preload("res://codigo/campanha/toldo_mercado.gdshader")
		material.set_shader_parameter("cor_listras",Color("3f885a") if indice==1 else Color("dec69a"))
		sprite.material=material
	sprite.set_meta("indice",indice)
	_colisao(Rect2(p-Vector2(38,12),Vector2(76,12)))

func _cerca_horizontal(inicio: int,fim: int,y: int) -> void:
	for x in range(inicio,fim,16):_cerca(Vector2(x,y),"horizontal")
	_colisao(Rect2(inicio-8,y-4,fim-inicio,4))

func _cerca_vertical(x: int,inicio: int,fim: int) -> void:
	for y in range(inicio,fim,32):_cerca(Vector2(x,y),"vertical")
	_colisao(Rect2(x-4,inicio,4,fim-inicio))

func _cerca(p: Vector2,tipo: String) -> void:
	var sprite:=Sprite2D.new()
	sprite.position=p
	sprite.centered=false
	sprite.offset=Vector2(-32,-92) if tipo=="horizontal" else Vector2(-16,-188)
	sprite.scale=Vector2.ONE/4
	sprite.z_index=Profundidade.z_de(p.y)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	var texturas:=[]
	for estacao in NOMES:texturas.append("res://assets/cenario/cidade/complementos/cercas/%s/%s.png" % [estacao,tipo])
	_sazonais.append({"sprite":sprite,"texturas":texturas})

func definir_estacao(indice: int) -> void:
	super.definir_estacao(indice)
	for fachada in _fachadas_familias:
		fachada.definir_estacao(estacao_atual)
	for peca in _pecas_referencia:
		peca.sprite.texture=peca.quadros[estacao_atual]
		var tamanho:Vector2=peca.sprite.texture.get_size()
		peca.sprite.offset=Vector2(-tamanho.x/2,-tamanho.y)
	for barraca in _barracas:
		barraca.modulate=[Color.WHITE,Color(1,0.98,0.92),Color(1,0.93,0.84),Color(0.86,0.93,1)][estacao_atual]
