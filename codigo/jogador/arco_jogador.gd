extends Node2D
## Tempos e sinais da ação; o visual é desenhado exclusivamente por HeroiRaven.


signal disparo_liberado(direcao: Vector2)
signal disparo_terminado

enum Estado { CARREGANDO, DISPARANDO }

const QUADROS_POR_LINHA := 8
const DURACAO_DISPARO: Array[float] = [0.18, 0.1, 0.1, 0.1, 0.4, 0.05, 0.05, 0.1]
const QUADRO_SOLTAR := 5
const LINHA_DISPARO_RETO := 4
const Z_ATRAS := 2
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FRENTE := 6

var jogador = null

var _estado: Estado = Estado.CARREGANDO
var _linha: int = 0
var _indice: int = 0
var _tempo: float = 0.0
var _escala_tempo: float = 1.0
var _direcao_disparo: Vector2 = Vector2.DOWN
var _pagina: int = 2
var _textura_arco_p2: Texture2D = null
var _textura_arco_p3: Texture2D = null
var _cabelo_aplicado: int = -1
var _roupa_aplicada: int = -1
var _pecas_aplicadas: int = -1
var _raizes_aplicadas: Dictionary = {}

var _corpo: Sprite2D
var _roupa: Sprite2D
var _cabelo: Sprite2D
var _arco: Sprite2D
var _aljava: Sprite2D

func _ready() -> void:
	pass

func _criar_camada(z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = QUADROS_POR_LINHA
	sprite.vframes = QUADROS_POR_LINHA
	sprite.z_index = z
	add_child(sprite)
	return sprite

func configurar(textura_arco_p2: Texture2D, textura_arco_p3: Texture2D) -> void:
	_textura_arco_p2 = textura_arco_p2
	_textura_arco_p3 = textura_arco_p3
	if is_node_ready():
		_aplicar_texturas()

func esta_disparando() -> bool:
	return _estado == Estado.DISPARANDO

static func linha_da_direcao(direcao: Vector2) -> int:
	if absf(direcao.x) > absf(direcao.y):
		return 2 if direcao.x > 0.0 else 3
	return 0 if direcao.y > 0.0 else 1

func disparar(direcao: Vector2, escala_tempo: float) -> void:
	_direcao_disparo = direcao.normalized()
	_escala_tempo = escala_tempo
	_linha = linha_da_direcao(_direcao_disparo)
	_estado = Estado.DISPARANDO
	_indice = 0
	_tempo = 0.0
	_pagina = 3
	_aplicar_texturas()
	_aplicar_quadro()

func parar_disparo() -> void:
	if _estado != Estado.DISPARANDO:
		return
	_estado = Estado.CARREGANDO
	_indice = 0
	_tempo = 0.0
	_pagina = 2
	_aplicar_texturas()
	_aplicar_quadro()

func _process(delta: float) -> void:
	if not visible:
		return
	if _estado == Estado.DISPARANDO:
		_sincronizar_aparencia()
		_tempo += delta
		_avancar(DURACAO_DISPARO, _escala_tempo)
	elif jogador != null:
		# Segue a direção do corpo desenhado em BaseSprites (linha = quadro / 8)
		_linha = clampi(int(jogador.sprite_corpo.frame / QUADROS_POR_LINHA), 0, 3)
	_aplicar_quadro()

func _avancar(duracoes: Array[float], escala: float) -> void:
	while _tempo >= duracoes[_indice] * escala:
		_tempo -= duracoes[_indice] * escala
		_indice += 1
		if _indice >= duracoes.size():
			_estado = Estado.CARREGANDO
			_pagina = 2
			_indice = 0
			_tempo = 0.0
			_aplicar_texturas()
			disparo_terminado.emit()
			return
		elif _estado == Estado.DISPARANDO and _indice == QUADRO_SOLTAR:
			disparo_liberado.emit(_direcao_disparo)

func _coluna() -> int:
	return _indice if _estado == Estado.DISPARANDO else 0

func _linha_na_folha() -> int:
	return _linha + (LINHA_DISPARO_RETO if _estado == Estado.DISPARANDO else 0)

func _aplicar_quadro() -> void:
	pass

func _arco_na_frente(coluna: int) -> bool:
	if _pagina == 2:
		return _linha == 0
	match _linha:
		0:
			return true
		1:
			return false
	return coluna != 0

func _aplicar_texturas() -> void:
	pass

func _sincronizar_aparencia() -> void:
	pass
