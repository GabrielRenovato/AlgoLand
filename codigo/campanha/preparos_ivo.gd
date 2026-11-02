extends RefCounted
## Material que o jogador pede a Ivo na primeira chegada à vila e que a barreira do pomar consome.
## A escolha vai para o save da campanha junto do objetivo `oficio`; o texto muda, o destino do pomar não.
const ESCOLHAS := {
	"ligacao_ferro": {
		"nome": "Ligação de ferro",
		"oferta": "Ferro de carreto, batido em cinta. Aguenta peso e não afrouxa, mas não cede.",
		"feito": "Ivo martela a cinta até ela fechar um anel firme. \"Leve a ligação de ferro. Se a cerca for empurrada, ela segura no lugar.\"",
		"barreira": "A ligação de ferro fecha o vão da cerca sem folga. O teste mostra que ela segura, mas os sulcos seguem por baixo.",
		"barricada": "Você firma a ligação de ferro na cerca da entrada. Ela não cede, e a primeira leva de rebentos chega menor. Quando estiver pronto, volte aqui para chamar a defesa.",
	},
	"ligacao_raiz": {
		"nome": "Ligação de raiz trançada",
		"oferta": "Raiz seca trançada com fio da forja. Cede ao empurrão e volta ao lugar.",
		"feito": "Ivo trança a raiz com fio fino e prova o nó. \"Leve a ligação de raiz. Dobra, mas não quebra.\"",
		"barreira": "A ligação de raiz cede quando algo empurra e volta ao lugar. O teste mostra que ela aguenta, mas os sulcos seguem por baixo.",
		"barricada": "Você prende a ligação de raiz entre as estacas da entrada. Ela dobra com o empurrão e os rebentos chegam mais frágeis. Quando estiver pronto, volte aqui para chamar a defesa.",
	},
}

static func ids() -> Array:
	return ESCOLHAS.keys()

static func valido(id: String) -> bool:
	return ESCOLHAS.has(id)

static func opcoes() -> Array[String]:
	var lista: Array[String] = []
	for id in ESCOLHAS:
		lista.append(ESCOLHAS[id].nome)
	return lista

static func texto(id: String, campo: String) -> String:
	return str(ESCOLHAS.get(id, {}).get(campo, ""))

## Efeito da ligação na defesa da vila: ferro tira um rebento da primeira onda; raiz tira vida de todos.
static func ajuste_defesa(id: String) -> Dictionary:
	match id:
		"ligacao_ferro": return {"menos_primeira_onda": 1, "menos_vida": 0}
		"ligacao_raiz": return {"menos_primeira_onda": 0, "menos_vida": 3}
	return {"menos_primeira_onda": 0, "menos_vida": 0}
