extends RefCounted

## Refeições do Caio (pedido de 2026-10-16: ligar a fazenda à arena e deixar a horta quase obrigatória). O Caio cozinha
## na pousada com a colheita (Fazenda.colheita); o prato vale a PRÓXIMA partida inteira e acaba quando ela termina
## (Progresso.encerrar_partida: morte ou botão CIDADE). Um prato por vez; no cooperativo os dois comem o mesmo.
##
## bonus: somado às melhorias permanentes de mesmo nome em Progresso.bonus() (vigor = vida, forca = dano,
## couraca = redução de dano, folego = estamina, saque = ouro por abate). Valores fortes de propósito: equivalem a
## vários níveis de melhoria, para a horta pesar na arena. Uma refeição por estação de plantio usa só plantas dela;
## o banquete mistura as três e é o mais forte. A fonte do jogo não tem acentos: os textos ficam sem eles.

const Peixes := preload("res://codigo/pesca/peixes.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")

const REFEICOES := {
	"omelete_horta": {"nome":"OMELETE DA HORTA", "receita":{"cenoura":1}, "produtos":{"ovo":2},
		"bonus":{"vigor":0.20,"folego":0.25}, "produto_icone":"omelete",
		"texto":"OVOS DO SEU GALINHEIRO COM CENOURA: VIDA E FOLEGO PARA EXPLORAR."},
	"peixe_assado": {"nome":"PEIXE ASSADO COM RAIZES", "receita":{"batata":1}, "peixes":{"sardinha":2},
		"bonus":{"vigor":0.20,"folego":0.30}, "peixe_icone":"sardinha",
		"texto":"SARDINHAS NA BRASA COM BATATA: VIDA E FOLEGO PARA A ARENA."},
	"caldo_rio": {"nome":"CALDO DO RIO", "receita":{"cenoura":1}, "peixes":{"carpa":1,"bagre":1},
		"bonus":{"couraca":0.12,"folego":0.35}, "peixe_icone":"carpa",
		"texto":"CARPA E BAGRE NO CALDO: DEFESA E FOLEGO PARA A ARENA."},
	"salmao_grelhado": {"nome":"SALMAO GRELHADO", "receita":{"abobora":1}, "peixes":{"salmao":1},
		"bonus":{"forca":0.30,"vigor":0.25}, "peixe_icone":"salmao",
		"texto":"UMA CAPTURA ESPECIAL COM ABOBORA: DANO E VIDA PARA A ARENA."},
	"sopa_raizes": {"nome": "SOPA DE RAIZES", "receita": {"cenoura": 2, "batata": 2},
		"bonus": {"vigor": 0.30}, "icone": "batata",
		"texto": "CENOURA E BATATA NO CALDO GROSSO: AGUENTA MUITO MAIS PANCADA."},
	"torta_morango": {"nome": "TORTA DE MORANGO", "receita": {"morango": 2, "couve_flor": 1},
		"bonus": {"forca": 0.20, "folego": 0.30}, "icone": "morango",
		"texto": "DOCE E LEVE: GOLPES MAIS FORTES E FOLEGO DE SOBRA."},
	"milho_assado": {"nome": "MILHO ASSADO NA BRASA", "receita": {"milho": 2, "girassol": 2},
		"bonus": {"saque": 0.40, "folego": 0.20}, "icone": "milho",
		"texto": "O CHEIRO DE MILHO ASSADO ATRAI SORTE: MUITO MAIS OURO POR ABATE."},
	"salada_verao": {"nome": "SALADA DE VERAO", "receita": {"tomate": 2, "melancia": 1},
		"bonus": {"forca": 0.35}, "icone": "tomate",
		"texto": "TOMATE MADURO E MELANCIA GELADA: CADA GOLPE PESA O DOBRO."},
	"ensopado_outono": {"nome": "ENSOPADO DE OUTONO", "receita": {"abobora": 2, "beterraba": 2},
		"bonus": {"couraca": 0.15, "vigor": 0.15}, "icone": "abobora",
		"texto": "ABOBORA E BETERRABA NO FOGO LENTO: A PELE FICA DURA COMO CASCA."},
	"banquete": {"nome": "BANQUETE DA COLHEITA", "receita": {"uva": 1, "berinjela": 1, "milho": 1, "morango": 1},
		"bonus": {"vigor": 0.25, "forca": 0.25, "saque": 0.25}, "icone": "uva",
		"texto": "UM POUCO DE CADA ESTACAO NA MESMA MESA: TUDO MELHORA."},
}
const ORDEM: Array[String] = ["sopa_raizes", "torta_morango", "milho_assado", "salada_verao", "ensopado_outono", "banquete", "peixe_assado", "caldo_rio", "salmao_grelhado", "omelete_horta"]
## Nome curto de cada bônus para os textos ("+30% VIDA")
const NOMES_BONUS := {"vigor": "VIDA", "forca": "DANO", "couraca": "DEFESA", "folego": "FOLEGO", "saque": "OURO"}

static func dados(id: String) -> Dictionary:
	return REFEICOES.get(id, {})

## Quanto a refeição soma na melhoria `chave` (0 sem refeição ou sem esse bônus)
static func bonus(id: String, chave: String) -> float:
	return float(dados(id).get("bonus", {}).get(chave, 0.0))

## "+30% VIDA, +20% DANO"
static func texto_bonus(id: String) -> String:
	var partes: Array[String] = []
	var bonus_prato: Dictionary = dados(id).get("bonus", {})
	for chave in bonus_prato:
		partes.append("+%d%% %s" % [roundi(float(bonus_prato[chave]) * 100.0), NOMES_BONUS.get(chave, chave.to_upper())])
	return ", ".join(partes)

## "2 CENOURA, 2 BATATA"
static func texto_receita(id: String, plantas: Dictionary) -> String:
	var partes: Array[String] = []
	var receita: Dictionary = dados(id).get("receita", {})
	for planta in receita:
		partes.append("%d %s" % [int(receita[planta]), String(plantas.get(planta, {}).get("nome", planta.to_upper()))])
	for peixe in dados(id).get("peixes",{}):
		partes.append("%d %s" % [int(dados(id)["peixes"][peixe]),Peixes.nome(peixe)])
	for produto in dados(id).get("produtos",{}):
		partes.append("%d %s" % [int(dados(id)["produtos"][produto]),produto.to_upper()])
	return ", ".join(partes)

static func icone(id: String) -> Texture2D:
	if dados(id).has("produto_icone"):
		return load("res://assets/cenario/fazenda/galinheiro/%s.png" % dados(id).produto_icone)
	if dados(id).has("peixe_icone"):
		return Peixes.icone(dados(id)["peixe_icone"])
	return IconesFazenda.item_colhido(String(dados(id).get("icone", "cenoura")))
