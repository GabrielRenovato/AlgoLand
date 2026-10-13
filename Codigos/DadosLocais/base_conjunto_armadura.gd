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

static func pode_ativar(tipos: Dictionary, equipados: Dictionary, recarga: float, sorteio: float, chance: float) -> bool:
	return mascara(tipos, equipados) == 15 and recarga <= 0.0 and sorteio >= 0.0 and sorteio < chance

static func dados(tipos: Dictionary, bases: Dictionary, tipo: String, nivel: int) -> Dictionary:
	if not tipos.has(tipo):
		return {}
	var base: Dictionary = bases[tipos[tipo]["slot"]]
	var k := clampi(nivel, 1, 5) - 1
	return {"bonus_vitalidade": int(base["vitalidade"][k]), "bonus_defesa": int(base["defesa"][k])}
