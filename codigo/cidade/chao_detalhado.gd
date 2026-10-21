extends Node2D
## Camada de apresentação. Lê os tiles reais sem editar células, ids ou colisões.
const SHADER := preload("res://codigo/cidade/chao_detalhado.gdshader")
const ESTACOES := ["primavera","verao","outono","inverno"]
const TERRA := ["spring","summer","autumn","winter"]
var estacao := -1
var area := Rect2()
var distribuicao: Image
var _material: ShaderMaterial
var _terreno: TileMapLayer
var _agua: TileMapLayer
var _cache: SubViewport
var _renderizador: Node2D
var _sprite: Sprite2D
func configurar(terreno: TileMapLayer, agua: TileMapLayer, preparar_material := false) -> void:
	_terreno=terreno
	_agua=agua
	transform=terreno.transform
	var retangulo := terreno.get_used_rect().merge(agua.get_used_rect())
	area=Rect2(Vector2(retangulo.position*16),Vector2(retangulo.size*16))
	if not preparar_material:
		# Compor uma vez por estação. No jogo, o chão custa uma textura,
		# em vez de executar as misturas e o acabamento em todos os quadros.
		_cache=SubViewport.new()
		_cache.size=Vector2i(area.size*4)
		_cache.disable_3d=true
		_cache.transparent_bg=true
		_cache.world_2d=World2D.new()
		_cache.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(_cache)
		_renderizador=new()
		_cache.add_child(_renderizador)
		_renderizador.configurar(terreno,agua,true)
		var camera:=Camera2D.new()
		camera.position=area.get_center()
		camera.zoom=Vector2(4,4)
		_cache.add_child(camera)
		_sprite=Sprite2D.new()
		_sprite.centered=false
		_sprite.position=area.position
		_sprite.scale=Vector2(.25,.25)
		_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_sprite.texture=_cache.get_texture()
		add_child(_sprite)
		z_as_relative=false
		z_index=-999
		_substituir_base.call_deferred()
		return
	distribuicao=Image.create(retangulo.size.x*64,retangulo.size.y*64,false,Image.FORMAT_RGBA8)
	var cache := {}
	var agua_atlas: Image=load("res://assets/cenario/algoland_original/mascara_agua.png").get_image()
	for camada: TileMapLayer in [terreno,agua]:
		for celula in camada.get_used_cells():
			var id := camada.get_cell_source_id(celula)
			var atlas := camada.get_cell_atlas_coords(celula)
			var chave := Vector3i(id,atlas.x,atlas.y)
			if not cache.has(chave): cache[chave]=_mascara(id,atlas,agua_atlas)
			distribuicao.blit_rect(cache[chave],Rect2i(0,0,64,64),(celula-retangulo.position)*64)
	_alinhar_soleiras()
	_material=ShaderMaterial.new()
	_material.shader=SHADER
	_material.set_shader_parameter("distribuicao",ImageTexture.create_from_image(distribuicao))
	distribuicao=null
	_material.set_shader_parameter("origem",terreno.to_global(area.position))
	_material.set_shader_parameter("tamanho",area.size)
	material=_material
	z_as_relative=false
	z_index=-999
	queue_redraw()
func _mascara(id: int,atlas: Vector2i,agua_atlas: Image) -> Image:
	var imagem := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var baixo := Color.RED if id in [0,1,3] else Color.BLUE
	var cima := Color.BLUE if id==0 else (Color.BLACK if id==3 else Color.GREEN)
	for y in 64:
		for x in 64:
			var alto := false
			if atlas.y>=4:
				alto=atlas.y==5
			elif id==3:
				# Máscara exata da água: a margem física permanece intacta.
				alto=agua_atlas.get_pixel(atlas.x*16+x/4,atlas.y*16+y/4).r>.5
			else:
				var indice := atlas.y*4+atlas.x
				var u := float(x)/63.0
				var v := float(y)/63.0
				var a := 1.0 if indice&8 else 0.0
				var b := 1.0 if indice&4 else 0.0
				var c := 1.0 if indice&2 else 0.0
				var d := 1.0 if indice&1 else 0.0
				alto=lerpf(lerpf(a,b,u),lerpf(c,d,u),v)>=.5
			imagem.set_pixel(x,y,cima if alto else baixo)
	return imagem
func _alinhar_soleiras() -> void:
	# Os atlas16px arredondavam portas em meia célula para o lado. O
	# acabamento visual segue o centro real da soleira sem editar o mapa.
	var predios: Dictionary=preload("res://codigo/cidade/dados_cidade.gd").PREDIOS
	for dados: Dictionary in predios.values():
		var base: Vector2=dados.base
		var centro:=base.x+float(dados.get("porta_x",0))
		var antigo:=roundf(centro/16.0)*16.0
		# O gerador Python usa arredondamento para o par nas meias células.
		if is_equal_approx(fposmod(centro,16.0),8.0):
			antigo=float(roundi(centro/32.0))*32.0
		if is_equal_approx(centro,antigo): continue
		var rua:=272.0 if base.y<=272 else 448.0
		var inicio:=base.y-4.0
		var x0:=maxi(0,floori((minf(centro,antigo)-25.0-area.position.x)*4))
		var x1:=mini(distribuicao.get_width(),ceili((maxf(centro,antigo)+25.0-area.position.x)*4))
		var y0:=maxi(0,floori((minf(inicio,rua)-25.0-area.position.y)*4))
		var y1:=mini(distribuicao.get_height(),ceili((maxf(inicio,rua)+25.0-area.position.y)*4))
		for y in range(y0,y1):
			for x in range(x0,x1):
				var p:=area.position+Vector2(x+.5,y+.5)/4.0
				var novo:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(centro,inicio),Vector2(centro,rua)))<24.0
				var velho:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(antigo,inicio),Vector2(antigo,rua)))<24.0
				if novo==velho: continue
				var cor:=distribuicao.get_pixel(x,y)
				if cor.r+cor.g<.5: continue # água e terra não viram calçada
				if novo: distribuicao.set_pixel(x,y,Color.GREEN)
				elif absf(p.y-rua)>22.0: distribuicao.set_pixel(x,y,Color.RED)
	var bordas:=_terreno.get_parent().get_node_or_null("BordasGrama")
	if bordas!=null:
		bordas.tufos=bordas.tufos.filter(func(t):
			var p:=Vector2i((Vector2(t.raiz)-area.position)*4)
			return p.x>=0 and p.y>=0 and p.x<distribuicao.get_width() and p.y<distribuicao.get_height() and distribuicao.get_pixelv(p).r>.5)
func aplicar(indice: int) -> void:
	estacao=clampi(indice,0,3)
	if _renderizador!=null:
		_renderizador.aplicar(estacao)
		_cache.render_target_update_mode=SubViewport.UPDATE_ONCE
		return
	for tipo in ["grama","pedra"]:
		_material.set_shader_parameter(tipo,load("res://assets/cenario/cidade/chao_detalhado/%s_%s.png" % [tipo,ESTACOES[estacao]]))
	_material.set_shader_parameter("terra",load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % TERRA[estacao]))
func _draw() -> void:
	if material!=null: draw_rect(area,Color.WHITE)
func _substituir_base() -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(_terreno): _terreno.hide()
