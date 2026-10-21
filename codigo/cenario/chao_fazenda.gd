extends Node2D
## Chão da fazenda no acabamento da cidade: grama e terra512×512 compostas uma vez por
## estação num SubViewport 4x. Só a apresentação muda: células, atlas, colisões e a cobertura da terra
## usada pelo plantio (LimitePlantio) continuam as dos tiles originais.
const SHADER := preload("res://codigo/cenario/chao_fazenda.gdshader")
const LimitePlantio := preload("res://codigo/cenario/limite_plantio.gd")
const ESTACOES := ["primavera","verao","outono","inverno"]
const ESCALA := 4
## Altura em pixels da faixa de grama no pé do penhasco.
const RODAPE := 4
const GRAMAS: Array[Vector2i] = [Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(0,4),Vector2i(0,5)]
var area := Rect2()
var estacao := -1
var _estacoes
var _terreno: Node2D
var _chao: TileMapLayer
var _terra: TileMapLayer
var _cache: SubViewport
var _material: ShaderMaterial
var _sprite: Sprite2D
var _flores: Flores
var _rodape: Sprite2D
var _mascaras := {}
var _pronto := false

## Só as flores do tile original (o desenho com grama antiga embaixo é descartado).
class Flores extends Node2D:
	var celulas := {}
	var texturas := {}
	func _draw() -> void:
		for celula in celulas:
			var textura: Texture2D = texturas.get(celulas[celula])
			if textura != null: draw_texture(textura,Vector2(celula*16))

func configurar(terreno: Node2D, estacoes) -> void:
	_terreno=terreno
	_estacoes=estacoes
	_chao=terreno.get_node("Chao")
	_terra=terreno.get_node("Terra")
	var usado := _chao.get_used_rect()
	area=Rect2(Vector2(usado.position*16),Vector2(usado.size*16))
	name="ChaoFazenda"
	terreno.add_child(self)
	# Logo acima do Chao e abaixo de Terra/Penhasco/Detalhes (mesmo z), que seguem desenhados por cima.
	terreno.move_child(self,_chao.get_index()+1)
	z_index=_chao.z_index
	_material=ShaderMaterial.new()
	_material.shader=SHADER
	_material.set_shader_parameter("origem",area.position)
	_material.set_shader_parameter("tamanho",area.size)
	_cache=SubViewport.new()
	_cache.size=Vector2i(area.size*ESCALA)
	_cache.disable_3d=true
	_cache.transparent_bg=true
	_cache.world_2d=World2D.new()
	_cache.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(_cache)
	var pintura := Pintura.new()
	pintura.area=area
	pintura.material=_material
	_cache.add_child(pintura)
	var camera := Camera2D.new()
	camera.position=area.get_center()
	camera.zoom=Vector2(ESCALA,ESCALA)
	_cache.add_child(camera)
	_sprite=Sprite2D.new()
	_sprite.centered=false
	_sprite.position=area.position
	_sprite.scale=Vector2.ONE/float(ESCALA)
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture=_cache.get_texture()
	add_child(_sprite)
	_flores=Flores.new()
	_flores.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_flores)
	_coletar_flores()
	_montar_rodape()
	visible=false

class Pintura extends Node2D:
	var area := Rect2()
	func _draw() -> void: draw_rect(area,Color.WHITE)

## A faixa de grama clara no pé do paredão é de outra paleta; o chão novo a cobre depois do Penhasco.
func _montar_rodape() -> void:
	var penhasco := _terreno.get_node_or_null("Penhasco") as TileMapLayer
	if penhasco == null or penhasco.get_used_cells().is_empty(): return
	var usado := penhasco.get_used_rect()
	var faixa := Rect2(Vector2(usado.position.x*16,usado.end.y*16-RODAPE),Vector2(usado.size.x*16,RODAPE))
	_rodape=Sprite2D.new()
	_rodape.name="RodapePenhasco"
	_rodape.centered=false
	_rodape.position=faixa.position
	_rodape.scale=Vector2.ONE/float(ESCALA)
	_rodape.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_rodape.texture=_cache.get_texture()
	_rodape.region_enabled=true
	_rodape.region_rect=Rect2((faixa.position-area.position)*ESCALA,faixa.size*ESCALA)
	_rodape.z_index=penhasco.z_index
	_terreno.add_child(_rodape)
	_terreno.move_child(_rodape,penhasco.get_index()+1)

