extends Node

## Atlas compartilhado pelos marcos ambientais; um único sinal por terreno.
@export var folhas: Array[Texture2D] = []
@export var protegida := false
@export var paredes: Array[Texture2D] = []
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var _atlas: Array[AtlasTexture] = []
var _faces: Sprite2D
var _objetos: Array[Sprite2D] = []

func _ready() -> void:
	for objeto in get_parent().get_node("Objetos3D").get_children():
		if objeto is Sprite2D and objeto.has_meta("decoracao_fenda"):
			_objetos.append(objeto)
			objeto.z_index = Profundidade.z_de(objeto.global_position.y)
			var atlas := objeto.texture as AtlasTexture
			if atlas and not _atlas.has(atlas):
				_atlas.append(atlas)
	_faces = get_parent().get_node_or_null("FacesMinerais") as Sprite2D
	var estacoes: Node = get_parent().get_node("Estacoes")
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)

func _trocar(indice: int) -> void:
	var estacao := clampi(indice, 0, 3)
	for atlas in _atlas:
		atlas.atlas = folhas[0 if protegida else estacao]
	if protegida:
		var tons := [Color(.83,.91,.91),Color(1,.95,.86),Color(.9,.85,.88),Color(.8,.85,1)]
		for objeto in _objetos:
			objeto.modulate = tons[estacao]
	if _faces and paredes.size() == 4:
		_faces.texture = paredes[estacao]
