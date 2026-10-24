extends "res://codigo/jogador/heroi_raven.gd"
## Mesmo compositor Raven do jogador, com modelo de dados isolado e repouso ou pose de guarda.
const ArmasRanking := preload("res://codigo/dados/armas_ranking.gd")
var dados := {}
var _pose_ranking := "parado"

func _ready() -> void:
	_jogador = preload("res://codigo/dados/visual_ranking.gd").criar_modelo(dados)
	add_child(_jogador)
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-40,-47)
	hframes = 4
	vframes = 4
	_direcao = 0
	_montar_camadas()
	var arma: String = _jogador.aparencia_raven.arma_mais_usada
	_pose_ranking = ArmasRanking.ARMAS.get(arma,"parado")
	_aplicar_aparencia(_pose_ranking)
	_process(0.0)

func _process(delta: float) -> void:
	_tempo += delta
	# Primeiro quadro da mesma pose de guarda usada pelo jogador: arma na mão, sem atacar.
	frame = int(fmod(_tempo,0.8)/0.2) if _pose_ranking=="parado" else 0
	for camada in _camadas: camada.frame = frame

func _exit_tree() -> void:
	pass

## Inclui cabelos, elmos e a arma dos quadros efetivamente exibidos.
func topo_aparente() -> float:
	var topo := 0.0
	var camadas: Array[Sprite2D] = [self]
	camadas.append_array(_camadas)
	for camada in camadas:
		if camada.texture == null: continue
		var imagem := camada.texture.get_image()
		var quadro := Vector2i(imagem.get_size()/Vector2i(4,4))
		for coluna in (4 if _pose_ranking=="parado" else 1):
			var usado := imagem.get_region(Rect2i(Vector2i(coluna*quadro.x,0),quadro)).get_used_rect()
			if usado.has_area(): topo = minf(topo,camada.offset.y+usado.position.y)
	return topo
