extends RefCounted
## Variedade dos NPCs gerados: cor própria das peças, altura e corpulência, idade (jovem/adulto/idoso), acessórios,
## sobrenome e ofício. Tudo sai da semente (a ficha continua portátil); `ficha.variacao` pode trazer ajustes manuais.
## ATIVA = false volta ao visual anterior sem restaurar nenhum arquivo. Reversão completa:
## python3 ferramentas/personagem/reverter_variedade_npcs.py
const ATIVA := true
const IDADES := ["jovem", "adulto", "idoso"]
const CATEGORIAS_COR := ["camisa", "calca", "calcado"]
const CINZA_IDOSO := "cec7bb"

## Paleta por perfil: cada NPC recebe uma cor de cada lista e uma pequena variação de brilho.
const PALETAS := {
	"aventureiro": {"camisa": ["586c3e", "3f6a66", "6b5a3a", "7b4a3c", "4a5f86"], "calca": ["846047", "69705b", "4f5a6b", "5b4a3d"], "calcado": ["633f3b", "4a3a30", "6b4a35"]},
	"guarda": {"camisa": ["334b70", "2f4a58", "40506a", "5a2f35"], "calca": ["69705b", "4a4f5a", "3d4552"], "calcado": ["3a2f2c", "4a3a30"]},
	"ferreiro": {"camisa": ["c9b58e", "a8895a", "8c6a45", "b09a78"], "calca": ["69705b", "54493f", "4a4a4a"], "calcado": ["8c5a3c", "5a3d2c"]},
	"agricultor": {"camisa": ["68734c", "8a8a4a", "6b8a5a", "a08a50"], "calca": ["846047", "6b5c48", "57606b"], "calcado": ["8c5a3c", "6b4a35"]},
	"herbalista": {"camisa": ["4c7b7a", "5e8a56", "7a6a9a", "8a6a8a"], "calca": ["69705b", "713c3d", "526074"], "calcado": ["985563", "6b4a50", "633f3b"]},
	"mercador": {"camisa": ["783947", "8a5a2f", "3f5f4f", "5a3f6a"], "calca": ["526074", "3d3d4d", "5b4a3d"], "calcado": ["443642", "633f3b"]},
	"camponesa": {"camisa": ["222027", "3a2f40", "4a3a30", "2f3f3a"], "calca": ["713c3d", "4a5f86", "5b4a3d", "526074"], "calcado": ["985563", "633f3b"]}}

## Acessórios disponíveis (malhas simples em acessorios_npc_3d.gd). `chance` por perfil; os demais perfis usam `base`.
const ACESSORIOS := {
	"chapeu_palha": {"nome": "Chapéu de palha", "base": 0.04, "chance": {"agricultor": 0.55, "aventureiro": 0.2, "mercador": 0.15, "herbalista": 0.15}},
	"lenco": {"nome": "Bandana", "base": 0.03, "chance": {"camponesa": 0.35, "herbalista": 0.2, "ferreiro": 0.2, "agricultor": 0.1}},
	"oculos": {"nome": "Óculos", "base": 0.07, "chance": {"herbalista": 0.15, "mercador": 0.12}},
	"barba": {"nome": "Barba", "base": 0.05, "chance": {"ferreiro": 0.5, "agricultor": 0.3, "aventureiro": 0.25, "mercador": 0.25, "guarda": 0.2, "herbalista": 0.0, "camponesa": 0.0}},
	"bigode": {"nome": "Bigode", "base": 0.04, "chance": {"herbalista": 0.0, "camponesa": 0.0, "guarda": 0.25, "mercador": 0.2}},
	"bolsa": {"nome": "Bolsa a tiracolo", "base": 0.05, "chance": {"mercador": 0.5, "aventureiro": 0.4, "herbalista": 0.3, "guarda": 0.1}}}

