extends Node2D

## Mapa montado em células lógicas de 16px, com peças nativas de 64px (4×).
## Não usa a ilustração como piso: cada camada contém TileMapLayer e TileSet reais.
signal pronto
const LAYOUT := preload("res://codigo/campanha/layout_mapa_tiles.json")
const ESTACOES := ["primavera","verao","outono","inverno"]
const INGLES := ["spring","summer","autumn","winter"]
const GRADE := Vector2i(96,64)
const TAMANHO := Vector2(1536,1024)
var camadas: Dictionary = {}
var rios: Array[Dictionary] = []
var estacao := -1
var montado := false
var _raiz := Node2D.new()
var _tile_set: TileSet
var _objetos: TileSet
var _tiles: Dictionary = {}
var _fontes_objetos: Dictionary = {}
var _dados: Dictionary = LAYOUT.data
var _mascaras: Texture2D
var _quedas: Texture2D
var _material_solo: ShaderMaterial

func _ready() -> void:
	_raiz.scale=Vector2.ONE/4
	add_child(_raiz)
	await definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)

func _gerar_atlas(indice: int) -> Array[Texture2D]:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(512,640)
	viewport.disable_3d=true
	viewport.transparent_bg=true
	viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var quad := ColorRect.new()
	quad.size=Vector2(512,640)
	var material := ShaderMaterial.new()
	material.shader=preload("res://codigo/campanha/atlas_mapa_tiles.gdshader")
	material.set_shader_parameter("solo",load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % INGLES[indice]))
	material.set_shader_parameter("inverno",1.0 if indice==3 else 0.0)
	quad.material=material
	viewport.add_child(quad)
	# Peças de rocha independentes, com acabamento sazonal e borda inferior vazada.
	var rochas:Texture2D=load("res://assets/ui/campanha/tiles/paredoes_sazonais.png")
	var tamanho_rocha:=rochas.get_size()/4.0
	for x in 8:
		var recorte:=AtlasTexture.new()
		recorte.atlas=rochas
		recorte.region=Rect2(Vector2(x%4,indice)*tamanho_rocha+Vector2.ONE,tamanho_rocha-Vector2(2,2))
		recorte.filter_clip=true
		var peca:=TextureRect.new()
		peca.texture=recorte
		peca.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		peca.size=Vector2(64,64)
		peca.position=Vector2(x*64,384)
		viewport.add_child(peca)
	var cascatas := SubViewport.new()
	cascatas.size=Vector2i(1024,192)
	cascatas.disable_3d=true
	cascatas.transparent_bg=true
	cascatas.world_2d=World2D.new()
	cascatas.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(cascatas)
	var atlas := preload("res://assets/ui/campanha/regiao_camadas/cachoeira.png")
	for i in 8:
		var quadro := AtlasTexture.new()
		quadro.atlas=atlas
		quadro.region=Rect2((i%4)*384+58,(i/4)*512+45,276,440)
		quadro.filter_clip=true
		var textura := TextureRect.new()
		textura.texture=quadro
		textura.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		textura.size=Vector2(128,192)
		textura.position=Vector2(i*128,0)
		textura.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		cascatas.add_child(textura)
	await RenderingServer.frame_post_draw
	var resultado: Array[Texture2D]=[ImageTexture.create_from_image(viewport.get_texture().get_image()),ImageTexture.create_from_image(cascatas.get_texture().get_image())]
	viewport.queue_free()
	cascatas.queue_free()
	return resultado

