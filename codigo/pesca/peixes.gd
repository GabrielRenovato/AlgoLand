extends RefCounted

## Peixes da pesca (pedido de 2026-10-17: minigame copiado do SeasonsFarm). Nomes e ícones vêm do catálogo do Nilo
## (assets/pesca/catalogo.json); aqui ficam raridade, dificuldade, estações e o que o Nilo paga em Brasas.
## dificuldade (0..100) é o teto do minigame de fisgada; estacoes vazio = o ano todo (0 prim., 1 verão, 2 outono, 3 inverno).

const CATALOGO := "res://assets/pesca/catalogo.json"
const PESOS := {"comum": 60, "incomum": 25, "raro": 10, "epico": 5}
## Textura de salto (4 quadros) por raridade, a sombra do peixe se debatendo na água
const SALTOS := {
	"comum": "res://assets/pesca/salto_comum.png", "incomum": "res://assets/pesca/salto_incomum.png",
	"raro": "res://assets/pesca/salto_raro.png", "epico": "res://assets/pesca/salto_epico.png",
}
static var DADOS := {
	"sardinha": {"raridade": "comum", "dificuldade": 20, "estacoes": [], "brasas": 3},
	"anchova": {"raridade": "comum", "dificuldade": 28, "estacoes": [], "brasas": 3},
	"linguado": {"raridade": "incomum", "dificuldade": 45, "estacoes": [0, 3], "brasas": 5},
	"atum": {"raridade": "incomum", "dificuldade": 60, "estacoes": [1, 2], "brasas": 6},
	"baiacu": {"raridade": "raro", "dificuldade": 75, "estacoes": [1], "brasas": 9},
	"salmao": {"raridade": "epico", "dificuldade": 90, "estacoes": [2, 3], "brasas": 14},
	"carpa": {"raridade": "comum", "dificuldade": 22, "estacoes": [], "brasas": 3},
	"bagre": {"raridade": "comum", "dificuldade": 32, "estacoes": [], "brasas": 3},
	"perca": {"raridade": "incomum", "dificuldade": 48, "estacoes": [0, 1], "brasas": 5},
	"truta": {"raridade": "incomum", "dificuldade": 62, "estacoes": [2, 3], "brasas": 6},
	"dourado": {"raridade": "raro", "dificuldade": 78, "estacoes": [1, 2], "brasas": 9},
	"esturjao": {"raridade": "epico", "dificuldade": 92, "estacoes": [3], "brasas": 14},
	"cavala": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[], "brasas":4},
	"arenque": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[1, 2], "brasas":4},
	"tainha": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[2, 3], "brasas":4},
	"pescada": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[], "brasas":4},
	"corvina": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[0, 1], "brasas":10},
	"robalo": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[1, 2], "brasas":10},
	"pargo": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[], "brasas":10},
	"sargo": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[3, 0], "brasas":10},
	"garoupa": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[0, 1], "brasas":20},
	"moreia": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[], "brasas":20},
	"barracuda": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[2, 3], "brasas":20},
	"peixe_espada": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[3, 0], "brasas":20},
	"arraia": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[], "brasas":34},
	"cacao": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[1, 2], "brasas":34},
	"tubarao_azul": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[2, 3], "brasas":34},
	"peixe_lua": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[], "brasas":34},
	"celacanto": {"raridade":"epico", "dificuldade":90, "nivel_vara":5, "estacoes":[0, 1], "brasas":52},
	"rei_das_profundezas": {"raridade":"epico", "dificuldade":90, "nivel_vara":5, "estacoes":[1, 2], "brasas":52},
	"lambari": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[], "brasas":4},
	"tilapia": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[1, 2], "brasas":4},
	"tucunare": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[2, 3], "brasas":4},
	"pacu": {"raridade":"comum", "dificuldade":38, "nivel_vara":1, "estacoes":[], "brasas":4},
	"piraputanga": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[0, 1], "brasas":10},
	"mandi": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[1, 2], "brasas":10},
	"curimbata": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[], "brasas":10},
	"jundia": {"raridade":"incomum", "dificuldade":51, "nivel_vara":2, "estacoes":[3, 0], "brasas":10},
	"matrinxa": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[0, 1], "brasas":20},
	"pirarara": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[], "brasas":20},
	"surubim": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[2, 3], "brasas":20},
	"cachara": {"raridade":"raro", "dificuldade":64, "nivel_vara":3, "estacoes":[3, 0], "brasas":20},
	"arapaima": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[], "brasas":34},
	"pirarucu": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[1, 2], "brasas":34},
	"piraiba": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[2, 3], "brasas":34},
	"arraia_do_rio": {"raridade":"epico", "dificuldade":77, "nivel_vara":4, "estacoes":[], "brasas":34},
	"dourado_ancestral": {"raridade":"epico", "dificuldade":90, "nivel_vara":5, "estacoes":[0, 1], "brasas":52},
	"guardiao_do_lago": {"raridade":"epico", "dificuldade":90, "nivel_vara":5, "estacoes":[1, 2], "brasas":52},
	"peixe_leao": {"raridade":"epico", "dificuldade":82, "nivel_vara":4, "nivel_pesca":50, "estacoes":[1, 2], "brasas":42},
	"acara_disco": {"raridade":"epico", "dificuldade":80, "nivel_vara":4, "nivel_pesca":50, "estacoes":[0, 1], "brasas":42},
	"peixe_mandarim": {"raridade":"epico", "dificuldade":92, "nivel_vara":5, "nivel_pesca":80, "estacoes":[0, 1], "brasas":68},
	"aruana_prateada": {"raridade":"epico", "dificuldade":93, "nivel_vara":5, "nivel_pesca":80, "estacoes":[2, 3], "brasas":68},
	"imperador_abissal": {"raridade":"epico", "dificuldade":100, "nivel_vara":5, "nivel_pesca":99, "estacoes":[], "brasas":110},
	"carpa_celestial": {"raridade":"epico", "dificuldade":100, "nivel_vara":5, "nivel_pesca":99, "estacoes":[], "brasas":110},
}

