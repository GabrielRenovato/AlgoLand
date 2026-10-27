extends "res://codigo/jogador/representacao_heroi_3d.gd"
## Mesmo modelo 3D do jogador, com aparência pública validada e sem lógica de jogo.
var dados := {}
var _pose_ranking := "parado"
var _tempo := 0.0
func _ready() -> void:
	aparencia = dados
	super._ready()
	if usando_espada or usando_lanca:
		_pose_ranking = "guarda" if heroi._tem_espada() and (usando_escudo or heroi._arma_de_duas_maos()) else "guarda_livre"
	_process(0.0)
func _process(delta: float) -> void:
	_tempo += delta
	if _pose_ranking=="parado": pose(false,0,_tempo)
	else:
		var clipe: String = heroi._nome_animacao(_pose_ranking)
		_posar(_pose_ranking,clipe,0,fposmod(_tempo,heroi._player.get_animation(clipe).length))
