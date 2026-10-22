extends RefCounted

## Biblioteca4× compartilhada pela areia e pelos móveis do cais.
const RAIZ := "res://assets/cenario/praia/detalhada/"
const NOMES := ["primavera", "verao", "outono", "inverno"]
static var _manifesto: Dictionary = {}

static func dados(tipo: String) -> Dictionary:
	if _manifesto.is_empty():
		_manifesto = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "manifesto.json"))
	return _manifesto.get(tipo, {})

static func aplicar(sprite: Sprite2D, tipo: String, pai: Node2D) -> void:
	var item := dados(tipo)
	if item.is_empty():
		return
	if pai == sprite:
		# Assentos e áreas de uso são filhos do móvel: não herdam a escala4×.
		var pintura := Sprite2D.new()
		pintura.name="ImagemDetalhada"
		pintura.centered=false
		sprite.self_modulate.a=0.0
		sprite.add_child(pintura)
		sprite=pintura
	sprite.texture = load(item.texturas[0])
	# O pivô físico é independente do tamanho do arquivo4×.
	sprite.offset = Vector2(item.offset[0], item.offset[1])
	preload("res://codigo/cidade/detalhe_ambiente.gd").instalar(pai, sprite, item)
