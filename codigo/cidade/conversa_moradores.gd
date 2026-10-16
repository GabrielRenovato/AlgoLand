extends RefCounted

## Cérebro das conversas da vila: lê o estado do jogo (vida, ouro, Brasas, horta, mochila, arena, calendário) e escolhe
## o que cada morador diz, com a personalidade de falas_moradores.gd. Lembra o que cada um já disse (Cidade.memoria),
## para variar o papo e nunca repetir a mesma dica seguida, e reage ao que o jogador fez desde a última conversa.

const Falas := preload("res://codigo/cidade/falas_moradores.gd")
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
## Mesmo rodízio de gerenciador_de_ondas.gd CHEFES (onda 10, 20, 30...); aqui só os nomes, sem carregar as cenas
const CHEFES := ["MINOTAURO", "MEDUSA", "GOBLIN MAROMBA", "COGUMELO ANCIAO", "DRAGAO VERMELHO"]
const INTERVALO_CHEFE := 10
## Como os vizinhos contratáveis aparecem nas dicas
const NOME_CONTRATO := {"curandeira": "a DONA ROSA", "bardo": "o CAIO", "mistica": "a ESTELA"}

static var _rng := RandomNumberGenerator.new()

static func falas(id: String) -> Dictionary:
	return Falas.FALAS.get(id, {})

## Nome do chefe que aparece na onda dada (múltipla de 10)
static func chefe_da_onda(onda: int) -> String:
	return CHEFES[(maxi(onda, INTERVALO_CHEFE) / INTERVALO_CHEFE - 1) % CHEFES.size()]

## Estado do jogo que as falas consultam: "marcas" (condições) e campos para os textos
const Refeicoes := preload("res://codigo/dados/refeicoes.gd")

