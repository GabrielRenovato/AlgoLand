extends Node2D
## Estado da pesca; corpo, roupa e vara pertencem ao renderizador Raven.
const Arco := preload("res://codigo/jogador/arco_jogador.gd")
var _linha := 0
var _pose := 0
var em_espera := false
var tensao := 0.0

func iniciar(jogador: Node2D, direcao: Vector2) -> void:
	name = "AnimacaoPesca"
	_linha = Arco.linha_da_direcao(direcao)
	jogador.add_child(self)

func pose(indice: int, esperando := false) -> void:
	em_espera = esperando
	_pose = clampi(indice,0,7)

func ponta() -> Vector2:
	return get_parent().get_node("HeroiRaven").ponta_pesca(_pose,_linha)

func ponta_arremesso() -> Vector2:
	return get_parent().get_node("HeroiRaven").ponta_pesca(2,_linha)