func definir_estacao(indice: int) -> void:
	indice=clampi(indice,0,3)
	if estacao==indice:return
	estacao=indice
	montado=false
	var atlas := await _gerar_atlas(indice)
	_mascaras=atlas[0]
	_quedas=atlas[1]
	for filho in _raiz.get_children():
		_raiz.remove_child(filho)
		filho.queue_free()
	camadas.clear()
	_fontes_objetos.clear()
	_objetos=TileSet.new()
	_objetos.tile_size=Vector2i(64,64)
	_tile_set=TileSet.new()
	_tile_set.tile_size=Vector2i(64,64)
	var fonte := TileSetAtlasSource.new()
	fonte.texture=_mascaras
	fonte.texture_region_size=Vector2i(64,64)
	for y in 7:
		for x in 8:fonte.create_tile(Vector2i(x,y))
	for x in 4:fonte.create_tile(Vector2i(x,8))
	_tile_set.add_source(fonte,0)
	var agua := TileSetAtlasSource.new()
	agua.texture=_mascaras
	agua.texture_region_size=Vector2i(64,64)
	agua.create_tile(Vector2i(0,7))
	agua.set_tile_animation_columns(Vector2i(0,7),8)
	agua.set_tile_animation_frames_count(Vector2i(0,7),8)
	agua.set_tile_animation_speed(Vector2i(0,7),5)
	_tile_set.add_source(agua,1)
	var cachoeira := TileSetAtlasSource.new()
	cachoeira.texture=_quedas
	cachoeira.texture_region_size=Vector2i(64,64)
	for y in 3:
		cachoeira.create_tile(Vector2i(0,y),Vector2i(2,1))
		cachoeira.get_tile_data(Vector2i(0,y),0).texture_origin=Vector2i(-32,0)
		cachoeira.set_tile_animation_columns(Vector2i(0,y),8)
		cachoeira.set_tile_animation_frames_count(Vector2i(0,y),8)
		cachoeira.set_tile_animation_speed(Vector2i(0,y),10)
	_tile_set.add_source(cachoeira,2)
	_material_solo=ShaderMaterial.new()
	_material_solo.shader=preload("res://codigo/campanha/material_solo_tiles.gdshader")
	_material_solo.set_shader_parameter("grama",load("res://assets/cenario/cidade/chao_detalhado/grama_%s.png" % ESTACOES[indice]))
	_material_solo.set_shader_parameter("pedra",load("res://assets/cenario/cidade/chao_detalhado/pedra_%s.png" % ESTACOES[indice]))
	_material_solo.set_shader_parameter("terra",load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % INGLES[indice]))
	for dado in [["Agua",0],["Paredoes",1],["Terreno",2],["Pontes",3],["Cachoeiras",4],["Lugares",5],["Vegetacao",6]]:
		var camada := TileMapLayer.new()
		camada.name=dado[0]
		camada.tile_set=_objetos if dado[0] in ["Lugares","Vegetacao"] else _tile_set
		camada.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		camada.z_index=dado[1]
		_raiz.add_child(camada)
		camadas[dado[0]]=camada
	camadas.Terreno.material=_material_solo
	_preparar_rios()
	_montar_solo()
	_montar_pontes()
	_montar_quedas()
	_montar_lugares()
	montado=true
	pronto.emit()

func _ilha_contem(ilha: Dictionary,p: Vector2) -> bool:
	var centro:=Vector2(ilha.centro[0],ilha.centro[1])
	var raio:=Vector2(ilha.raios[0],ilha.raios[1])
	var q:Vector2=(p-centro)/raio
	var ondulacao:=sin(p.x*0.63+ilha.nivel)*0.025+cos(p.y*0.9)*0.025
	return q.length_squared()<0.94+ondulacao

func _nivel(p: Vector2,com_rio:=true) -> int:
	var nivel:=0
	for ilha in _dados.ilhas:
		if _ilha_contem(ilha,p):nivel=maxi(nivel,int(ilha.nivel))
	if com_rio:
		for rio in rios:
			if p.x>=rio.x and p.x<=rio.x+rio.largura and p.y>=rio.inicio and p.y<=rio.boca+1:return 0
	return nivel

func _preparar_rios() -> void:
	rios.clear()
	for dado in _dados.rios:
		for ilha in _dados.ilhas:
			if ilha.id!=dado.ilha:continue
			var boca:=int(ilha.centro[1])
			for y in range(boca,GRADE.y):
				if _ilha_contem(ilha,Vector2(dado.x+1,y)):boca=y
			rios.append({"ilha":ilha.id,"x":int(dado.x),"largura":int(dado.largura),"inicio":int(ilha.centro[1]),"boca":boca,"altura":int(ilha.nivel)+1})

func _estrada(p: Vector2) -> bool:
	for rota in _dados.rotas:
		for i in rota.size()-1:
			var a:=Vector2(rota[i][0],rota[i][1])
			var b:=Vector2(rota[i+1][0],rota[i+1][1])
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<0.85:return true
	return false

func _montar_solo() -> void:
	for y in range(-24,GRADE.y+24):
		for x in range(-24,GRADE.x+24):
			camadas.Agua.set_cell(Vector2i(x,y),1,Vector2i(0,7))
	for y in GRADE.y:
		for x in GRADE.x:
			var p:=Vector2(x,y)
			var vertices: Array[Vector2]=[p,p+Vector2(1,0),p+Vector2(0,1),p+Vector2(1,1)]
			var mascara:=0
			var estrada:=0
			for i in 4:
				if _nivel(vertices[i])>0:mascara|=1<<(3-i)
				if _estrada(vertices[i]):estrada|=1<<(3-i)
			if mascara==0:continue
			var tile:=Vector2i(mascara%8,2+mascara/8)
			if mascara==15:tile=Vector2i(estrada%8,estrada/8)
			camadas.Terreno.set_cell(Vector2i(x,y),0,tile)
			if _nivel(p+Vector2(0.5,1.5),false)==0 and _nivel(p+Vector2(0.5,0.5),false)>0:
				var altura:=_nivel(p+Vector2(0.5,0.5),false)+1
				for dy in range(1,altura+1):
					camadas.Paredoes.set_cell(Vector2i(x,y+dy),0,Vector2i(2 if dy==altura else (3 if dy==1 else (x+y)%2),6))

