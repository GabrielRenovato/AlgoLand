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
	return heroi.ponta_pesca_3d() if heroi != null else global_position

func ponta_arremesso() -> Vector2:
	var heroi := get_parent().get_node_or_null("HeroiBase3D")
	if heroi != null and heroi.visible and heroi._acao == "pesca":
		return _origem_arremesso if _origem_arremesso.is_finite() else ponta()
	return ponta()

## Só fixa a saída depois que o rig terminou a pose do quadro de lançamento.
func fixar_arremesso_3d() -> void:
	if not _origem_arremesso.is_finite(): _origem_arremesso = ponta()

## Quadro da pose de pesca (0..3) enviado aos outros jogadores: lançamento em três quadros e vara estendida depois.
const POSES := [0,1,2,3,3,3,3,3]
func quadro() -> int:
	return 3 if em_espera else POSES[clampi(_pose,0,7)]
