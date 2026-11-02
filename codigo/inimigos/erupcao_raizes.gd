extends Node2D

## Apenas representação: dano e janelas pertencem ao rebento no anfitrião.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var tempo := 0.0
var somente_visual := false
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("espelhos_coop")
	z_as_relative=false
	z_index=Profundidade.z_de(global_position.y)
	_sprite=Sprite2D.new()
	_sprite.texture=load("res://assets/inimigos/rebento_raizes/erupcao.png")
	_sprite.hframes=4
	_sprite.centered=false
	_sprite.offset=Vector2(-512,-800)
	_sprite.scale=Vector2.ONE*.065
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

func _process(delta: float) -> void:
	if somente_visual: return
	atualizar(tempo+delta)
	if tempo>=.55: queue_free()

func atualizar(instante: float) -> void:
	tempo=instante
	_sprite.frame=mini(int(tempo/.14),3)

func espelho() -> Dictionary:
	return {"k":"erupcao_raizes","x":global_position.x,"y":global_position.y,"t":tempo}
