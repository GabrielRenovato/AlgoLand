extends Node2D

## Casca de gelo em seis quadros: formação, brilho e quebra. Sem dano próprio.
var _sprite: Sprite2D
var _tempo := 0.0
var _quebrando := false

func _ready() -> void:
	var alvo := get_parent()
	var corpo: Sprite2D = alvo.get_node("Texture")
	var imagem := corpo.texture.get_image()
	var tamanho := Vector2i(imagem.get_width() / corpo.hframes, imagem.get_height() / corpo.vframes)
	var origem := Vector2i((corpo.frame % corpo.hframes) * tamanho.x, (corpo.frame / corpo.hframes) * tamanho.y)
	var area := imagem.get_region(Rect2i(origem, tamanho)).get_used_rect()
	var variante := "pequeno" if area.size.y <= 22 else ("grande" if area.size.y > 40 or area.size.x > 32 else "normal")
	if area.size.x > 64 or area.size.y > 64:
		variante = "gigante"
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://Efeitos/congelamento/" + variante + ".png")
	_sprite.hframes = 6
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var quadro := Vector2(_sprite.texture.get_width() / 6, _sprite.texture.get_height())
	var retangulo := corpo.get_rect()
	_sprite.scale = corpo.scale
	_sprite.position = corpo.position + Vector2(retangulo.position.x + area.get_center().x, retangulo.position.y + area.end.y - quadro.y / 2.0 + 2) * corpo.scale
	_sprite.z_index = corpo.z_index + 1
	add_child(_sprite)

func renovar() -> void:
	if _quebrando:
		_tempo = 0.2
	_quebrando = false

func descongelar() -> void:
	if not _quebrando:
		_tempo = 0.0
		_quebrando = true

func _process(delta: float) -> void:
	_tempo += delta
	if _quebrando:
		_sprite.frame = 4 if _tempo < 0.12 else 5
		if _tempo >= 0.24:
			queue_free()
	else:
		_sprite.frame = (0 if _tempo < 0.08 else 1) if _tempo < 0.16 else 2 + (int(_tempo * 6) % 2)
