extends RefCounted

const Raridades := preload("res://codigo/dados/raridades.gd")
## Nível em que a peça de conjunto para de subir de nível e passa a subir de raridade na bigorna
const NIVEL_ASCENSAO := 5

## Cadastro único das peças reais. A prévia do F3 não participa destes bônus.
const GUARDA_NOVATO := preload("res://assets/personagens/conjuntos/guarda_novato/definicao.gd")
const CONJUNTOS := [
	preload("res://codigo/dados/conjunto_carrasco.gd"),
	preload("res://assets/personagens/conjuntos/cavaleiro_rubro/definicao.gd"),
	preload("res://assets/personagens/conjuntos/cavalheiro/definicao.gd"),
	preload("res://assets/personagens/conjuntos/sentinela/definicao.gd"),
	preload("res://assets/personagens/conjuntos/batedor/definicao.gd"),
	preload("res://assets/personagens/conjuntos/guardiao_geada/definicao.gd"),
	preload("res://assets/personagens/conjuntos/templario_solar/definicao.gd"),
	preload("res://assets/personagens/conjuntos/arauto_trovao/definicao.gd"),
	preload("res://assets/personagens/conjuntos/guardiao_esmeralda/definicao.gd"),
	preload("res://assets/personagens/conjuntos/soberano_astral/definicao.gd"),
]

static func de_tipo(tipo: String) -> GDScript:
	if GUARDA_NOVATO.TIPOS.has(tipo):return GUARDA_NOVATO
	for conjunto in CONJUNTOS:
		if conjunto.TIPOS.has(tipo):
			return conjunto
	return null

## Peça de conjunto no nível máximo e ainda abaixo de lendária: a bigorna sobe a raridade em vez do nível
static func pode_ascender(item) -> bool:
	return item != null and de_tipo(item.tipo) != null and item.nivel >= NIVEL_ASCENSAO \
			and Raridades.indice(item.raridade) < Raridades.ORDEM.size() - 1

## Sobe um degrau de raridade (comum > incomum > raro > épico > lendário) e soma um bônus aleatório que a peça ainda não tem.
## O multiplicador da raridade também passa a valer sobre vitalidade e defesa da peça (Raridades.escalar)
static func ascender(item, rng: RandomNumberGenerator) -> bool:
	if not pode_ascender(item):
		return false
	item.raridade = Raridades.ORDEM[Raridades.indice(item.raridade) + 1]
	var extra := Raridades.sortear_afixo_extra(rng, item.afixos, item.raridade)
	for id in extra:
		item.afixos[id] = extra[id]
	return true

## Arma ou escudo no nível máximo: a bigorna também sobe a raridade, com um bônus que a categoria aceita.
## Quem chama confere o nível e se o tipo é de equipamento
static func ascender_equipamento(item, rng: RandomNumberGenerator) -> bool:
	if item == null or Raridades.indice(item.raridade) >= Raridades.ORDEM.size() - 1:
		return false
	item.raridade = Raridades.ORDEM[Raridades.indice(item.raridade) + 1]
	var extra := Raridades.sortear_afixo_extra(rng, item.afixos, item.raridade, item.categoria)
	for id in extra:
		item.afixos[id] = extra[id]
	return true

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
	var bits := GUARDA_NOVATO.mascara(equipados)
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

## Fator do efeito do conjunto (peças x nível), 0 se o bônus não vale
static func fator(conjunto: GDScript, equipados: Dictionary) -> float:
	return conjunto.Base.fator(conjunto.TIPOS, equipados)

static func fator_nivel(conjunto: GDScript, equipados: Dictionary) -> float:
	return conjunto.Base.fator_nivel(conjunto.TIPOS, equipados) if conjunto.quantidade(equipados) >= conjunto.Base.PECAS_PARCIAL else 0.0

static func bonus_status(equipados: Dictionary) -> Dictionary:
	var resultado := {"defesa": 0.0, "vitalidade": 0.0}
	for conjunto in CONJUNTOS:
		if conjunto.TIPO_BONUS != "status":
			continue
		var multiplicador := fator(conjunto, equipados)
		if multiplicador <= 0.0:
			continue
		var constantes: Dictionary = conjunto.get_script_constant_map()
		for atributo in resultado:
			resultado[atributo] += float(constantes.get("BONUS_" + atributo.to_upper(), 0.0)) * multiplicador
	return resultado

## Os IDs elementais antigos conservam o valor como propriedades físicas do conjunto.
static func bonus_fisico(equipados: Dictionary) -> Dictionary:
	var resultado := {"empurrao":0.0,"guarda":0.0,"esquiva":0.0}
	for conjunto in CONJUNTOS + [GUARDA_NOVATO]:
		if conjunto.ID=="guarda_novato":
			var n:int=conjunto.quantidade(equipados)
			if n>=2:resultado.guarda+=0.05
			if n==4:resultado.esquiva+=0.05
		var escala := fator(conjunto,equipados) * fator_nivel(conjunto,equipados)
		if conjunto.TIPO_BONUS == "raio": resultado.empurrao += 0.15 * escala
		elif conjunto.TIPO_BONUS == "congelamento": resultado.guarda += 0.08 * escala
	resultado.empurrao = minf(0.50,resultado.empurrao)
	resultado.guarda = minf(0.30,resultado.guarda)
	return resultado
