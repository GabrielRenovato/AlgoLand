extends RefCounted

## GERADO pelo manifesto do conjunto; regras em base_conjunto_armadura.gd.
const Base := preload("res://Codigos/DadosLocais/base_conjunto_armadura.gd")
const ID := "cavaleiro_rubro"
const NOME := "CAVALEIRO RUBRO"
const RARIDADE := "incomum"
const RAIZ_SPRITES := "res://CharacterSprites/Conjuntos/cavaleiro_rubro/"
const PRECO_BASE := 300
const SUBSTITUIR_CABECA := false
const ONDA_MINIMA := 4
const CHANCE_DROP_NORMAL := 0.35
const CHANCE_DROP_MUTANTE := 0.45
const CHANCE_DROP_CHEFE := 0.45
const TIPO_BONUS := "status"
const PECAS_BONUS := 4
const CHANCE_BONUS := 0.0
const RECARGA_BONUS := 0.0
const MULT_DANO_BONUS := 0.0
const AVISO_BONUS := 0.0
const BONUS_DEFESA := 0.1
const BONUS_VITALIDADE := 0.1
const TIPOS := {
	"elmo_cavaleiro_rubro": {
		"slot": "cabeca",
		"peca": "elmo",
		"bit": 1,
		"nome": "ELMO DO CAVALEIRO RUBRO"
	},
	"peitoral_cavaleiro_rubro": {
		"slot": "corpo",
		"peca": "peitoral",
		"bit": 2,
		"nome": "PEITORAL DO CAVALEIRO RUBRO"
	},
	"luvas_cavaleiro_rubro": {
		"slot": "luvas",
		"peca": "luvas",
		"bit": 4,
		"nome": "LUVAS DO CAVALEIRO RUBRO"
	},
	"botas_cavaleiro_rubro": {
		"slot": "botas",
		"peca": "botas",
		"bit": 8,
		"nome": "BOTAS DO CAVALEIRO RUBRO"
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