const OFICIOS := {"aventureiro": "Aventureiro", "guarda": "Guarda", "ferreiro": "Ferreiro", "agricultor": "Agricultor", "herbalista": "Herbalista", "mercador": "Mercador", "camponesa": "Camponesa"}
const PRIMEIROS := ["Ari", "Cora", "Davi", "Elia", "Gael", "Iara", "Luan", "Mara", "Nara", "Noel", "Ravi", "Yuna", "Bento", "Celina", "Dante", "Eloá", "Fabio", "Gema", "Hugo", "Ismênia", "Jonas", "Kira", "Lauro", "Mirta", "Nuno", "Olívia", "Paulo", "Quitéria", "Rúben", "Sônia", "Tadeu", "Ulda", "Vitor", "Wanda", "Xavi", "Zeca", "Amara", "Breno", "Dália", "Egídio", "Flora", "Ícaro", "Jade", "Leandro", "Mônica", "Otto", "Pérola", "Rafa", "Selma", "Tobias"]
const SOBRENOMES := ["da Ponte", "do Moinho", "Carvalho", "Pedreira", "das Flores", "Lenhador", "Tecelã", "Várzea", "do Vale", "Salgueiro", "Ferreira", "Cerqueira", "da Fonte", "Roseira", "Barro", "Campina", "do Poço", "Silveira", "Brisa", "Fornaça", "Trigueiro", "Malva", "Orvalho", "do Pomar"]

static func _rng(semente: int, perfil: String, numero: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semente, perfil, numero, 7919])
	return rng

static func _cor_variada(hex: String, rng: RandomNumberGenerator) -> String:
	var cor := Color(hex)
	var fator := rng.randf_range(0.9, 1.1)
	return Color(clampf(cor.r * fator, 0.0, 1.0), clampf(cor.g * fator, 0.0, 1.0), clampf(cor.b * fator, 0.0, 1.0)).to_html(false)

## Acrescenta variacao, sobrenome, ofício e nome mais variado à ficha recém-gerada (sem mexer em nada do que ela já tinha,
## exceto o cabelo grisalho dos idosos e o nome sorteado).
static func aplicar(ficha: Dictionary) -> Dictionary:
	if not ATIVA: return ficha
	var perfil: String = ficha.perfil
	var semente: int = ficha.semente
	var rng := _rng(semente, perfil, int(ficha.get("numero", 0)))
	var variacao := {"cores": {}, "acessorios": []}
	# Idade: guardas e aventureiros jovens não viram idosos.
	var sorteio := rng.randf()
	var idade := "adulto"
	if sorteio < 0.18: idade = "jovem"
	elif sorteio > (0.92 if perfil == "guarda" else 0.80): idade = "idoso"
	variacao.idade = idade
	match idade:
		"jovem":
			variacao.altura = rng.randf_range(0.92, 0.97)
			variacao.corpulencia = rng.randf_range(0.92, 1.0)
			variacao.postura = 0.0
		"idoso":
			variacao.altura = rng.randf_range(0.95, 1.0)
			variacao.corpulencia = rng.randf_range(1.0, 1.08)
			variacao.postura = rng.randf_range(0.06, 0.11)
		_:
			variacao.altura = rng.randf_range(0.97, 1.06)
			variacao.corpulencia = rng.randf_range(0.95, 1.10)
			variacao.postura = 0.0
	for categoria in CATEGORIAS_COR:
		var opcoes: Array = PALETAS[perfil][categoria]
		variacao.cores[categoria] = _cor_variada(opcoes[rng.randi_range(0, opcoes.size() - 1)], rng)
	# Acessórios: chapéu e lenço são excludentes; barba exclui bigode; idoso usa mais óculos e barba.
	var escolhidos: Array = []
	for id in ACESSORIOS:
		var dados: Dictionary = ACESSORIOS[id]
		var chance: float = float(dados.chance.get(perfil, dados.base))
		if idade == "idoso" and id in ["oculos", "barba"] and chance > 0.0: chance = minf(chance + 0.2, 0.8)
		if idade == "jovem" and id in ["barba", "bigode"]: chance = 0.0
		if rng.randf() < chance: escolhidos.append(id)
	if "chapeu_palha" in escolhidos and "lenco" in escolhidos: escolhidos.erase("lenco")
	if "barba" in escolhidos and "bigode" in escolhidos: escolhidos.erase("bigode")
	variacao.acessorios = escolhidos
	ficha.variacao = variacao
	# Nome e identidade: sorteio à parte para não deslocar as demais escolhas da semente.
	var nomes := RandomNumberGenerator.new()
	nomes.seed = hash([semente, perfil, 1217])
	ficha.nome = PRIMEIROS[nomes.randi_range(0, PRIMEIROS.size() - 1)]
	ficha.sobrenome = SOBRENOMES[nomes.randi_range(0, SOBRENOMES.size() - 1)]
	ficha.ocupacao = OFICIOS.get(perfil, "Morador")
	if idade == "idoso":
		var cinza := Color(CINZA_IDOSO)
		ficha.aparencia.cor = [cinza.r, cinza.g, cinza.b, 1.0]
	return ficha