func _coletar_flores() -> void:
	var celulas: Dictionary = _flores.celulas
	var grama = _estacoes.get("_grama_continua")
	if grama != null:
		for dados in grama._celulas:
			if dados.camada == _chao and dados.banco >= 1: celulas[dados.celula]=dados.atlas
	for celula in _chao.get_used_cells():
		var atlas := _chao.get_cell_atlas_coords(celula)
		if _chao.get_cell_source_id(celula) == 0 and atlas.x <= 3 and atlas.y in [6,7]: celulas[celula]=atlas

func aplicar(indice: int) -> void:
	estacao=clampi(indice,0,3)
	_material.set_shader_parameter("grama",load("res://assets/cenario/cidade/chao_detalhado/grama_%s.png" % ESTACOES[estacao]))
	_material.set_shader_parameter("terra",load("res://assets/cenario/fazenda/natureza_detalhada/%s/terra.png" % ESTACOES[estacao]))
	_material.set_shader_parameter("distribuicao",_mascara(estacao))
	_desenhar_flores()
	_cache.render_target_update_mode=SubViewport.UPDATE_ONCE
	if not _pronto: _substituir_base.call_deferred()

## Cobertura de terra pixel a pixel, pela mesma definição que o arado usa; o resto é grama.
func _mascara(indice: int) -> ImageTexture:
	if _mascaras.has(indice): return _mascaras[indice]
	var imagem := Image.create(int(area.size.x),int(area.size.y),false,Image.FORMAT_RGBA8)
	imagem.fill(Color(1,0,0,1))
	var terra := Color(0,0,1,1)
	var origem := Vector2i(area.position)
	for celula in _terra.get_used_cells():
		var atlas: Vector2i = _estacoes._terra_continua.atlas_original(celula)
		var base := celula*16-origem
		if atlas in LimitePlantio.CENTROS:
			imagem.fill_rect(Rect2i(base,Vector2i(16,16)),terra)
			continue
		for y in 16:
			for x in 16:
				if LimitePlantio.cobre_pixel(indice,atlas,x,y): imagem.set_pixel(base.x+x,base.y+y,terra)
	var textura := ImageTexture.create_from_image(imagem)
	_mascaras[indice]=textura
	return textura

func _desenhar_flores() -> void:
	var folha := LimitePlantio.FOLHAS[estacao].get_image()
	if folha.is_compressed(): folha.decompress()
	var paleta := {}
	for atlas in GRAMAS:
		for y in 16:
			for x in 16: paleta[folha.get_pixel(atlas.x*16+x,atlas.y*16+y).to_rgba32()]=true
	var texturas: Dictionary = _flores.texturas
	texturas.clear()
	for atlas in _flores.celulas.values():
		if texturas.has(atlas): continue
		var imagem := Image.create(16,16,false,Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var cor := folha.get_pixel(atlas.x*16+x,atlas.y*16+y)
				if not paleta.has(cor.to_rgba32()): imagem.set_pixel(x,y,cor)
		texturas[atlas]=ImageTexture.create_from_image(imagem)
	_flores.queue_redraw()

func _substituir_base() -> void:
	# O chão novo só entra depois de pintado, para a tela nunca ficar sem terreno.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_pronto=true
	sincronizar()

## O modo de comparação Tiny traz os tiles de volta e esconde o chão composto.
func sincronizar() -> void:
	var tiny := bool(_terreno.get_meta("visual_tiny",false))
	visible=_pronto and not tiny
	if _rodape != null: _rodape.visible=visible
	_chao.visible=not visible
	_terra.visible=not visible
