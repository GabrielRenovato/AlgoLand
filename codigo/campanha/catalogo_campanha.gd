extends RefCounted

## Catálogo do protótipo; não substitui os andares atuais nem instala uma temporada.
const Manifesto := preload("res://codigo/campanha/primeiro_andar.json")
const ID := "campanha_primeira_raiz_v1"
const FORMATO := 1
# Limite atual da campanha: estágios 1 a 4 (chegada, estrada, vila, Bacia do Moinho). O pomar e o conteúdo
# posterior ficam preservados, fora do beta.
const REGIOES_HABILITADAS := ["chegada", "estrada", "vila", "moinho"]

static func dados() -> Dictionary:
	return Manifesto.data.duplicate(true)

static func _lista_ids(valor: Variant, conhecidos: Dictionary) -> bool:
	if not valor is Array:
		return false
	var vistos := {}
	for id in valor:
		if not id is String or not conhecidos.has(id) or vistos.has(id):
			return false
		vistos[id] = true
	return true

static func validar(catalogo: Dictionary) -> bool:
	if catalogo.get("formato") != FORMATO or catalogo.get("id") != ID:
		return false
	var versao: Variant = catalogo.get("versao_conteudo")
	if not (versao is int or versao is float) or versao != int(versao) or versao < 1:
		return false
	for campo in ["destinos", "missoes", "reliquias"]:
		if not catalogo.get(campo) is Dictionary or catalogo[campo].is_empty():
			return false
	var destinos: Dictionary = catalogo.destinos
	var missoes: Dictionary = catalogo.missoes
	if not destinos.has(catalogo.get("andar_inicial", "")):
		return false
	for id in destinos:
		var destino: Variant = destinos[id]
		if not id is String or not destino is Dictionary:
			return false
		if not destino.get("nome") is String or not destino.get("tipo") in ["andar", "cidade", "exploracao", "dungeon"]:
			return false
		if not _lista_ids(destino.get("requisitos"), missoes):
			return false
		if not destino.get("conteudo") in ["planejado", "jogavel"] or not destino.get("cena") is String:
			return false
		if destino.conteudo == "jogavel" and not ResourceLoader.exists(destino.cena, "PackedScene"):
			return false
		if destino.tipo != "andar":
			if not destinos.has(destino.get("andar", "")) or destinos[destino.andar].tipo != "andar":
				return false
			var duracao: Variant = destino.get("duracao",{})
			if not duracao is Dictionary or not duracao.get("prevista") is Array or duracao.prevista.size()!=2: return false
			for segundos in [duracao.get("minima"),duracao.prevista[0],duracao.prevista[1]]:
				if not (segundos is int or segundos is float) or not is_finite(float(segundos)) or segundos<60 or segundos>3600: return false
			if duracao.prevista[1]<duracao.prevista[0] or duracao.prevista[0]<duracao.minima: return false
			var minimo: Variant = destino.get("grupo_minimo")
			var maximo: Variant = destino.get("grupo_maximo")
			if not (minimo is int or minimo is float) or not (maximo is int or maximo is float):
				return false
			if minimo != int(minimo) or maximo != int(maximo) or minimo < 1 or maximo < minimo or maximo > 4:
				return false
	for id in missoes:
		var missao: Variant = missoes[id]
		if not id is String or not missao is Dictionary:
			return false
		if not missao.get("nome") is String or not destinos.has(missao.get("destino", "")):
			return false
		if not missao.get("opcional") is bool or not _lista_ids(missao.get("requisitos"), missoes):
			return false
		if not _validar_objetivos(missao.get("objetivos", []), destinos):
			return false
	# Ordenação topológica: um ciclo deixa missões sem qualquer caminho de conclusão.
	var resolvidas := {}
	while resolvidas.size() < missoes.size():
		var anterior := resolvidas.size()
		for id in missoes:
			if not resolvidas.has(id) and requisitos_cumpridos(missoes[id].requisitos, resolvidas.keys()):
				resolvidas[id] = true
		if anterior == resolvidas.size():
			return false
	for id in catalogo.reliquias:
		var reliquia: Variant = catalogo.reliquias[id]
		if not id is String or not reliquia is Dictionary:
			return false
		if not reliquia.get("nome") is String or not missoes.has(reliquia.get("obtida_em", "")) or not missoes.has(reliquia.get("ativada_em", "")):
			return false
		if not destinos.has(reliquia.get("destino", "")):
			return false
		if not _depende_de(missoes, reliquia.ativada_em, reliquia.obtida_em):
			return false
		if not reliquia.ativada_em in destinos[reliquia.destino].requisitos:
			return false
	return true

static func _validar_objetivos(objetivos: Variant, destinos: Dictionary) -> bool:
	if not objetivos is Array:
		return false
	var por_id := {}
	for objetivo in objetivos:
		if not objetivo is Dictionary or not objetivo.get("id") is String or objetivo.id.is_empty() or por_id.has(objetivo.id):
			return false
		for campo in ["tipo", "alvo", "texto"]:
			if not objetivo.get(campo) is String or objetivo[campo].is_empty():
				return false
		if not destinos.has(objetivo.get("regiao", "")):
			return false
		por_id[objetivo.id] = objetivo
	var resolvidos := {}
	for objetivo in objetivos:
		if not _lista_ids(objetivo.get("apos"), por_id):
			return false
	while resolvidos.size() < objetivos.size():
		var tamanho := resolvidos.size()
		for objetivo in objetivos:
			if requisitos_cumpridos(objetivo.apos, resolvidos.keys()):
				resolvidos[objetivo.id] = true
		if resolvidos.size() == tamanho:
			return false
	return true

static func requisitos_cumpridos(requisitos: Array, concluidas: Array) -> bool:
	for id in requisitos:
		if not id in concluidas:
			return false
	return true

static func _depende_de(missoes: Dictionary, id: String, anterior: String) -> bool:
	var fila: Array = missoes[id].requisitos.duplicate()
	var vistos := {}
	while not fila.is_empty():
		var atual: String = fila.pop_back()
		if atual == anterior:
			return true
		if not vistos.has(atual):
			vistos[atual] = true
			fila.append_array(missoes[atual].requisitos)
	return false
