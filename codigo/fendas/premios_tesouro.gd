extends RefCounted

const CHANCE_PORTAL := 0.15
const CHANCE_PREMIO_RARO := 0.05
const MULT_OURO_MIMICO := 5
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Drop := preload("res://codigo/logica/equipamento_drop.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")

static func sortear_premio(rng: RandomNumberGenerator, andar: int) -> DadosItem:
	if rng.randf() >= CHANCE_PREMIO_RARO:
		return null
	# Peças reais dos conjuntos existentes, no ápice da evolução disponível na bigorna.
	var conjunto: GDScript = Conjuntos.CONJUNTOS[rng.randi_range(0, Conjuntos.CONJUNTOS.size() - 1)]
	var tipos: Array = conjunto.TIPOS.keys()
	var tipo: String = tipos[rng.randi_range(0, tipos.size() - 1)]
	var item := Drop.criar_item(rng, andar, false, true, "lendario", tipo)
	item.nivel = Conjuntos.NIVEL_ASCENSAO
	item.raridade = "lendario"
	item.afixos = Raridades.sortear_afixos(rng, item.categoria, "lendario")
	return item
