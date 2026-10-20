extends CharacterBody2D

## Galinhas e galo ambiente: caminham, bicam, desviam e procuram abrigo no mau tempo.
var indice := 0
var area: Rect2
var entrada_abrigo: Vector2
var sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
var _alvo: Vector2
var _pausa := 0.0
var _tempo := 0.0
var _abrigada := false
var _saida_em := 0.0

func _ready() -> void:
	add_to_group("aves_quintal_carpinteiro")
	collision_layer = 0
	collision_mask = 64
	_rng.seed = 5327+indice*59
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 3
	forma.shape = circulo
	add_child(forma)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/cenario/fazenda/galinheiro/"+("galo" if indice==4 else "galinha_white" if indice%2==0 else "galinha_brown_white")+".png")
	sprite.hframes = 4
	sprite.vframes = 7
	sprite.offset.y = -5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_alvo = position
	_pausa = _rng.randf_range(0.5,2.5)
	preload("res://codigo/cidade/sombra_cidade.gd").contato(self,9,2,Vector2(0,1))

func _physics_process(delta: float) -> void:
	_tempo += delta
	var vila := get_parent().get_parent()
	var hora: float = vila.hora_atual()
	var recolher: bool = hora < 7 or hora >= 18 or vila.clima_atual() in [2,3,4,5,6]
	if recolher:
		_alvo = entrada_abrigo
		if position.distance_to(_alvo) < 3:
			if not _abrigada: _saida_em = indice*0.65
			_abrigada = true
			visible = false
			return
	elif _abrigada:
		_saida_em -= delta
		if _saida_em > 0: return
		_abrigada = false
		visible = true
		_pausa = 0
		_novo_alvo()
	velocity = Vector2.ZERO
	if not recolher and _pausa > 0:
		_pausa -= delta
	else:
		if position.distance_to(_alvo) < 2:
			_pausa = _rng.randf_range(1.5,4.5)
			_novo_alvo()
		else:
			velocity = position.direction_to(_alvo)*12
			for outra in get_tree().get_nodes_in_group("aves_quintal_carpinteiro"):
				if outra == self or outra.get_world_2d()!=get_world_2d() or not outra.visible: continue
				var distancia: float = position.distance_to(outra.position)
				if distancia>0.01 and distancia<10: velocity += outra.position.direction_to(position)*(10-distancia)*2
			move_and_slide()
			if get_slide_collision_count()>0 and not recolher: _novo_alvo()
	if absf(velocity.x)>0.1: sprite.flip_h = velocity.x<0
	sprite.frame = (4 if velocity.length()>1 else 8)+int(_tempo/(0.15 if velocity.length()>1 else 0.28))%4
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(global_position.y)

func _novo_alvo() -> void:
	_alvo = Vector2(_rng.randf_range(area.position.x,area.end.x),_rng.randf_range(area.position.y,area.end.y))
