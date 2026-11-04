extends Node
## Mantém a atenção no acampamento até perceber um jogador ou receber um golpe.
var alvo_atividade:=Vector2.ZERO
var atividade:="vigiar"
var _goblin:Node2D
var _vida_inicial:=0

func _ready() -> void:
	_goblin=get_parent();_vida_inicial=_goblin.vida
	_goblin.ia_habilitada=false
	_goblin.definir_direcao_animacao(alvo_atividade-_goblin.global_position)

func _physics_process(_delta:float) -> void:
	if _goblin.esta_morto:set_physics_process(false);return
	if _goblin.vida<_vida_inicial:_alertar();return
	var raio:=146.0 if atividade=="vigiar" else 112.0
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if bool(jogador.get("estaMorto")):continue
		if _goblin.global_position.distance_to(jogador.global_position)>raio:continue
		var raio_visao:=PhysicsRayQueryParameters2D.create(_goblin.global_position,jogador.global_position,64)
		if _goblin.get_world_2d().direct_space_state.intersect_ray(raio_visao).is_empty():
			_alertar();return

func _alertar() -> void:
	_goblin.ia_habilitada=true
	set_physics_process(false)
