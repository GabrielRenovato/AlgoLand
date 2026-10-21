extends Node2D
## Tempos e sinais da ação; o visual é desenhado exclusivamente por HeroiRaven.


signal terminou

const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")

const QUADROS_POR_LINHA := 8
const COLUNAS_SACAR: Array[int] = [0, 1, 2]
const COLUNA_APARAR := 3
const COLUNA_ESQUIVA := 4
const COLUNA_FERIDO := 5
const DURACAO_QUADRO_SACAR := 0.08
const CODIGOS_UM_MAO := {"espada_basica": "sw01", "espada_gemea": "sw02", "machado": "ax01", "maca": "mc01"}
const CODIGOS_ARCO := {"arco_curvo": "bo01", "arco_curto": "bo02", "arco_longo": "bo03"}
const Z_ATRAS := 2
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FRENTE := 6
const ORDEM := {
	"espada": ["BFBFFFBB", "FBBBBBBB", "BFFBFFBB", "BFFBFFBB"],
	"escudo": ["BFBBFBBB", "FBFFBFBB", "BBBFFBBB", "BBBFFBBB"],
	"lanca": ["BFFFFFFF", "FBBBBBBB", "BFFBFFFF", "BFFBFFFF"],
	"arco": ["BFFFFBBB", "FBBBBBFB", "BBFBFBBB", "BBFBFBBB"],
	"aljava": ["BBBBBBBB", "FFFFFFFF", "BBBBBBBB", "BBBBBBBB"],
}

var jogador = null
var pose_atual := ""

var _sequencia: Array = []  # lista de [coluna, duracao]
var _indice: int = 0
var _tempo: float = 0.0
var _linha: int = 0
var _familia: String = ""
var _cabelo_aplicado: int = -1
var _roupa_aplicada: int = -1
var _pecas_aplicadas: int = -1
var _raizes_aplicadas: Dictionary = {}

var _corpo: Sprite2D
var _roupa: Sprite2D
var _cabelo: Sprite2D
var _arma: Sprite2D
var _escudo: Sprite2D
var _aljava: Sprite2D

func _ready() -> void:
	visible = false

func _criar_camada(z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = QUADROS_POR_LINHA
	sprite.vframes = QUADROS_POR_LINHA
	sprite.z_index = z
	add_child(sprite)
	return sprite

const DURACAO_SEGURADA := 3600.0

func tocar(pose: String, direcao: Vector2, familia: String, id_arma: String, nivel_arma: int, nivel_escudo: int, duracao: float = 0.25) -> void:
	pose_atual = pose
	match pose:
		"sacar":
			_sequencia = COLUNAS_SACAR.map(func(coluna): return [coluna, DURACAO_QUADRO_SACAR])
		"guardar":
			var invertida := COLUNAS_SACAR.duplicate()
			invertida.reverse()
			_sequencia = invertida.map(func(coluna): return [coluna, DURACAO_QUADRO_SACAR])
		"aparar":
			_sequencia = [[COLUNA_APARAR, DURACAO_SEGURADA]]
		"esquiva":
			_sequencia = [[COLUNA_ESQUIVA, duracao]]
		"ferido":
			_sequencia = [[COLUNA_FERIDO, duracao]]
		_:
			return
	_familia = familia
	_linha = ArcoJogador.linha_da_direcao(direcao)
	_indice = 0
	_tempo = 0.0
	_carregar_texturas(id_arma, nivel_arma, nivel_escudo)
	visible = true
	_aplicar_quadro()

func virar(direcao: Vector2) -> void:
	if not visible or _sequencia.is_empty():
		return
	var nova := ArcoJogador.linha_da_direcao(direcao)
	if nova != _linha:
		_linha = nova
		_aplicar_quadro()

func encerrar() -> void:
	if not visible:
		return
	_sequencia = []
	visible = false
	terminou.emit()

func _carregar_texturas(_id_arma: String, _nivel_arma: int, _nivel_escudo: int) -> void:
	pass

func _process(delta: float) -> void:
	if not visible or _sequencia.is_empty():
		return
	_sincronizar_aparencia()
	_tempo += delta
	while _tempo >= _sequencia[_indice][1]:
		_tempo -= _sequencia[_indice][1]
		_indice += 1
		if _indice >= _sequencia.size():
			_sequencia = []
			visible = false
			terminou.emit()
			return
	_aplicar_quadro()

func _aplicar_quadro() -> void:
	pass

func _z_da_ordem(chave: String, coluna: int) -> int:
	return Z_FRENTE if ORDEM[chave][_linha][coluna] == "F" else Z_ATRAS

func _sincronizar_aparencia() -> void:
	pass
