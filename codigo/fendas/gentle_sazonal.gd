extends Node

## Compatibilidade dos mapas de floresta; usa apenas árvores e brilhos próprios.
@export var folhas_arvores: Array[Texture2D] = []
@export var brilho: Texture2D
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var _atlas: Array[AtlasTexture] = []
var _brilho: TileSetAtlasSource

func _ready() -> void:
	for objeto in get_parent().get_node("Objetos3D").get_children():
		if objeto is Sprite2D and objeto.get_meta("arvore_gentle",false):
			objeto.z_index = Profundidade.z_de(objeto.global_position.y)
			var atlas := objeto.texture as AtlasTexture
			if not _atlas.has(atlas): _atlas.append(atlas)
	_brilho = get_parent().get_node("Brilho").tile_set.get_source(0) as TileSetAtlasSource
	# Os brilhos próprios têm quatro quadros por animação.
	for linha in 3:
		_brilho.set_tile_animation_frames_count(Vector2i(0,linha),4)
		_brilho.set_tile_animation_columns(Vector2i(0,linha),4)
	var estacoes: Node = get_parent().get_node("Estacoes")
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)

func _trocar(indice: int) -> void:
	var paleta: String = str(get_meta("paleta","01"))
	folhas_arvores[indice] = load("res://assets/cenario/substitutos/arvores_florestas/v%s/%s.png" % [paleta,["spring","summer","autumn","winter"][indice]])
	for atlas in _atlas: atlas.atlas = folhas_arvores[clampi(indice,0,3)]
	_brilho.texture = get_parent().get_node("Estacoes").BRILHOS[indice]
