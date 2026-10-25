extends RefCounted

## Materiais são pilhas físicas na mochila. O Ivo consome os itens de quem fabrica.
const MATERIAIS := {
	"moeda_forja": {"nome": "MOEDA DE FORJA", "origem": "NA BIGORNA: MELHORE O NIVEL E A RARIDADE DAS PECAS DE CONJUNTO."},
	"pedra_vara": {"nome": "PEDRA DA VARA", "origem": "Pode ser encontrada pescando."},
	"madeira": {"nome": "MADEIRA", "origem": "Corte arvores e arranque os tocos na fazenda."},
	"pedra": {"nome": "PEDRA", "origem": "Quebre pedras na fazenda com a picareta."},
	"ferro": {"nome": "MINERIO DE FERRO", "origem": "Mine os veios com a picareta: andares 6, 9, 12..."},
	"fibra": {"nome": "FIBRA", "origem": "Corte arbustos ou retire o mato da fazenda."},
	"fragmento": {"nome": "FRAGMENTO DA ARENA", "origem": "Receba um ao concluir cada andar da arena."},
	"nucleo": {"nome": "NUCLEO DE GUARDIAO", "origem": "Derrote chefes da arena."},
}
const Montantes := preload("res://codigo/dados/armas_montantes.gd")
const INICIAIS_LIVRES := ["espada_basica", "escudo_basico", "enxada", "regador", "machadinha", "picareta", "vara_pesca"]
## Modelos antigos permanecem legíveis em saves e encomendas já pagas.
const ARMAS_RETIRADAS := ["maca", "arco_curvo", "arco_longo"]
static func receitas_ativas() -> Array:
	return RECEITAS.keys().filter(func(tipo): return not tipo in ARMAS_RETIRADAS)

