extends Node2D
## Tempos e sinais da ação; o visual é desenhado exclusivamente por HeroiRaven.


signal impacto(acao: String)
signal terminou(acao: String)

const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")

const QUADROS_POR_LINHA := 8
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FERRAMENTA := 6

const ACOES := {
	"enxada": {"ferramenta": "fazenda", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"machado": {"ferramenta": "machado", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"picareta": {"ferramenta": "picareta", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"plantar": {"ferramenta": "fazenda", "linha_base": 0, "quadro_impacto": 1,
		"quadros": [[4, 0.30], [5, 0.10], [6, 0.10], [7, 0.10]]},
	"regar": {"ferramenta": "fazenda", "linha_base": 4, "quadro_impacto": 2,
		"quadros": [[0, 0.09], [1, 0.09], [2, 0.12], [3, 0.12], [2, 0.12], [3, 0.16]]},
	# Encher no lago usa a folha do regador, mas só no quadro de segurar a lata: sem o jato que despeja água fora
	"encher": {"ferramenta": "fazenda", "linha_base": 4, "quadro_impacto": 2, "folha": "regar",
		"quadros": [[0, 0.22], [0, 0.20], [0, 0.16]]},
	"colher": {"ferramenta": "fazenda", "linha_base": 4, "quadro_impacto": 2,
		"quadros": [[4, 0.29], [5, 0.17], [6, 0.13], [7, 0.21]]},
}

var jogador = null
var acao_atual := ""
## Nome da folha de sprites da ação em curso (encher usa a do regador)
var folha_atual := ""

var _quadros: Array = []
var _indice := 0
var _tempo := 0.0
var _linha := 0
var _impacto_emitido := false
var _cabelo_aplicado := -1
var _roupa_aplicada := -1
var _pecas_aplicadas := -1
var _raizes_aplicadas: Dictionary = {}

var _corpo: Sprite2D
var _roupa: Sprite2D
var _cabelo: Sprite2D
var _ferramenta: Sprite2D

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

func esta_tocando() -> bool:
	return acao_atual != ""

func tocar(acao: String, direcao: Vector2) -> bool:
	if not ACOES.has(acao):
		return false
	var dados: Dictionary = ACOES[acao]
	acao_atual = acao
	folha_atual = str(dados.get("folha", acao))
	_quadros = dados["quadros"]
	_linha = int(dados["linha_base"]) + ArcoJogador.linha_da_direcao(direcao)
	_indice = 0
	_tempo = 0.0
	_impacto_emitido = false
	visible = true
	_aplicar_quadro()
	return true

func parar() -> void:
	acao_atual = ""
	_quadros = []
	visible = false

func _process(delta: float) -> void:
	if acao_atual == "":
		return
	_sincronizar_aparencia()
	_tempo += delta
	while not _quadros.is_empty() and _tempo >= _quadros[_indice][1]:
		_tempo -= _quadros[_indice][1]
		_indice += 1
		if _indice >= _quadros.size():
			var acao := acao_atual
			parar()
			terminou.emit(acao)
			return
		_aplicar_quadro()

func _aplicar_quadro() -> void:
	# O impacto pertence à ação, mesmo quando o Raven desenha a ferramenta.
	if not _impacto_emitido and _indice == int(ACOES[acao_atual]["quadro_impacto"]):
		_impacto_emitido = true
		impacto.emit(acao_atual)

func _sincronizar_aparencia() -> void:
	pass
