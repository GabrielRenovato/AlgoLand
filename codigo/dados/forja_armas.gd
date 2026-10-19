extends RefCounted

## Materiais são pilhas físicas na mochila. O Ivo consome os itens de quem fabrica.
const MATERIAIS := {
	"moeda_forja": {"nome": "MOEDA DE FORJA", "origem": "Pode cair dos chefes da arena."},
	"pedra_vara": {"nome": "PEDRA DA VARA", "origem": "Pode ser encontrada pescando."},
	"madeira": {"nome": "MADEIRA", "origem": "Corte arvores e arranque os tocos na fazenda."},
	"pedra": {"nome": "PEDRA", "origem": "Quebre pedras na fazenda com a picareta."},
	"ferro": {"nome": "MINERIO DE FERRO", "origem": "Mine os veios com a picareta: andares 6, 9, 12..."},
	"fibra": {"nome": "FIBRA", "origem": "Corte arbustos ou retire o mato da fazenda."},
	"fragmento": {"nome": "FRAGMENTO DA ARENA", "origem": "Receba um ao concluir cada onda da arena."},
	"nucleo": {"nome": "NUCLEO DE GUARDIAO", "origem": "Derrote chefes da arena."},
}
const INICIAIS_LIVRES := ["espada_basica", "escudo_basico", "enxada", "regador", "machadinha", "picareta", "vara_pesca"]
const RECEITAS := {
	"lanca_basica": {"madeira": 4, "pedra": 2, "fragmento": 2},
	"aljava_basica": {"fibra": 3, "fragmento": 1},
	"cabeca_basica": {"fibra": 2, "fragmento": 2},
	"armadura_basica": {"fibra": 4, "fragmento": 3},
	"luvas_basicas": {"fibra": 2, "fragmento": 1},
	"botas_basicas": {"fibra": 2, "fragmento": 2},
	"elmo_carrasco": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"peitoral_carrasco": {"ferro": 5, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"luvas_carrasco": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"botas_carrasco": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"elmo_cavaleiro_rubro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"peitoral_cavaleiro_rubro": {"ferro": 5, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"luvas_cavaleiro_rubro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"botas_cavaleiro_rubro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"elmo_cavalheiro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"peitoral_cavalheiro": {"ferro": 5, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"luvas_cavalheiro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"botas_cavalheiro": {"ferro": 3, "fibra": 3, "fragmento": 5, "nucleo": 1},
	"arco_curto": {"madeira": 4, "fibra": 4, "fragmento": 2},
	"espada_gemea": {"ferro": 3, "madeira": 4, "fragmento": 4},
	"maca": {"pedra": 4, "ferro": 4, "madeira": 2, "fragmento": 6},
	"machado": {"ferro": 6, "madeira": 6, "nucleo": 1},
	"arco_curvo": {"madeira": 8, "fibra": 6, "ferro": 3, "fragmento": 10},
	"arco_longo": {"madeira": 10, "fibra": 8, "ferro": 5, "nucleo": 2},
}
## Dias corridos do calendário do jogo; avançar ondas não reduz o prazo.
const DIAS_FABRICACAO := {
	"lanca_basica": 2,
	"aljava_basica": 2,
	"cabeca_basica": 2,
	"armadura_basica": 2,
	"luvas_basicas": 2,
	"botas_basicas": 2,
	"elmo_carrasco": 2,
	"peitoral_carrasco": 2,
	"luvas_carrasco": 2,
	"botas_carrasco": 2,
	"elmo_cavaleiro_rubro": 2,
	"peitoral_cavaleiro_rubro": 2,
	"luvas_cavaleiro_rubro": 2,
	"botas_cavaleiro_rubro": 2,
	"elmo_cavalheiro": 2,
	"peitoral_cavalheiro": 2,
	"luvas_cavalheiro": 2,
	"botas_cavalheiro": 2,
	"arco_curto": 1, "espada_gemea": 2, "maca": 2,
	"machado": 3, "arco_curvo": 2, "arco_longo": 3,
}

static func dias_fabricacao(tipo: String) -> int:
	return int(DIAS_FABRICACAO.get(tipo,2))

static func extracao(tipo: String, toco := false) -> Dictionary:
	if toco:
		return {"madeira": 1}
	match tipo:
		"arvore": return {"madeira": 4}
		"arvoreta": return {"madeira": 2, "fibra": 1}
		"arbusto": return {"fibra": 2}
		"mato": return {"fibra": 1}
		"pedra": return {"pedra": 2}
	return {}

const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Desafios := preload("res://codigo/dados/desafios_armas.gd")
const CATEGORIAS := {"escudo_basico":"escudo", "aljava_basica":"secundaria",
	"cabeca_basica":"cabeca", "armadura_basica":"corpo", "luvas_basicas":"luvas", "botas_basicas":"botas"}

static func onda_receita(tipo: String) -> int:
	if Desafios.DESAFIOS.has(tipo):
		return int(Desafios.DESAFIOS[tipo]["meta"])
	if Conjuntos.de_tipo(tipo) != null:
		return 10
	return 1

static func criar_item(tipo: String):
	var Dados = load("res://codigo/modelos/dados_item.gd")
	if not RECEITAS.has(tipo) and not tipo in INICIAIS_LIVRES: return null
	if tipo in Dados.FERRAMENTAS: return Dados.de_fazenda(tipo)
	if tipo == Dados.TIPO_VARA: return Dados.de_vara()
	var item = Dados.new()
	item.id = StringName(tipo)
	item.tipo = tipo
	item.categoria = CATEGORIAS.get(tipo,"arma")
	item.duas_maos = tipo.begins_with("arco_") or tipo=="lanca_basica"
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		item.categoria = conjunto.TIPOS[tipo]["slot"]
		item.raridade = conjunto.RARIDADE
	return item

static func nome(tipo: String) -> String:
	var item = criar_item(tipo)
	return item.nome() if item != null else tipo.to_upper()
