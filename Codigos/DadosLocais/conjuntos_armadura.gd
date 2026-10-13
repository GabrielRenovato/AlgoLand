extends RefCounted

## Cadastro único das peças reais. A prévia do F3 não participa destes bônus.
const CONJUNTOS := [
	preload("res://Codigos/DadosLocais/conjunto_carrasco.gd"),
	preload("res://CharacterSprites/Conjuntos/cavaleiro_rubro/definicao.gd"),
	preload("res://CharacterSprites/Conjuntos/cavalheiro/definicao.gd"),
]

static func de_tipo(tipo: String) -> GDScript:
	for conjunto in CONJUNTOS:
		if conjunto.TIPOS.has(tipo):
			return conjunto
	return null

static func raizes(equipados: Dictionary) -> Dictionary:
	var resultado := {}
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		var item = equipados.get(slot)
		if item == null or item.categoria != slot:
			continue
		var conjunto := de_tipo(item.tipo)
		if conjunto != null and conjunto.TIPOS[item.tipo]["slot"] == slot:
			resultado[conjunto.TIPOS[item.tipo]["peca"]] = conjunto.RAIZ_SPRITES
	return resultado

static func mascara(equipados: Dictionary) -> int:
	var bits := 0
	for conjunto in CONJUNTOS:
		bits |= conjunto.mascara(equipados)
	return bits

## Intervalos exclusivos: cada conjunto conserva a chance de vir no drop.
static func sortear(rng: RandomNumberGenerator, onda: int, mutante: bool, chefe: bool) -> String:
	var valor := rng.randf()
	var acumulado := 0.0
	for conjunto in CONJUNTOS:
		acumulado += conjunto.chance_drop(onda, mutante, chefe)
		if valor < acumulado:
			var tipos: Array = conjunto.TIPOS.keys()
			return tipos[rng.randi_range(0, tipos.size() - 1)]
	return ""

static func bonus_status(equipados: Dictionary) -> Dictionary:
	var resultado := {"defesa": 0.0, "vitalidade": 0.0}
	for conjunto in CONJUNTOS:
		if conjunto.TIPO_BONUS != "status" or conjunto.mascara(equipados) != 15:
			continue
		var constantes: Dictionary = conjunto.get_script_constant_map()
		for atributo in resultado:
			resultado[atributo] += float(constantes.get("BONUS_" + atributo.to_upper(), 0.0))
	return resultado
