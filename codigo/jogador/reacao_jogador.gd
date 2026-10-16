extends Node2D

# Poses curtas da "página 1" dos pacotes de combate (pONE1, pPOL1 e pBOW1): sacar/guardar a arma,
# esquiva, ferido e aparar (guarda). Fica por cima das outras camadas só enquanto a pose dura (visible = false depois);
# "aparar" dura até encerrar() (o jogador segura o botão).
# Cada folha tem 8x8 quadros; linhas 0-3 = baixo, cima, direita, esquerda.

signal terminou

const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")

const RAIZ := "res://assets/personagens/Reacao/"
const QUADROS_POR_LINHA := 8
const COLUNAS_SACAR: Array[int] = [0, 1, 2]
const COLUNA_APARAR := 3
const COLUNA_ESQUIVA := 4
const COLUNA_FERIDO := 5
const DURACAO_QUADRO_SACAR := 0.08
const ObjetosRefinados := preload("res://codigo/dados/objetos_refinados.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const CODIGOS_UM_MAO := {"espada_basica": "sw01", "espada_gemea": "sw02", "machado": "ax01", "maca": "mc01"}
const CODIGOS_ARCO := {"arco_curvo": "bo01", "arco_curto": "bo02", "arco_longo": "bo03"}
# Camadas relativas ao corpo (z = 3 em BaseSprites)
const Z_ATRAS := 2
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FRENTE := 6
# F = na frente do corpo, B = atrás, por coluna de cada linha (guias "layer order, page 1" dos pacotes)
const ORDEM := {
	"espada": ["BFBFFFBB", "FBBBBBBB", "BFFBFFBB", "BFFBFFBB"],
	"escudo": ["BFBBFBBB", "FBFFBFBB", "BBBFFBBB", "BBBFFBBB"],
	"lanca": ["BFFFFFFF", "FBBBBBBB", "BFFBFFFF", "BFFBFFFF"],
	"arco": ["BFFFFBBB", "FBBBBBFB", "BBFBFBBB", "BBFBFBBB"],
	"aljava": ["BBBBBBBB", "FFFFFFFF", "BBBBBBBB", "BBBBBBBB"],
}

var jogador = null

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
	_corpo = _criar_camada(Z_CORPO)
	_roupa = _criar_camada(Z_ROUPA)
	_cabelo = _criar_camada(Z_CABELO)
	_arma = _criar_camada(Z_FRENTE)
	_escudo = _criar_camada(Z_FRENTE)
	_aljava = _criar_camada(Z_ATRAS)
	visible = false

func _criar_camada(z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = QUADROS_POR_LINHA
	sprite.vframes = QUADROS_POR_LINHA
	sprite.z_index = z
	add_child(sprite)
	return sprite

# Duração de quem fica até encerrar() (aparar): longa o bastante para nunca acabar sozinha
const DURACAO_SEGURADA := 3600.0

# familia: "um_mao", "lanca" ou "arco". duracao só vale para "esquiva" e "ferido".
func tocar(pose: String, direcao: Vector2, familia: String, id_arma: String, nivel_arma: int, nivel_escudo: int, duracao: float = 0.25) -> void:
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

## Vira a pose em andamento para outra direção (a guarda gira com o jogador)
func virar(direcao: Vector2) -> void:
	if not visible or _sequencia.is_empty():
		return
	var nova := ArcoJogador.linha_da_direcao(direcao)
	if nova != _linha:
		_linha = nova
		_aplicar_quadro()

## Acaba a pose na hora (soltar a guarda)
func encerrar() -> void:
	if not visible:
		return
	_sequencia = []
	visible = false
	terminou.emit()

func _carregar_texturas(id_arma: String, nivel_arma: int, nivel_escudo: int) -> void:
	var pasta := RAIZ + _familia + "/"
	var nivel := clampi(nivel_arma, 1, 5)
	_corpo.texture = load(pasta + "corpo.png")
	_cabelo_aplicado = -1
	_roupa_aplicada = -1
	_sincronizar_aparencia()
	_escudo.visible = false
	_aljava.visible = false
	match _familia:
		"um_mao":
			ObjetosRefinados.aplicar(_arma, load(pasta + "arma_%s_%d.png" % [CODIGOS_UM_MAO.get(id_arma, "sw01"), nivel]))
			if nivel_escudo > 0:
				ObjetosRefinados.aplicar(_escudo, load(pasta + "escudo_%d.png" % clampi(nivel_escudo, 1, 5)))
				_escudo.visible = true
		"lanca":
			ObjetosRefinados.aplicar(_arma, load(pasta + "arma_%d.png" % nivel))
		"arco":
			ObjetosRefinados.aplicar(_arma, load(pasta + "arma_%s_%d.png" % [CODIGOS_ARCO.get(id_arma, "bo01"), nivel]))
			ObjetosRefinados.aplicar(_aljava, load(pasta + "aljava.png"))
			_aljava.visible = true

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
	var coluna: int = _sequencia[_indice][0]
	var quadro := _linha * QUADROS_POR_LINHA + coluna
	for camada in [_corpo, _roupa, _cabelo, _arma, _escudo, _aljava]:
		camada.frame = quadro
	var chave_arma := "espada" if _familia == "um_mao" else _familia
	_arma.z_index = _z_da_ordem(chave_arma, coluna)
	_escudo.z_index = _z_da_ordem("escudo", coluna)
	_aljava.z_index = _z_da_ordem("aljava", coluna)

func _z_da_ordem(chave: String, coluna: int) -> int:
	return Z_FRENTE if ORDEM[chave][_linha][coluna] == "F" else Z_ATRAS

# Cabelo e roupa escolhidos na criação do personagem, na folha da família da arma (um_mao, lanca ou arco)
func _sincronizar_aparencia() -> void:
	if jogador == null:
		return
	var pagina := "reacao_" + _familia
	var cabelo: int = Aparencia.indice_cabelo(jogador.cabelo_atual)
	var roupa: int = Aparencia.indice_roupa(jogador.roupa_atual)
	var pecas: int = jogador.pecas_cavaleiro
	var raizes_lidas = jogador.get("raizes_armadura")
	var raizes: Dictionary = raizes_lidas if raizes_lidas is Dictionary else {}
	Aparencia.aplicar_corpo(_corpo, pagina, roupa, pecas, raizes)
	if cabelo != _cabelo_aplicado or roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_cabelo(_cabelo, cabelo, pagina, roupa, pecas, raizes)
		_cabelo_aplicado = cabelo
	if roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_roupa(_roupa, roupa, pagina, pecas, raizes)
		_roupa_aplicada = roupa
	_pecas_aplicadas = pecas
	_raizes_aplicadas = raizes.duplicate()
	_cabelo.modulate = jogador.cor_cabelo
	Aparencia.aplicar_cartola(_cabelo, _roupa, pagina, roupa, pecas, raizes)
