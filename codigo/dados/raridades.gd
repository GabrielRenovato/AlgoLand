extends RefCounted

## Raridade dos equipamentos (armas e escudos): a ordem, a cor, o multiplicador de status, os afixos (bônus extras sorteados) e o peso de cada
## uma no sorteio de drop. É a fonte ÚNICA: DadosItem, as telas e o drop leem daqui.
##
##   raridade   cor        status   afixos   peso (drop)   (o preço de venda também sobe: "preco" em DADOS)
##   comum      cinza      x1,00    0        60
##   incomum    verde      x1,08    0        28
##   raro       azul       x1,18    1         9
##   epico      roxo       x1,32    2         2,5
##   lendario   laranja    x1,50    3         0,5   (um deles pode vir como encantamento já no nível 1)
##
## Textos sem acento: a fonte pixel do projeto não os tem.

const ORDEM: Array[String] = ["comum", "incomum", "raro", "epico", "lendario"]

const DADOS := {
	"comum": {"nome": "COMUM", "cor": Color(0.92, 0.92, 0.92), "mult": 1.0, "preco": 1.0, "afixos": 0, "peso": 60.0},
	"incomum": {"nome": "INCOMUM", "cor": Color(0.35, 0.85, 0.35), "mult": 1.08, "preco": 1.25, "afixos": 0, "peso": 28.0},
	"raro": {"nome": "RARO", "cor": Color(0.3, 0.55, 1.0), "mult": 1.18, "preco": 1.6, "afixos": 1, "peso": 9.0},
	"epico": {"nome": "EPICO", "cor": Color(0.7, 0.35, 1.0), "mult": 1.32, "preco": 2.2, "afixos": 2, "peso": 2.5},
	"lendario": {"nome": "LENDARIO", "cor": Color(1.0, 0.6, 0.15), "mult": 1.5, "preco": 3.0, "afixos": 3, "peso": 0.5},
}

## Quanto cada onda desloca o sorteio para cima: o peso das raridades acima da comum cresce (1 + onda * isto)
const GANHO_POR_ONDA := 0.05
## Cada "degrau" extra (chefe, mutante...) multiplica o peso das raridades acima da comum por isto, por posição na ordem
const GANHO_POR_DEGRAU := 3.0

## Afixos: valor sorteado entre `min` e `max` (para comum = 1,0 de escala), escalado pela raridade em `escala_raridade`.
## `slots`: em que categorias o afixo pode sair. Os valores são pequenos de propósito: o grosso do ganho está no multiplicador.
const AFIXOS := {
	"critico": {"nome": "CRITICO", "min": 0.02, "max": 0.04, "pct": true, "slots": ["arma"]},
	"dano_critico": {"nome": "DANO CRITICO", "min": 0.10, "max": 0.20, "pct": true, "slots": ["arma"]},
	"roubo_vida": {"nome": "ROUBO DE VIDA", "min": 1.0, "max": 2.0, "pct": false, "slots": ["arma"]},
	"velocidade": {"nome": "VELOCIDADE", "min": 3.0, "max": 6.0, "pct": false, "slots": ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]},
	"vitalidade": {"nome": "VITALIDADE", "min": 1.0, "max": 2.0, "pct": false, "slots": ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]},
	"defesa": {"nome": "DEFESA", "min": 2.0, "max": 4.0, "pct": false, "slots": ["escudo", "cabeca", "corpo", "luvas", "botas"]},
}
## Encantamentos que o lendário pode trazer já no nível 1 (no lugar de um afixo)
const ENCANTAMENTOS_LENDARIO: Array[String] = ["fogo", "gelo", "raio", "eletrico"]

# --- Consultas -------------------------------------------------------------------------------------------------------

static func valida(raridade: String) -> bool:
	return DADOS.has(raridade)

static func indice(raridade: String) -> int:
	return maxi(ORDEM.find(raridade), 0)

static func cor(raridade: String) -> Color:
	return DADOS.get(raridade, DADOS["comum"])["cor"]

static func nome(raridade: String) -> String:
	return DADOS.get(raridade, DADOS["comum"])["nome"]

static func multiplicador(raridade: String) -> float:
	return DADOS.get(raridade, DADOS["comum"])["mult"]

## Quanto a raridade multiplica o preço de venda do item
static func multiplicador_preco(raridade: String) -> float:
	return DADOS.get(raridade, DADOS["comum"])["preco"]

static func quantidade_afixos(raridade: String) -> int:
	return DADOS.get(raridade, DADOS["comum"])["afixos"]