## Valida ajustes manuais (oficina, arquivos de ficha) por cima do que a semente sorteou.
static func normalizar(entrada: Variant, ficha: Dictionary) -> Dictionary:
	var resultado: Dictionary = ficha.get("variacao", {}).duplicate(true)
	if not resultado.has("cores"): resultado.cores = {}
	if not ATIVA or not (entrada is Dictionary): return resultado
	if str(entrada.get("idade", "")) in IDADES: resultado.idade = str(entrada.idade)
	if entrada.get("altura") is float or entrada.get("altura") is int: resultado.altura = clampf(float(entrada.altura), 0.85, 1.12)
	if entrada.get("corpulencia") is float or entrada.get("corpulencia") is int: resultado.corpulencia = clampf(float(entrada.corpulencia), 0.85, 1.2)
	if entrada.get("postura") is float or entrada.get("postura") is int: resultado.postura = clampf(float(entrada.postura), 0.0, 0.17)
	if entrada.get("cores") is Dictionary:
		for categoria in CATEGORIAS_COR:
			var hex := str(entrada.cores.get(categoria, "")).trim_prefix("#")
			if hex.length() == 6 and hex.is_valid_hex_number(): resultado.cores[categoria] = hex.to_lower()
	if entrada.get("acessorios") is Array:
		var lista: Array = []
		for id in entrada.acessorios:
			if ACESSORIOS.has(str(id)) and not str(id) in lista: lista.append(str(id))
		resultado.acessorios = lista.slice(0, 5)
	return resultado

static func nome_completo(ficha: Dictionary) -> String:
	var sobrenome := str(ficha.get("sobrenome", ""))
	return ficha.nome if sobrenome.is_empty() else "%s %s" % [ficha.nome, sobrenome]

## Moradores escritos à mão: idade deduzida do cabelo grisalho; acessórios e ajustes só os do JSON.
static func para_morador(pessoa: Dictionary, ficha: Dictionary) -> Dictionary:
	if not ATIVA or not ficha.has("variacao"): return ficha
	var ajuste := {"acessorios": pessoa.get("acessorios", []), "idade": pessoa.get("idade", "idoso" if str(pessoa.get("tom_cabelo", "")).trim_prefix("#") == CINZA_IDOSO else "adulto")}
	for campo in ["altura", "corpulencia", "postura", "cores"]:
		if pessoa.has(campo): ajuste[campo] = pessoa[campo]
	if ajuste.idade == "idoso" and not pessoa.has("postura"): ajuste.postura = 0.08
	if ajuste.idade != "idoso" and not pessoa.has("postura"): ajuste.postura = 0.0
	ficha.variacao = normalizar(ajuste, ficha)
	ficha.sobrenome = pessoa.get("sobrenome", "")
	ficha.ocupacao = pessoa.get("papel", ficha.get("ocupacao", ""))
	return ficha