const RECEITAS_BASE := {
	"espada_basica": {"ferro": 2, "madeira": 2},
	"escudo_basico": {"madeira": 4, "ferro": 2},
	"lanca_basica": {"madeira": 12, "pedra": 6, "fibra": 4, "fragmento": 4},
	"aljava_basica": {"fibra": 10, "madeira": 4, "fragmento": 3},
	"cabeca_basica": {"fibra": 8, "pedra": 4, "fragmento": 4},
	"armadura_basica": {"fibra": 12, "madeira": 8, "fragmento": 6},
	"luvas_basicas": {"fibra": 6, "fragmento": 2},
	"botas_basicas": {"fibra": 8, "madeira": 4, "fragmento": 3},
	"elmo_carrasco": {"ferro": 5, "fibra": 8, "fragmento": 12, "nucleo": 2},
	"peitoral_carrasco": {"ferro": 7, "fibra": 12, "fragmento": 16, "nucleo": 2},
	"luvas_carrasco": {"ferro": 3, "fibra": 6, "fragmento": 8, "nucleo": 1},
	"botas_carrasco": {"ferro": 4, "fibra": 8, "fragmento": 10, "nucleo": 1},
	"elmo_cavaleiro_rubro": {"ferro": 5, "fibra": 8, "fragmento": 12, "nucleo": 2},
	"peitoral_cavaleiro_rubro": {"ferro": 7, "fibra": 12, "fragmento": 16, "nucleo": 2},
	"luvas_cavaleiro_rubro": {"ferro": 3, "fibra": 6, "fragmento": 8, "nucleo": 1},
	"botas_cavaleiro_rubro": {"ferro": 4, "fibra": 8, "fragmento": 10, "nucleo": 1},
	"elmo_cavalheiro": {"ferro": 5, "fibra": 8, "fragmento": 12, "nucleo": 2},
	"peitoral_cavalheiro": {"ferro": 7, "fibra": 12, "fragmento": 16, "nucleo": 2},
	"luvas_cavalheiro": {"ferro": 3, "fibra": 6, "fragmento": 8, "nucleo": 1},
	"botas_cavalheiro": {"ferro": 4, "fibra": 8, "fragmento": 10, "nucleo": 1},
	"arco_curto": {"madeira": 16, "fibra": 10, "fragmento": 6},
	"espada_gemea": {"ferro": 5, "madeira": 16, "fragmento": 8},
	"maca": {"pedra": 4, "ferro": 4, "madeira": 2, "fragmento": 6},
	"machado": {"ferro": 8, "madeira": 24, "fragmento": 12, "nucleo": 2},
	"arco_curvo": {"madeira": 8, "fibra": 6, "ferro": 3, "fragmento": 10},
	"arco_longo": {"madeira": 10, "fibra": 8, "ferro": 5, "nucleo": 2},
}
## Dias corridos do calendário do jogo; avançar ondas não reduz o prazo.
const DIAS_FABRICACAO := {
	"espada_basica": 2, "escudo_basico": 2,
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
static var RECEITAS: Dictionary = _montar_receitas()

## Novos conjuntos usam o mesmo contrato de quatro peças, com custo por raridade.
static func _montar_receitas() -> Dictionary:
	var resultado := RECEITAS_BASE.duplicate(true)
	for tipo in Montantes.MODELOS:
		resultado[tipo] = Montantes.MODELOS[tipo].materiais.duplicate()
	for conjunto in Conjuntos.CONJUNTOS:
		var fator := 1 + Raridades.indice(conjunto.RARIDADE)
		for tipo in conjunto.TIPOS:
			if resultado.has(tipo):
				continue
			var peca: String = conjunto.TIPOS[tipo]["peca"]
			var custo: Dictionary = RECEITAS_BASE[peca+"_carrasco"].duplicate()
			for material in custo:
				custo[material] *= fator
			resultado[tipo] = custo
	return resultado

const Raridades := preload("res://codigo/dados/raridades.gd")
## Marcos por peça; conjuntos avançados também respeitam o seu andar mínimo.
const ANDARES_CONJUNTO := {"luvas":10,"botas":12,"cabeca":15,"corpo":20}
const ANDARES_BASICOS := {"lanca_basica":2,"aljava_basica":3,"luvas_basicas":2,
	"botas_basicas":3,"cabeca_basica":4,"armadura_basica":5}
const CATEGORIAS := {"escudo_basico":"escudo", "aljava_basica":"secundaria",
	"cabeca_basica":"cabeca", "armadura_basica":"corpo", "luvas_basicas":"luvas", "botas_basicas":"botas"}

static func onda_receita(tipo: String) -> int:
	if Montantes.MODELOS.has(tipo): return int(Montantes.MODELOS[tipo].andar)
	if Desafios.DESAFIOS.has(tipo):
		return int(Desafios.DESAFIOS[tipo]["meta"])
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		return maxi(conjunto.ONDA_MINIMA, int(ANDARES_CONJUNTO[conjunto.TIPOS[tipo]["slot"]]))
	return int(ANDARES_BASICOS.get(tipo,1))

static func criar_item(tipo: String):
	var Dados = load("res://codigo/modelos/dados_item.gd")
	if not RECEITAS.has(tipo) and not tipo in INICIAIS_LIVRES: return null
	if tipo in Dados.FERRAMENTAS: return Dados.de_fazenda(tipo)
	if tipo == Dados.TIPO_VARA: return Dados.de_vara()
	var item = Dados.new()
	item.id = StringName(tipo)
	item.tipo = tipo
	item.categoria = CATEGORIAS.get(tipo,"arma")
	item.duas_maos = tipo.begins_with("arco_") or tipo in ["lanca_basica", "espada_gemea", "machado"] or Montantes.MODELOS.has(tipo)
	if Montantes.MODELOS.has(tipo):
		var modelo: Dictionary = Montantes.MODELOS[tipo]
		item.raridade = modelo.raridade
		item.encantamento = modelo.get("encantamento", "")
		item.nivel_encantamento = int(modelo.get("nivel_encantamento", 0))
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		item.categoria = conjunto.TIPOS[tipo]["slot"]
		item.raridade = conjunto.RARIDADE
	return item

static func nome(tipo: String) -> String:
	var item = criar_item(tipo)
	return item.nome() if item != null else tipo.to_upper()