static func contexto(id: String, arvore: SceneTree) -> Dictionary:
	var cena := arvore.current_scene
	var hora: float = cena.hora_atual() if cena != null and cena.has_method("hora_atual") else 12.0
	var estacao := Calendario.estacao()
	var dia := Calendario.dia_na_estacao()
	var restantes := Calendario.DIAS_POR_ESTACAO - dia
	var m := {}
	m["manha"] = hora >= 6.0 and hora < 12.0
	m["tarde"] = hora >= 12.0 and hora < 18.0
	m["noite"] = hora >= 18.0 or hora < 6.0
	for i in 4:
		m[["primavera", "verao", "outono", "inverno"][i]] = estacao == i
	m["fim_estacao"] = restantes <= 2
	m["festa"] = dia == Calendario.DIAS_POR_ESTACAO
	# Jogador
	var jogador: Node = null
	for candidato in arvore.get_nodes_in_group("character"):
		if candidato is CharacterBody2D:
			jogador = candidato
			break
	var vida := 1.0
	if jogador != null and jogador.get("estatisticas") != null and jogador.estatisticas.hp_maximo > 0:
		vida = float(jogador.hp_atual) / float(jogador.estatisticas.hp_maximo)
	m["hp_baixo"] = vida < 0.5
	m["desarmado"] = jogador != null and not (jogador.usando_espada or jogador.usando_lanca or jogador.usando_arco)
	m["mochila_cheia"] = not InventarioJogador.tem_espaco()
	m["ouro_bigorna"] = DadosJogo.moedas >= 200
	m["ouro_muito"] = DadosJogo.moedas >= 500
	# Progresso permanente: melhorias, contratados, chefes, recorde
	var melhoria := ""
	var custo_melhoria := -1
	for chave in Progresso.ORDEM_MELHORIAS:
		var custo := Progresso.custo_proximo(chave)
		if custo != -1 and (custo_melhoria == -1 or custo < custo_melhoria):
			custo_melhoria = custo
			melhoria = Progresso.MELHORIAS[chave]["nome"]
	var contratar := ""
	for chave in Progresso.ORDEM_MORADORES:
		if not Progresso.tem_morador(chave):
			contratar = chave
			break
	m["pode_melhorar"] = custo_melhoria != -1 and Progresso.brasas >= custo_melhoria
	m["pode_contratar"] = contratar != "" and Progresso.brasas >= int(Progresso.MORADORES[contratar]["custo"])
	m["tudo_comprado"] = custo_melhoria == -1 and contratar == ""
	m["rosa_contratada"] = Progresso.tem_morador("curandeira")
	m["caio_contratado"] = Progresso.tem_morador("bardo")
	m["estela_contratada"] = Progresso.tem_morador("mistica")
	m["venceu_chefe"] = Progresso.checkpoint_max > 0
	m["todos_chefes"] = false
	m["ja_lutou"] = Progresso.recorde_onda > 0
	var proxima_linha := InventarioJogador.onda_da_proxima_linha()
	m["perto_linha"] = proxima_linha > 0 and proxima_linha - Progresso.maior_onda_vencida <= 5
	m["tem_pedido_livre"] = Dados.MISSOES.keys().any(func(chave): return not Cidade.missoes.has(chave))
	# Horta e caldeirão
	var maduras := 0
	var murchas := 0
	var plantadas := Fazenda.celulas_com_planta()
	for celula in plantadas:
		if Fazenda.esta_madura(celula):
			maduras += 1
		elif Fazenda.esta_murcha(celula):
			murchas += 1
	m["tem_maduras"] = maduras > 0
	m["tem_murchas"] = murchas > 0
	m["horta_vazia"] = plantadas.is_empty() and estacao != 3
	# Refeições do Caio e venda de colheita para a Lia (ligação fazenda -> arena)
	m["comeu"] = Progresso.refeicao != ""
	m["pode_cozinhar"] = not m["comeu"] and Refeicoes.ORDEM.any(func(prato): return Fazenda.motivo_para_nao_cozinhar(prato) == "")
	var fora := false
	var da_estacao := false
	for planta in Fazenda.ORDEM_PLANTAS:
		if InventarioJogador.quantidade_sementes(planta) > 0:
			if int(Fazenda.PLANTAS[planta]["estacao"]) == estacao:
				da_estacao = true
			else:
				fora = true
	m["sementes_fora_estacao"] = fora
	m["sementes_estacao"] = da_estacao
	m["tem_colheita"] = Fazenda.total_de_itens_colhidos() > 0
	m["tem_pocoes"] = not Fazenda.pocoes_que_tem().is_empty()
	m["tem_pocao_cura"] = Fazenda.quantidade_pocoes("cura") > 0
	var pocao_possivel := ""
	for pocao in Pocoes.ORDEM:
		if Fazenda.motivo_para_nao_fazer(pocao) == "":
			pocao_possivel = Pocoes.POCOES[pocao]["nome"]
			break
	m["pode_pocao"] = pocao_possivel != ""
	var da_estacao_nomes: Array = []
	var rapidas: Array = []
	for planta in Fazenda.plantas_da_estacao(estacao):
		da_estacao_nomes.append(Fazenda.PLANTAS[planta]["nome"])
		if Fazenda.da_tempo_de_crescer(planta):
			rapidas.append(Fazenda.PLANTAS[planta]["nome"])
	# Próximo chefe: a primeira onda múltipla de 10 depois do que o jogador já venceu
	var vencida := maxi(Progresso.checkpoint_max, Progresso.maior_onda_vencida)
	var onda_chefe := (vencida / INTERVALO_CHEFE + 1) * INTERVALO_CHEFE
	m["limite_plantio"] = estacao != 3 and rapidas.size() < da_estacao_nomes.size()
	m["da_tempo_alguma"] = not rapidas.is_empty()
	return {
		"marcas": m,
		"id": id,
		"hora": hora,
		"amizade": int(Cidade.amizade.get(id, 0)),
		"periodo": "Boa noite" if m["noite"] else "Bom dia" if m["manha"] else "Boa tarde",
		"ouro": DadosJogo.moedas,
		"brasas": Progresso.brasas,
		"melhoria": melhoria,
		"custo_melhoria": custo_melhoria,
		"contratar": NOME_CONTRATO.get(contratar, ""),
		"custo_contratar": int(Progresso.MORADORES[contratar]["custo"]) if contratar != "" else 0,
		"onda_chefe": onda_chefe,
		"proximo_chefe": chefe_da_onda(onda_chefe),
		"chefe_vencido": chefe_da_onda(Progresso.checkpoint_max / INTERVALO_CHEFE * INTERVALO_CHEFE),
		"recorde": Progresso.recorde_onda,
		"proxima_linha": proxima_linha,
		"maduras": maduras,
		"dias_restantes": restantes,
		"faltam": "%d dia%s" % [restantes, "" if restantes == 1 else "s"],
		"plantas_estacao": ", ".join(da_estacao_nomes),
		"plantas_rapidas": ", ".join(rapidas) if not rapidas.is_empty() else "nenhuma, melhor esperar a proxima estacao",
		"pocao_possivel": pocao_possivel,
	}

