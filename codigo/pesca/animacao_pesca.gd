extends Node2D
## Estado da pesca; o renderizador ativo fornece a ponta real da vara.
const Arco := preload("res://codigo/jogador/arco_jogador.gd")
var _linha := 0
var _pose := 0
var em_espera := false
var tensao := 0.0
var _origem_arremesso := Vector2.INF

func iniciar(jogador: Node2D, direcao: Vector2) -> void:
	name = "AnimacaoPesca"
	_linha = Arco.linha_da_direcao(direcao)
	jogador.add_child(self)

func pose(indice: int, esperando := false) -> void:
	em_espera = esperando
	_pose = clampi(indice,0,7)

func ponta() -> Vector2:
	var heroi := get_parent().get_node_or_null("HeroiBase3D")
	if heroi != null and heroi.visible and heroi._acao == "pesca":
		return heroi.ponta_pesca_3d()
	return get_parent().get_node("HeroiRaven").ponta_pesca(_pose,_linha)

func ponta_arremesso() -> Vector2:
	var heroi := get_parent().get_node_or_null("HeroiBase3D")
	if heroi != null and heroi.visible and heroi._acao == "pesca":
		return _origem_arremesso if _origem_arremesso.is_finite() else ponta()
	return get_parent().get_node("HeroiRaven").ponta_pesca(2,_linha)

## Só fixa a saída depois que o rig terminou a pose do quadro de lançamento.
func fixar_arremesso_3d() -> void:
	if not _origem_arremesso.is_finite(): _origem_arremesso = ponta()
