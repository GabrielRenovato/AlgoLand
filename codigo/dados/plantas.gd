extends RefCounted

## Dados das plantas da fazenda (sem estado): o autoload Fazenda (codigo/globais/fazenda_dados.gd) e quem só precisa dos dados
## (itens da mochila, ícones, drop) leem daqui. Separado do autoload para ser carregado sem ele (testes e preloads).

const PREFIXO_SEMENTE := "semente:"
const TIRAS := "res://assets/cenario/Farm RPG/Crops/"
const FOLHA_ICONES := "res://assets/cenario/Farm RPG/Crops/All Crops.png"

## Plantas: estação, dias regados até a colheita (um item por colheita), raridade da semente (a chance de cair dos
## inimigos, em semente_drop.gd: as plantas das melhores poções são as mais raras), a tira do
## Farm RPG (quadros de 16x16, ou 16x32 se "alta"), os quadros da tira em ordem de crescimento (a semente na terra
## até a planta madura) e as células do "All Crops.png" (coluna, linha) do saco de semente e do item colhido.
## Uma estação tem Calendario.DIAS_POR_ESTACAO (30) dias: quem demora mais do que os dias que faltam na estação murcha antes de amadurecer.
const PLANTAS := {
	"cenoura": {"nome": "CENOURA", "estacao": 0, "dias": 3, "raridade": "comum",
		"tira": "Spring/Carrot.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 6), "item": Vector2i(2, 6)},
	"batata": {"nome": "BATATA", "estacao": 0, "dias": 4, "raridade": "comum",
		"tira": "Spring/Potato.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 4), "item": Vector2i(2, 4)},
	"couve_flor": {"nome": "COUVE-FLOR", "estacao": 0, "dias": 5, "raridade": "incomum",
		"tira": "Spring/Cauliflower.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 10), "item": Vector2i(2, 10)},
	"morango": {"nome": "MORANGO", "estacao": 0, "dias": 6, "raridade": "incomum",
		"tira": "Spring/Strawberry.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 2), "item": Vector2i(2, 2)},
	"girassol": {"nome": "GIRASSOL", "estacao": 1, "dias": 3, "raridade": "comum",
		"tira": "Summer/Sunflower.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": true, "saco": Vector2i(9, 5), "item": Vector2i(11, 5)},
	"tomate": {"nome": "TOMATE", "estacao": 1, "dias": 4, "raridade": "raro",
		"tira": "Summer/Tomato.png", "quadros": [0, 1, 2, 3, 4, 6], "alta": false, "saco": Vector2i(9, 4), "item": Vector2i(11, 4)},
	"milho": {"nome": "MILHO", "estacao": 1, "dias": 5, "raridade": "incomum",
		"tira": "Fall/Corn.png", "quadros": [0, 1, 2, 3, 4, 5, 7], "alta": true, "saco": Vector2i(18, 4), "item": Vector2i(20, 4)},
	"melancia": {"nome": "MELANCIA", "estacao": 1, "dias": 6, "raridade": "epico",
		"tira": "Summer/Watermelon.png", "quadros": [0, 1, 2, 3, 4, 5, 7], "alta": false, "saco": Vector2i(9, 11), "item": Vector2i(11, 11)},
	"beterraba": {"nome": "BETERRABA", "estacao": 2, "dias": 3, "raridade": "comum",
		"tira": "Fall/Beetroot.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 1), "item": Vector2i(20, 1)},
	"berinjela": {"nome": "BERINJELA", "estacao": 2, "dias": 4, "raridade": "epico",
		"tira": "Fall/Eggplant.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 5), "item": Vector2i(20, 5)},
	"abobora": {"nome": "ABOBORA", "estacao": 2, "dias": 5, "raridade": "incomum",
		"tira": "Fall/Pumpkin.png", "quadros": [0, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 2), "item": Vector2i(20, 2)},
	"uva": {"nome": "UVA", "estacao": 2, "dias": 6, "raridade": "raro",
		"tira": "Fall/Grapes.png", "quadros": [0, 2, 3, 4, 5], "alta": true, "saco": Vector2i(18, 3), "item": Vector2i(20, 3)},
}
## Raridade da semente (chance de cair dos inimigos em codigo/logica/semente_drop.gd): cor e nome, como nos MMORPGs
const COR_RARIDADE := {"comum": Color(0.92, 0.92, 0.88), "incomum": Color(0.45, 1, 0.4), "raro": Color(0.4, 0.68, 1),
	"epico": Color(0.82, 0.45, 1)}
const NOME_RARIDADE := {"comum": "COMUM", "incomum": "INCOMUM", "raro": "RARA", "epico": "EPICA"}
## Ordem de exibição (barra de ferramentas e listas)
const ORDEM_PLANTAS: Array[String] = ["cenoura", "batata", "couve_flor", "morango", "girassol", "tomate", "milho",
	"melancia", "beterraba", "berinjela", "abobora", "uva"]

## Texto do tempo de crescimento: "3 DIAS" (sem acento por causa da fonte)
static func texto_crescimento(id: String) -> String:
	var dias := int(PLANTAS[id]["dias"]) if PLANTAS.has(id) else 0
	return "%d DIA%s" % [dias, "" if dias == 1 else "S"]

## Ids das plantas de uma estação, na ordem de exibição
static func plantas_da_estacao(estacao: int) -> Array[String]:
	var lista: Array[String] = []
	for id in ORDEM_PLANTAS:
		if int(PLANTAS[id]["estacao"]) == estacao:
			lista.append(id)
	return lista
