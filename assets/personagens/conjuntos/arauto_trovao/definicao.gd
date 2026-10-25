extends RefCounted

## GERADO pelo manifesto do conjunto; regras em base_conjunto_armadura.gd.
const Base := preload("res://codigo/dados/base_conjunto_armadura.gd")
const ID := "arauto_trovao"
const NOME := "ARAUTO DO TROVAO"
const RARIDADE := "epico"
const RAIZ_SPRITES := "res://assets/personagens/conjuntos/arauto_trovao/"
const PRECO_BASE := 1100
const SUBSTITUIR_CABECA := false
const MODO_VISUAL := "armadura"
const ONDA_MINIMA := 31
const CHANCE_DROP_NORMAL := 0.0
const CHANCE_DROP_MUTANTE := 0.0
const CHANCE_DROP_CHEFE := 0.04
const TIPO_BONUS := "raio"
const PECAS_BONUS := 4
const DURACAO_BONUS := 0.0
const CHANCE_BONUS := 0.1
const RECARGA_BONUS := 3.0
const MULT_DANO_BONUS := 2.2
const AVISO_BONUS := 0.12
const BONUS_DEFESA := 0.0
const BONUS_VITALIDADE := 0.0
const TIPOS := {
	"elmo_arauto_trovao": {
		"slot": "cabeca",
		"peca": "elmo",
		"bit": 1,
		"nome": "ELMO DO ARAUTO DO TROVAO"
	},
	"peitoral_arauto_trovao": {
		"slot": "corpo",
		"peca": "peitoral",
		"bit": 2,
		"nome": "PEITORAL DO ARAUTO DO TROVAO"
	},
	"luvas_arauto_trovao": {
		"slot": "luvas",
		"peca": "luvas",
		"bit": 4,
		"nome": "LUVAS DO ARAUTO DO TROVAO"
	},
	"botas_arauto_trovao": {
		"slot": "botas",
		"peca": "botas",
		"bit": 8,
		"nome": "BOTAS DO ARAUTO DO TROVAO"
	}
}
const BASES := {
	"cabeca": {
		"vitalidade": [
			2.0,
			3.0,
			4.0,
			6.0,
			8.0
		],
		"defesa": [
			2.0,
			4.0,
			8.0,
			11.0,
			15.0
		]
	},
	"corpo": {
		"vitalidade": [
			3.0,
			4.0,
			7.0,
			10.0,
			14.0
		],
		"defesa": [
			3.0,
			7.0,
			11.0,
			16.0,
			22.0
		]
	},
	"luvas": {
		"vitalidade": [
			1.0,
			2.0,
			3.0,
			4.0,
			5.0
		],
		"defesa": [
			1.0,
			2.0,
			4.0,
			7.0,
			10.0
		]
	},
	"botas": {
		"vitalidade": [
			1.0,
			2.0,
			3.0,
			4.0,
			5.0
		],
		"defesa": [
			1.0,
			2.0,
			4.0,
			7.0,
			10.0
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
