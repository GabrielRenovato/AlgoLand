extends RefCounted

## GERADO pelo manifesto do conjunto; regras em base_conjunto_armadura.gd.
const Base := preload("res://codigo/dados/base_conjunto_armadura.gd")
const ID := "carrasco"
const NOME := "CARRASCO"
const RARIDADE := "comum"
const RAIZ_SPRITES := "res://assets/personagens/conjuntos/carrasco/"
const PRECO_BASE := 900
const SUBSTITUIR_CABECA := false
const MODO_VISUAL := "armadura"
const ONDA_MINIMA := 1
const CHANCE_DROP_NORMAL := 0.05
const CHANCE_DROP_MUTANTE := 0.1
const CHANCE_DROP_CHEFE := 0.1
const TIPO_BONUS := "raio"
const PECAS_BONUS := 4
const DURACAO_BONUS := 0.0
const CHANCE_BONUS := 0.1
const RECARGA_BONUS := 2.0
const MULT_DANO_BONUS := 2.0
const AVISO_BONUS := 0.12
const BONUS_DEFESA := 0.0
const BONUS_VITALIDADE := 0.0
const TIPOS := {
	"elmo_carrasco": {
		"slot": "cabeca",
		"peca": "elmo",
		"bit": 1,
		"nome": "ELMO DO CARRASCO"
	},
	"peitoral_carrasco": {
		"slot": "corpo",
		"peca": "peitoral",
		"bit": 2,
		"nome": "PEITORAL DO CARRASCO"
	},
	"luvas_carrasco": {
		"slot": "luvas",
		"peca": "luvas",
		"bit": 4,
		"nome": "LUVAS DO CARRASCO"
	},
	"botas_carrasco": {
		"slot": "botas",
		"peca": "botas",
		"bit": 8,
		"nome": "BOTAS DO CARRASCO"
	}
}
const BASES := {
	"cabeca": {
		"vitalidade": [
			2.0,
			3.0,
			5.0,
			7.0,
			9.0
		],
		"defesa": [
			2.0,
			4.0,
			7.0,
			10.0,
			14.0
		]
	},
	"corpo": {
		"vitalidade": [
			3.0,
			5.0,
			8.0,
			11.0,
			15.0
		],
		"defesa": [
			3.0,
			6.0,
			10.0,
			15.0,
			20.0
		]
	},
	"luvas": {
		"vitalidade": [
			1.0,
			2.0,
			3.0,
			4.0,
			6.0
		],
		"defesa": [
			1.0,
			2.0,
			4.0,
			6.0,
			9.0
		]
	},
	"botas": {
		"vitalidade": [
			1.0,
			2.0,
			3.0,
			4.0,
			6.0
		],
		"defesa": [
			1.0,
			2.0,
			4.0,
			6.0,
			9.0
		]
	}
}

static func chance_drop(onda: int, mutante: bool, chefe: bool) -> float:
	return Base.chance_drop(onda, ONDA_MINIMA, {"normal": CHANCE_DROP_NORMAL, "mutante": CHANCE_DROP_MUTANTE, "chefe": CHANCE_DROP_CHEFE}, mutante, chefe)

static func mascara(equipados: Dictionary) -> int:
	return Base.mascara(TIPOS, equipados)

static func quantidade(equipados: Dictionary) -> int:
	return Base.quantidade(TIPOS, equipados)

static func pode_ativar(equipados: Dictionary, recarga: float, sorteio: float) -> bool:
	return Base.pode_ativar(TIPOS, equipados, recarga, sorteio, CHANCE_BONUS)

static func dados(tipo: String, nivel: int) -> Dictionary:
	return Base.dados(TIPOS, BASES, tipo, nivel)