## A fala vale agora? ("se": todas as marcas ligadas; "nao": todas desligadas)
static func vale(fala: Dictionary, ctx: Dictionary) -> bool:
	var marcas: Dictionary = ctx["marcas"]
	for marca in fala.get("se", []):
		if not marcas.get(marca, false):
			return false
	for marca in fala.get("nao", []):
		if marcas.get(marca, false):
			return false
	return true

static func _texto(modelo: String, ctx: Dictionary) -> String:
	return modelo.format(ctx)

## Memória de um morador: o que já disse e o que já sabia do jogador
static func _memoria(id: String) -> Dictionary:
	if not Cidade.memoria.has(id) or not Cidade.memoria[id] is Dictionary:
		Cidade.memoria[id] = {}
	var mem: Dictionary = Cidade.memoria[id]
	for campo in ["vistas", "hoje"]:
		if not mem.get(campo) is Dictionary:
			mem[campo] = {}
	return mem

static func _ouvida(id: String, chave: String) -> int:
	return int(_memoria(id)["vistas"].get(chave, 0))

static func _marcar(id: String, chave: String) -> void:
	var mem := _memoria(id)
	mem["vistas"][chave] = int(mem["vistas"].get(chave, 0)) + 1
	var hoje = mem["hoje"].get(chave)
	var vezes := int(hoje[1]) if hoje is Array and int(hoje[0]) == Calendario.dia else 0
	mem["hoje"][chave] = [Calendario.dia, vezes + 1]
	Cidade.lembrar()

## Quantas vezes a fala foi dita hoje
static func _vezes_hoje(id: String, chave: String) -> int:
	var hoje = _memoria(id)["hoje"].get(chave)
	return int(hoje[1]) if hoje is Array and int(hoje[0]) == Calendario.dia else 0

## Saudação pela amizade (novo, conhecido, amigo) e pela hora
static func saudacao(id: String, ctx: Dictionary) -> String:
	var tabela: Dictionary = falas(id).get("saudacoes", {})
	var grau := "amigo" if ctx["amizade"] >= 7 else "conhecido" if ctx["amizade"] >= 3 else "novo"
	var opcoes: Array = tabela.get(grau, [])
	if opcoes.is_empty():
		return ""
	return _texto(opcoes[_rng.randi() % opcoes.size()], ctx)

## Primeira conversa com o morador: a boas-vindas dele, uma vez só, e já fica gravado que o jogador não é mais novato.
## Saves de antes desta fala já trazem a memória da reação ("chefe"): quem já conversou não recebe as boas-vindas.
static func boas_vindas(id: String, ctx: Dictionary) -> String:
	var mem := _memoria(id)
	if mem.get("conhecido", false) or mem.has("chefe"):
		return ""
	mem["conhecido"] = true
	Cidade.lembrar()
	return _texto(str(falas(id).get("boas_vindas", "")), ctx)

## Reação ao que mudou desde a última conversa com este morador: chefe vencido, recorde ou volta da arena.
## Na primeira conversa só memoriza, sem reagir.
static func reacao(id: String, ctx: Dictionary) -> String:
	var mem := _memoria(id)
	var atual := {"chefe": Progresso.checkpoint_max, "recorde": Progresso.recorde_onda, "ondas": Cidade.ondas_vencidas}
	var conhecia := mem.has("chefe")
	var tipo := ""
	if conhecia:
		if atual["chefe"] > int(mem["chefe"]):
			tipo = "chefe"
		elif atual["recorde"] > int(mem["recorde"]):
			tipo = "recorde"
		elif atual["ondas"] > int(mem["ondas"]):
			tipo = "voltou"
	for chave in atual:
		mem[chave] = atual[chave]
	Cidade.lembrar()
	if tipo == "":
		return ""
	return _texto(falas(id).get("reacoes", {}).get(tipo, ""), ctx)

