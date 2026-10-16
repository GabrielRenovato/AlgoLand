extends Node

## Acabamento de cenário sem alterar atlas, células, animações ou colisões.
const ShaderTiles := preload("res://codigo/cenario/acabamento_tiles.gdshader")
const AGUA := "res://codigo/cidade/agua_cidade.gdshader"
const DESENHO_SOLO := "res://codigo/logica/plantio.gd"
var material_tiles: ShaderMaterial
var _materiais_agua: Array[WeakRef] = []
var ativo := true:
	set(valor):
		ativo = valor
		if material_tiles != null:
			material_tiles.set_shader_parameter("intensidade_acabamento",1.0 if ativo else 0.0)
		for referencia in _materiais_agua:
			var material: ShaderMaterial = referencia.get_ref()
			if material != null:
				material.set_shader_parameter("intensidade_acabamento",1.0 if ativo else 0.0)

func _ready() -> void:
	material_tiles = ShaderMaterial.new()
	material_tiles.shader = ShaderTiles
	get_tree().node_added.connect(_ao_no_adicionado)
	aplicar_arvore(get_tree().root)

static func textura_de_cenario(textura: Texture2D) -> bool:
	if textura == null:
		return false
	if textura is AtlasTexture:
		return textura_de_cenario(textura.atlas)
	return textura.resource_path.begins_with("res://assets/cenario/")

func _ao_no_adicionado(no: Node) -> void:
	if no is TileMapLayer or no is Sprite2D or no is Polygon2D or (no.get_script() != null and no.get_script().resource_path == DESENHO_SOLO):
		_aplicar_referencia.call_deferred(weakref(no))

func _aplicar_referencia(referencia: WeakRef) -> void:
	var no: Node = referencia.get_ref()
	if is_instance_valid(no):
		aplicar_no(no)

func aplicar_arvore(no: Node) -> void:
	aplicar_no(no)
	for filho in no.get_children():
		aplicar_arvore(filho)

func aplicar_no(no: Node) -> void:
	if not is_instance_valid(no) or not no.is_inside_tree() or not no is CanvasItem:
		return
	var elegivel := false
	if no is TileMapLayer and no.tile_set != null:
		for i in no.tile_set.get_source_count():
			var fonte: TileSetSource = no.tile_set.get_source(no.tile_set.get_source_id(i))
			if fonte is TileSetAtlasSource and textura_de_cenario(fonte.texture):
				elegivel = true
	elif no is Sprite2D or no is Polygon2D:
		elegivel = textura_de_cenario(no.texture)
	elif no.get_script() != null and no.get_script().resource_path == DESENHO_SOLO:
		elegivel = true
	if not elegivel:
		return
	if no.material == null:
		no.material = material_tiles
	elif no.material is ShaderMaterial and no.material.shader != null and no.material.shader.resource_path == AGUA:
		var material: ShaderMaterial = no.material
		material.set_shader_parameter("intensidade_acabamento",1.0 if ativo else 0.0)
		for referencia in _materiais_agua:
			if referencia.get_ref() == material:
				return
		_materiais_agua.append(weakref(material))
