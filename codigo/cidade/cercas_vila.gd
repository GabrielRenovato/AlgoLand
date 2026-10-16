extends Node2D

## Trechos curtos de madeira nos jardins. As entradas ficam abertas e só há cerca em grama pura.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PASTA := "res://assets/cenario/fazenda/cerca/"
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
# x, y da base, quantidade de travessas. Os vãos entre trechos servem de portões.
const TRECHOS := [
	Vector3i(32, 248, 3), Vector3i(128, 248, 3),
	Vector3i(160, 328, 3), Vector3i(224, 328, 2),
	Vector3i(528, 312, 3), Vector3i(592, 312, 3),
	Vector3i(24, 496, 2), Vector3i(88, 496, 3),
	Vector3i(192, 512, 2), Vector3i(256, 512, 3),
	Vector3i(496, 496, 3), Vector3i(560, 496, 3),
]
var _pecas: Array[Sprite2D] = []
var _estacoes: Node

func _ready() -> void:
	name = "CercasJardins"
	var terreno: TileMapLayer = get_parent().get_node("Terrains/Terreno")
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	for trecho in TRECHOS:
		for i in trecho.z:
			var base := Vector2(trecho.x + i * 16, trecho.y)
			# Não ocupar ruas, acessos, margens ou água, inclusive quando o mapa for regenerado.
			if not _grama(terreno, base) or not _grama(terreno, base + Vector2(16, 0)):
				continue
			_peca(base, "horizontal")
			_peca(base + Vector2(16, 0), "poste")
			var forma := CollisionShape2D.new()
			var caixa := RectangleShape2D.new()
			caixa.size = Vector2(20, 4)
			forma.shape = caixa
			forma.position = base + Vector2(6, -2)
			corpo.add_child(forma)
	_estacoes = get_parent().get_node("Terrains/Estacoes")
	_estacoes.estacao_mudou.connect(_aplicar_estacao)
	_aplicar_estacao(maxi(0, int(_estacoes.estacao_atual)))

func _grama(terreno: TileMapLayer, ponto: Vector2) -> bool:
	var celula := terreno.local_to_map(ponto)
	return terreno.get_cell_source_id(celula) == 0 and terreno.get_cell_atlas_coords(celula).y == 4

func _peca(base: Vector2, tipo: String) -> void:
	var sprite := Sprite2D.new()
	sprite.position = base
	sprite.centered = false
	sprite.offset = Vector2(-4, -23)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = Profundidade.z_de(base.y)
	sprite.set_meta("peca", tipo)
	sprite.add_to_group("cercas_vila")
	add_child(sprite)
	_pecas.append(sprite)

func _aplicar_estacao(estacao: int) -> void:
	for sprite in _pecas:
		sprite.texture = load(PASTA + ESTACOES[clampi(estacao, 0, 3)] + "/" + str(sprite.get_meta("peca")) + ".png")