## Papo do dia a dia: das falas que valem agora, a menos ouvida (empate: sorteio)
static func papo(id: String, ctx: Dictionary) -> String:
	var opcoes: Array = falas(id).get("papo", []).filter(func(f): return vale(f, ctx))
	if opcoes.is_empty():
		return ""
	var menor := 1 << 30
	for f in opcoes:
		menor = mini(menor, _ouvida(id, "papo:" + f["texto"]))
	var candidatas := opcoes.filter(func(f): return _ouvida(id, "papo:" + f["texto"]) == menor)
	var escolhida: Dictionary = candidatas[_rng.randi() % candidatas.size()]
	_marcar(id, "papo:" + escolhida["texto"])
	return _texto(escolhida["texto"], ctx)

## Dica útil pelo estado do jogo: a mais urgente; o que já foi dito hoje perde força, para variar
static func dica(id: String, ctx: Dictionary) -> String:
	var melhor: Dictionary = {}
	var melhor_nota := -INF
	for f in falas(id).get("dicas", []):
		if not vale(f, ctx):
			continue
		var chave: String = "dica:" + f["chave"]
		var nota: float = float(f["prioridade"]) - 40.0 * _vezes_hoje(id, chave) - 3.0 * mini(_ouvida(id, chave), 5) + _rng.randf()
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = f
	if melhor.is_empty():
		return ""
	_marcar(id, "dica:" + melhor["chave"])
	return _texto(melhor["texto"], ctx)

## Histórias liberadas pela amizade
static func historias_liberadas(id: String, ctx: Dictionary) -> Array:
	return falas(id).get("historias", []).filter(func(h): return ctx["amizade"] >= int(h["amizade"]))

static func tem_historia_nova(id: String, ctx: Dictionary) -> bool:
	return historias_liberadas(id, ctx).any(func(h): return _ouvida(id, "historia:" + h["titulo"]) == 0)

## A próxima história: a primeira ainda não contada; se todas já foram, recomeça pela menos ouvida.
## Sem nenhuma liberada, diz quanto falta de amizade.
static func historia(id: String, ctx: Dictionary) -> String:
	var liberadas := historias_liberadas(id, ctx)
	if liberadas.is_empty():
		return "Ainda nao te conheco o bastante para contar historias. Volte para conversar outros dias."
	var escolhida: Dictionary = liberadas[0]
	for h in liberadas:
		if _ouvida(id, "historia:" + h["titulo"]) < _ouvida(id, "historia:" + escolhida["titulo"]):
			escolhida = h
	_marcar(id, "historia:" + escolhida["titulo"])
	var texto: String = escolhida["titulo"] + "\n" + _texto(escolhida["texto"], ctx)
	var proxima: Array = falas(id).get("historias", []).filter(func(h): return ctx["amizade"] < int(h["amizade"]))
	if not proxima.is_empty() and liberadas.all(func(h): return _ouvida(id, "historia:" + h["titulo"]) > 0):
		texto += "\n(Mais amizade, mais historias.)"
	return texto

## Opinião sobre um vizinho (em rodízio) e onde ele está agora
static func vizinho(id: String, ctx: Dictionary) -> String:
	var opinioes: Dictionary = falas(id).get("vizinhos", {})
	if opinioes.is_empty():
		return ""
	var nomes: Array = opinioes.keys()
	var mem := _memoria(id)
	var indice := int(mem.get("vizinho", 0)) % nomes.size()
	mem["vizinho"] = indice + 1
	Cidade.lembrar()
	var outro: String = nomes[indice]
	var agenda := Dados.agenda(outro, ctx["hora"], Calendario.estacao(), -1, Calendario.dia_da_semana())
	var lugar: String = "PRACA" if agenda["local"] == "cidade" else Dados.PREDIOS[agenda["local"]]["nome"]
	return "%s\n(Agora: %s - %s, %s.)" % [_texto(opinioes[outro], ctx), Dados.MORADORES[outro]["nome"], agenda["atividade"], lugar]

## Frase curta do balão sobre a cabeça, sem repetir a última
static func balao(id: String, ctx: Dictionary) -> String:
	var opcoes: Array = falas(id).get("baloes", []).filter(func(f): return vale(f, ctx))
	if opcoes.is_empty():
		return ""
	var ultima := str(_memoria(id).get("ultimo_balao", ""))
	if opcoes.size() > 1:
		opcoes = opcoes.filter(func(f): return f["texto"] != ultima)
	var escolhida: String = opcoes[_rng.randi() % opcoes.size()]["texto"]
	_memoria(id)["ultimo_balao"] = escolhida
	return _texto(escolhida, ctx)
