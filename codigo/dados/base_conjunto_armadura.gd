extends RefCounted

## Regras comuns. Uma definição de conjunto só precisa fornecer os dados.
static func chance_drop(onda: int, minima: int, chances: Dictionary, mutante: bool, chefe: bool) -> float:
	if onda < minima:
		return 0.0
	return float(chances["chefe"] if chefe else (chances["mutante"] if mutante else chances["normal"]))

static func mascara(tipos: Dictionary, equipados: Dictionary) -> int:
	var resultado := 0
	for tipo in tipos:
		var item = equipados.get(tipos[tipo]["slot"])
		if item != null and item.tipo == tipo and item.categoria == tipos[tipo]["slot"]:
			resultado |= int(tipos[tipo]["bit"])
	return resultado

static func quantidade(tipos: Dictionary, equipados: Dictionary) -> int:
	var bits := mascara(tipos, equipados)
	var total := 0
	for bit in [1, 2, 4, 8]:
		if (bits & bit) != 0:
			total += 1
	return total

## Bônus por quantidade de peças do mesmo conjunto: 2 ou 3 peças dão metade do efeito, 4 peças o efeito completo
const PECAS_PARCIAL := 2
const PECAS_COMPLETO := 4
const FRACAO_PARCIAL := 0.5
## Cada nível acima do 1 soma isto ao efeito (nível 5 = 2x)
const GANHO_POR_NIVEL := 0.25

## Fração do efeito pela quantidade de peças (0, FRACAO_PARCIAL ou 1)
static func fator_pecas(tipos: Dictionary, equipados: Dictionary) -> float:
	var total := quantidade(tipos, equipados)
	if total >= PECAS_COMPLETO:
		return 1.0
	return FRACAO_PARCIAL if total >= PECAS_PARCIAL else 0.0

## Nível do conjunto: o da peça equipada mais fraca dele (0 sem peças)
static func nivel_conjunto(tipos: Dictionary, equipados: Dictionary) -> int:
	var menor := 0
	for tipo in tipos:
		var item = equipados.get(tipos[tipo]["slot"])
		if item != null and item.tipo == tipo and item.categoria == tipos[tipo]["slot"]:
			menor = clampi(item.nivel, 1, 5) if menor == 0 else mini(menor, clampi(item.nivel, 1, 5))
	return menor

static func fator_nivel(tipos: Dictionary, equipados: Dictionary) -> float:
	var nivel := nivel_conjunto(tipos, equipados)
	return 1.0 + GANHO_POR_NIVEL * (nivel - 1) if nivel > 0 else 0.0

## Fator total do efeito: peças x nível (0 quando o bônus não vale)
static func fator(tipos: Dictionary, equipados: Dictionary) -> float:
	return fator_pecas(tipos, equipados) * fator_nivel(tipos, equipados)

static func pode_ativar(tipos: Dictionary, equipados: Dictionary, recarga: float, sorteio: float, chance: float) -> bool:
	var efetiva := minf(chance * fator(tipos, equipados), 1.0)
	return efetiva > 0.0 and recarga <= 0.0 and sorteio >= 0.0 and sorteio < efetiva

static func dados(tipos: Dictionary, bases: Dictionary, tipo: String, nivel: int) -> Dictionary:
	if not tipos.has(tipo):
		return {}
	var base: Dictionary = bases[tipos[tipo]["slot"]]
	var k := clampi(nivel, 1, 5) - 1
	return {"bonus_vitalidade": int(base["vitalidade"][k]), "bonus_defesa": int(base["defesa"][k])}