## Aplica o multiplicador a um valor de status. Acima da comum sempre dá pelo menos +1 (um raro nunca empata com o comum por arredondamento)
static func escalar(valor: int, raridade: String) -> int:
	if valor <= 0:
		return valor
	var escalado := roundi(valor * multiplicador(raridade))
	if raridade != "comum" and escalado <= valor:
		escalado = valor + 1
	return escalado

# --- Sorteio ---------------------------------------------------------------------------------------------------------

## Pesos efetivos por raridade para a onda dada (`degraus`: chefe/mutante deslocam para cima). Devolve {raridade: peso}
static func pesos(onda: int, degraus: int = 0, minima: String = "comum") -> Dictionary:
	var resultado := {}
	var piso := indice(minima)
	for i in ORDEM.size():
		if i < piso:
			continue
		var r := ORDEM[i]
		var peso: float = DADOS[r]["peso"]
		if i > 0:
			peso *= 1.0 + maxf(onda, 0) * GANHO_POR_ONDA
			peso *= pow(GANHO_POR_DEGRAU, degraus * float(i) / float(ORDEM.size() - 1))
		resultado[r] = peso
	return resultado

static func sortear(rng: RandomNumberGenerator, onda: int = 1, degraus: int = 0, minima: String = "comum") -> String:
	var tabela := pesos(onda, degraus, minima)
	var total := 0.0
	for r in tabela:
		total += tabela[r]
	var ponto := rng.randf() * total
	for r in ORDEM:
		if not tabela.has(r):
			continue
		ponto -= tabela[r]
		if ponto <= 0.0:
			return r
	return ORDEM[ORDEM.size() - 1] if tabela.has(ORDEM[ORDEM.size() - 1]) else ORDEM[indice(minima)]

# --- Afixos ----------------------------------------------------------------------------------------------------------

## Sorteia os afixos de um item recém-criado: {id: valor}. Para o lendário, um dos slots pode sair como encantamento
## (chave "encantamento" no resultado, tratada por quem cria o item). Sem repetir afixo
static func sortear_afixos(rng: RandomNumberGenerator, categoria: String, raridade: String) -> Dictionary:
	var quantos := quantidade_afixos(raridade)
	var resultado := {}
	if quantos <= 0:
		return resultado
	var candidatos: Array = []
	for id in AFIXOS:
		if categoria in AFIXOS[id]["slots"]:
			candidatos.append(id)
	if raridade == "lendario" and categoria == "arma" and quantos > 0:
		resultado["encantamento"] = ENCANTAMENTOS_LENDARIO[rng.randi_range(0, ENCANTAMENTOS_LENDARIO.size() - 1)]
		quantos -= 1
	while quantos > 0 and not candidatos.is_empty():
		var k := rng.randi_range(0, candidatos.size() - 1)
		var id: String = candidatos[k]
		candidatos.remove_at(k)
		resultado[id] = valor_afixo(rng, id, raridade)
		quantos -= 1
	return resultado

## Valor sorteado de um afixo, escalado pela raridade do item
static func valor_afixo(rng: RandomNumberGenerator, id: String, raridade: String) -> float:
	var escala := 0.6 + 0.4 * indice(raridade) / float(ORDEM.size() - 1)
	var def: Dictionary = AFIXOS[id]
	var bruto := rng.randf_range(def["min"], def["max"]) * escala * 1.6
	# afixos inteiros (roubo de vida, velocidade, vitalidade, defesa) não passam de números redondos; os percentuais ficam com 2 casas
	return snappedf(bruto, 0.01) if def["pct"] else float(maxi(roundi(bruto), 1))

## Um afixo novo (que o item ainda não tem), de qualquer tipo, no valor da raridade: {id: valor}; vazio se já tem todos.
## Usado na ascensão das peças de conjunto na bigorna (cada raridade acima da comum soma um bônus)
static func sortear_afixo_extra(rng: RandomNumberGenerator, existentes: Dictionary, raridade: String) -> Dictionary:
	var candidatos: Array = []
	for id in AFIXOS:
		if not existentes.has(id):
			candidatos.append(id)
	if candidatos.is_empty():
		return {}
	var id: String = candidatos[rng.randi_range(0, candidatos.size() - 1)]
	return {id: valor_afixo(rng, id, raridade)}

static func nome_afixo(id: String) -> String:
	return AFIXOS.get(id, {}).get("nome", id.to_upper())

## Texto de uma linha do tooltip: "+3% CRITICO", "+2 DEFESA"
static func texto_afixo(id: String, valor: float) -> String:
	var def: Dictionary = AFIXOS.get(id, {})
	if def.get("pct", false):
		return "+%d%% %s" % [roundi(valor * 100.0), nome_afixo(id)]
	return "+%d %s" % [roundi(valor), nome_afixo(id)]
