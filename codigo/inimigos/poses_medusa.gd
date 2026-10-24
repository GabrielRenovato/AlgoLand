extends RefCounted
## Poses desenhadas, com quadros próprios por direção e sem deformar a arte.
const DIRECOES := ["baixo", "cima", "direita", "esquerda"]
const PASTA := "res://assets/inimigos/medusa/poses/"
var _paginas := {}

static func preparo(progresso: float) -> float:
	# Arma o golpe rapidamente e sustenta a pose durante o restante do aviso.
	return clampf(progresso / 0.7, 0.0, 1.0) * 2.0

static func golpe(progresso: float) -> float:
	# O impacto coincide com o acerto das garras, aos 30% da etapa ativa.
	var tempo := clampf(progresso, 0.0, 1.0)
	return 2.0 + tempo / 0.3 if tempo <= 0.3 else 3.0 + (tempo - 0.3) / 0.7 * 1.5

static func recuperacao(progresso: float) -> float:
	# Retorna em cerca de 400 ms; a abertura para contra-ataque permanece inteira.
	return lerpf(4.5, 6.0, clampf(progresso / 0.42, 0.0, 1.0))

func _init() -> void:
	for pagina in ["garras", "cauda", "bote", "olhar"]:
		var caminho: String = PASTA + pagina + ".tres"
		if ResourceLoader.exists(caminho):
			_paginas[pagina] = load(caminho)

func possui(pagina: String) -> bool:
	return _paginas.has(pagina)

func indice(pagina: String, linha: int, pose: float) -> int:
	var animacao: SpriteFrames = _paginas[pagina]
	var quantidade := animacao.get_frame_count(DIRECOES[linha])
	var chaves: PackedInt32Array = animacao.get_meta("chaves_" + DIRECOES[linha])
	var posicao := fposmod(pose, 6.0)
	var origem := int(posicao)
	var inicio := float(chaves[origem])
	var fim := float(chaves[origem + 1]) if origem < 5 else float(quantidade)
	return int(lerpf(inicio, fim, fposmod(posicao, 1.0))) % quantidade

func aplicar(sprite: Sprite2D, pagina: String, linha: int, pose: float) -> void:
	var animacao: SpriteFrames = _paginas[pagina]
	sprite.texture = animacao.get_frame_texture(DIRECOES[linha], indice(pagina, linha, pose))
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.material = null

func olhos(pagina: String, linha: int, pose: float, padrao: Vector2) -> Vector2:
	var animacao: SpriteFrames = _paginas[pagina]
	var ancoras: Array = animacao.get_meta("olhos_" + DIRECOES[linha], [])
	var quadro := indice(pagina, linha, pose)
	return ancoras[quadro] if quadro < ancoras.size() else padrao