func _montar_pontes() -> void:
	for y in GRADE.y:
		for x in GRADE.x:
			var p:=Vector2(x+0.5,y+0.5)
			if _nivel(p)>0 or not _estrada(p):continue
			var vertical:=_estrada(p+Vector2(0,1)) and not _estrada(p+Vector2(1,0))
			camadas.Pontes.set_cell(Vector2i(x,y),0,Vector2i(2 if vertical else 0,8))

func _montar_quedas() -> void:
	for rio in rios:
		for x in range(rio.x,rio.x+rio.largura,2):
			for y in range(rio.altura+1):
				var quadro:=0 if y==0 else (2 if y==rio.altura else 1)
				camadas.Cachoeiras.set_cell(Vector2i(x,rio.boca+y),2,Vector2i(0,quadro))

func _fonte_objeto(chave: String,textura: Texture2D,regiao:=Vector2i.ZERO,origem:=Vector2i.ZERO) -> int:
	if _fontes_objetos.has(chave):return _fontes_objetos[chave]
	var imagem:=textura.get_image()
	if not imagem.has_mipmaps():imagem.generate_mipmaps()
	textura=ImageTexture.create_from_image(imagem)
	var fonte:=TileSetAtlasSource.new()
	fonte.texture=textura
	fonte.texture_region_size=Vector2i(textura.get_size()) if regiao==Vector2i.ZERO else regiao
	fonte.create_tile(origem)
	var tile:=fonte.get_tile_data(origem,0)
	tile.texture_origin=Vector2i(0,fonte.texture_region_size.y/2-32)
	var id:=_objetos.add_source(fonte)
	_fontes_objetos[chave]=id
	return id

func _casa(id: String,p: Vector2i) -> void:
	var dados:=preload("res://codigo/cidade/fachadas_detalhadas.gd").dados(id)
	var tex:Texture2D=load(dados.texturas[estacao])
	camadas.Lugares.set_cell(p,_fonte_objeto(id,tex),Vector2i.ZERO)

func _peca(id: String,p: Vector2i) -> void:
	var tex:Texture2D=load("res://assets/cenario/fazenda/natureza_detalhada/%s/%s.png" % [ESTACOES[estacao],id])
	camadas.Vegetacao.set_cell(p,_fonte_objeto(id,tex),Vector2i.ZERO)

func _montar_lugares() -> void:
	_casa("casa_bento",Vector2i(30,31))
	_casa("venda",Vector2i(38,34))
	_casa("enfermaria",Vector2i(33,37))
	_casa("mistica",Vector2i(45,13))
	_peca("carvalho",Vector2i(33,28))
	for y in [23,27,31]:
		for x in [8,12,16]:_peca("jovem",Vector2i(x,y))
	var gerador:=RandomNumberGenerator.new()
	gerador.seed=9137
	for i in 150:
		var p:=Vector2i(gerador.randi_range(3,92),gerador.randi_range(5,59))
		if _nivel(Vector2(p))==0 or _estrada(Vector2(p)):continue
		var perto:=false
		for rota in _dados.rotas:
			for alvo in rota:
				if Vector2(p).distance_to(Vector2(alvo[0],alvo[1]))<4:perto=true
		if not perto:_peca("pinheiro" if p.x>50 else "carvalho",p)
	for p in [Vector2i(78,38),Vector2i(83,36),Vector2i(85,42),Vector2i(89,39)]:
		_peca("pedra_0",p)
	_montar_portal()
	var atlas:Texture2D=load("res://assets/ui/campanha/tiles/locais_sazonais.png")
	var celula:=Vector2i(atlas.get_width()/4,atlas.get_height()/4)
	var destinos:=[Vector2i(44,41),Vector2i(84,31),Vector2i(18,14),Vector2i(79,16)]
	for i in 4:
		var pos:=Vector2i(i,estacao)
		var fonte:=_fonte_objeto("destino_%d" % i,atlas,celula,pos)
		camadas.Lugares.set_cell(destinos[i],fonte,pos)

func _montar_portal() -> void:
	var textura:Texture2D=load("res://assets/cenario/cidade/complementos/portal/%s.png" % ESTACOES[estacao])
	var fonte:=TileSetAtlasSource.new()
	fonte.texture=textura
	fonte.texture_region_size=Vector2i(textura.get_width()/9,textura.get_height())
	fonte.create_tile(Vector2i.ZERO)
	fonte.set_tile_animation_columns(Vector2i.ZERO,9)
	fonte.set_tile_animation_frames_count(Vector2i.ZERO,9)
	fonte.set_tile_animation_speed(Vector2i.ZERO,8)
	fonte.get_tile_data(Vector2i.ZERO,0).texture_origin=Vector2i(0,fonte.texture_region_size.y/2-32)
	camadas.Lugares.set_cell(Vector2i(15,49),_objetos.add_source(fonte),Vector2i.ZERO)