static var _catalogo: Dictionary = {}

static func catalogo() -> Dictionary:
	if _catalogo.is_empty():
		var lido = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
		_catalogo = lido["peixes"] if lido is Dictionary else {}
	return _catalogo

static func existe(id: String) -> bool:
	return DADOS.has(id) and catalogo().has(id)

static func nome(id: String) -> String:
	return "PEDRA DA VARA" if id == "pedra_vara" else String(catalogo().get(id, {}).get("nome", id.to_upper()))

static func icone(id: String) -> Texture2D:
	if id == "pedra_vara":
		return load("res://assets/ui/fazenda/drop_pedra.png")
	var caminho := String(catalogo().get(id, {}).get("icone", ""))
	return load(caminho) if caminho != "" else null

static func raridade(id: String) -> String:
	return "epico" if id == "pedra_vara" else String(DADOS.get(id, {}).get("raridade", "comum"))

static func brasas(id: String) -> int:
	return int(DADOS.get(id, {}).get("brasas", 3))

## Sorteia um peixe do `ambiente` ("mar" ou "rio") que sai na `estacao` atual, com pesos por raridade
static func sortear(ambiente: String, estacao: int, rng: RandomNumberGenerator = null, habilidade := 99) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var grupos := {}
	for id in DADOS:
		if nivel_pesca(id) > habilidade:
			continue
		if not catalogo().has(id) or String(catalogo()[id].get("ambiente","")) != ambiente:
			continue
		var estacoes: Array = DADOS[id]["estacoes"]
		if not estacoes.is_empty() and not estacoes.has(estacao):
			continue
		var categoria := raridade(id)
		if not grupos.has(categoria):
			grupos[categoria] = []
		grupos[categoria].append(id)
	var total := 0
	for categoria in grupos:
		total += int(PESOS[categoria])
	if total == 0:
		return ""
	var sorte := rng.randi_range(0,total-1)
	for categoria in grupos:
		sorte -= int(PESOS[categoria])
		if sorte < 0:
			var candidatos: Array = grupos[categoria]
			return candidatos[rng.randi_range(0,candidatos.size()-1)]
	return ""

static func nivel_recomendado(id: String) -> int:
	return int(DADOS.get(id,{}).get("nivel_vara",{"comum":1,"incomum":2,"raro":3,"epico":4}.get(raridade(id),1)))

## Nível da habilidade que libera a espécie; o refinamento continua sendo uma recomendação.
static func nivel_pesca(id: String) -> int:
	if DADOS.get(id, {}).has("nivel_pesca"):
		return int(DADOS[id]["nivel_pesca"])
	var iniciais := {"sardinha":1, "anchova":1, "carpa":1, "bagre":1,
		"linguado":5, "perca":5, "atum":15, "truta":15,
		"baiacu":25, "dourado":25, "salmao":35, "esturjao":35}
	if iniciais.has(id): return int(iniciais[id])
	return int({1:10, 2:20, 3:40, 4:60, 5:90}.get(nivel_recomendado(id), 1))
