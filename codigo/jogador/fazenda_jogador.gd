extends Node2D

# Ações de fazenda da "página 2" da base Mana Seed (char_a_p2): enxada/machado/picareta, plantar, regar e colher.
# Desenha o personagem inteiro (corpo, roupa, cabelo e ferramenta) enquanto a ação dura; depois some (visible = false).
# A folha tem 8x8 quadros de 64 px em 4 blocos de 4x4:
#   linhas 0-3 / colunas 0-3: golpe (enxada, machado ou picareta, conforme a folha da ferramenta)
#   linhas 0-3 / colunas 4-7: plantar (jogar sementes)
#   linhas 4-7 / colunas 0-3: regar
#   linhas 4-7 / colunas 4-7: colher (arrancar e levantar)
# Dentro de cada bloco as linhas são as direções: baixo, cima, direita, esquerda (mesma ordem das outras páginas).

signal impacto(acao: String)
signal terminou(acao: String)

const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")

const RAIZ := "res://assets/personagens/Fazenda/"
const QUADROS_POR_LINHA := 8
const Madeira := preload("res://codigo/dados/ferramentas_madeira.gd")
const ObjetosRefinados := preload("res://codigo/dados/objetos_refinados.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
# Camadas relativas ao corpo (z = 3 em BaseSprites); a ferramenta (6tla) fica sempre por cima: o artista só
# desenha os pixels dela que aparecem
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FERRAMENTA := 6

# linha_base: 0 ou 4 (bloco de cima ou de baixo). quadros: [coluna, duração]. quadro_impacto: índice em
# "quadros" em que a ferramenta acerta o chão / a semente cai / a água sai / a planta sai da terra
const ACOES := {
	"enxada": {"ferramenta": "fazenda", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"machado": {"ferramenta": "machado", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"picareta": {"ferramenta": "picareta", "linha_base": 0, "quadro_impacto": 2,
		"quadros": [[0, 0.22], [1, 0.08], [2, 0.12], [3, 0.26]]},
	"plantar": {"ferramenta": "fazenda", "linha_base": 0, "quadro_impacto": 1,
		"quadros": [[4, 0.12], [5, 0.18], [6, 0.14], [7, 0.24]]},
	"regar": {"ferramenta": "fazenda", "linha_base": 4, "quadro_impacto": 2,
		"quadros": [[0, 0.16], [1, 0.16], [2, 0.22], [3, 0.22], [2, 0.22], [3, 0.26]]},
	"colher": {"ferramenta": "fazenda", "linha_base": 4, "quadro_impacto": 2,
		"quadros": [[4, 0.18], [5, 0.22], [6, 0.16], [7, 0.34]]},
}

var jogador = null
var acao_atual := ""

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
	_corpo = _criar_camada(Z_CORPO)
	_roupa = _criar_camada(Z_ROUPA)
	_cabelo = _criar_camada(Z_CABELO)
	_ferramenta = _criar_camada(Z_FERRAMENTA)
	_corpo.texture = load(RAIZ + "corpo.png")
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

## Começa a ação virada para `direcao`. Retorna false se a ação não existir
func tocar(acao: String, direcao: Vector2) -> bool:
	if not ACOES.has(acao):
		return false
	var dados: Dictionary = ACOES[acao]
	acao_atual = acao
	_quadros = dados["quadros"]
	_linha = int(dados["linha_base"]) + ArcoJogador.linha_da_direcao(direcao)
	_indice = 0
	_tempo = 0.0
	_impacto_emitido = false
	ObjetosRefinados.aplicar(_ferramenta, load(RAIZ + "ferramenta_%s.png" % dados["ferramenta"]))
	var melhorias := preload("res://codigo/dados/melhorias_ferramentas.gd")
	var grau: int=melhorias.nivel(EventosJogo.inventario_de(jogador),melhorias.POR_ACAO.get(acao,""))
	_ferramenta.material = Madeira.material(2.0,grau) if acao in ["enxada","machado","picareta","regar"] else null
	_sincronizar_aparencia()
	visible = true
	_aplicar_quadro()
	return true

## Interrompe a ação sem emitir "terminou" (morte, dano, troca de cena)
func parar() -> void:
	acao_atual = ""
	_quadros = []
	visible = false

func _process(delta: float) -> void:
	if acao_atual == "":
		return
	_sincronizar_aparencia()
	_tempo += delta
	while _tempo >= _quadros[_indice][1]:
		_tempo -= _quadros[_indice][1]
		_indice += 1
		if _indice >= _quadros.size():
			var acao := acao_atual
			parar()
			terminou.emit(acao)
			return
		_aplicar_quadro()

func _aplicar_quadro() -> void:
	var quadro := _linha * QUADROS_POR_LINHA + int(_quadros[_indice][0])
	for camada in [_corpo, _roupa, _cabelo, _ferramenta]:
		camada.frame = quadro
	if not _impacto_emitido and _indice >= int(ACOES[acao_atual]["quadro_impacto"]):
		_impacto_emitido = true
		impacto.emit(acao_atual)

# Cabelo e roupa escolhidos na criação do personagem (lista em codigo/dados/aparencia.gd)
func _sincronizar_aparencia() -> void:
	if jogador == null:
		return
	var cabelo: int = Aparencia.indice_cabelo(jogador.cabelo_atual)
	var roupa: int = Aparencia.indice_roupa(jogador.roupa_atual)
	var pecas: int = jogador.pecas_cavaleiro
	var raizes_lidas = jogador.get("raizes_armadura")
	var raizes: Dictionary = raizes_lidas if raizes_lidas is Dictionary else {}
	Aparencia.aplicar_corpo(_corpo, "fazenda", roupa, pecas, raizes)
	if cabelo != _cabelo_aplicado or roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_cabelo(_cabelo, cabelo, "fazenda", roupa, pecas, raizes)
		_cabelo_aplicado = cabelo
	if roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_roupa(_roupa, roupa, "fazenda", pecas, raizes)
		_roupa_aplicada = roupa
	_pecas_aplicadas = pecas
	_raizes_aplicadas = raizes.duplicate()
	_cabelo.modulate = jogador.cor_cabelo
	Aparencia.aplicar_cartola(_cabelo, _roupa, "fazenda", roupa, pecas, raizes)
