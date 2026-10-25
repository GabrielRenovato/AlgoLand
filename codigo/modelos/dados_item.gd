class_name DadosItem
extends Resource

const Raridades := preload("res://codigo/dados/raridades.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Plantas := preload("res://codigo/dados/plantas.gd")
## Ferramentas da fazenda (itens da mochila, categoria "ferramenta"); as sementes são "semente" com tipo "semente:<planta>"
## Machadinha (corta árvores) e picareta (quebra pedras): "machadinha" porque "machado" já é uma arma
const FERRAMENTAS := ["enxada", "regador", "machadinha", "picareta"]

# Sem acentos: as fontes pixel do projeto não os suportam
const NOMES := {
	"montante_ferro": "MONTANTE DE FERRO",
	"montante_sentinela": "MONTANTE DA SENTINELA",
	"montante_geada": "MONTANTE DA GEADA",
	"montante_trovao": "MONTANTE DO TROVAO",
	"montante_astral": "MONTANTE ASTRAL",

	"espada_basica": "ESPADA",
	"espada_gemea": "ESPADA DE DUAS MAOS",
	"machado": "MACHADO",
	"maca": "MACA",
	"arco_curto": "ARCO",
	"arco_curvo": "ARCO CURVO",
	"arco_longo": "ARCO LONGO",
	"lanca_basica": "LANCA",
	"escudo_basico": "ESCUDO",
	"aljava_basica": "ALJAVA",
	"cabeca_basica": "ELMO",
	"armadura_basica": "ARMADURA",
	"luvas_basicas": "LUVAS",
	"botas_basicas": "BOTAS",
	"enxada": "ENXADA",
	"regador": "REGADOR",
	"mao": "MAO (COLHER)",
	"machadinha": "MACHADINHA",
	"picareta": "PICARETA",
}

@export var id: StringName = &""
@export var tipo: String = "espada_basica"
@export_enum("arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas", "ferramenta", "semente", "peixe", "vara", "material", "receita", "colheita", "pocao", "produto", "comida") var categoria: String = "arma"
@export var nivel: int = 1
@export_enum("comum", "incomum", "raro", "epico", "lendario") var raridade: String = "comum"
@export var icone: Texture2D
@export var duas_maos: bool = false
## Vazio = sem encantamento; ver codigo/dados/encantamentos.gd
@export var encantamento: String = ""
@export var nivel_encantamento: int = 0
## Bônus extras da raridade: {id do afixo: valor}, ver Raridades.AFIXOS (vazio nos itens comuns e nos saves antigos)
@export var afixos: Dictionary = {}
## Itens que empilham (sementes): quantos há nesta casa da mochila. Os demais têm sempre 1
@export var quantidade: int = 1
@export_range(0,3) var qualidade: int = 0

## Ferramenta ou semente nova para a mochila. Semente: tipo "semente:<planta>", na raridade da planta (a cor da casa)
static func de_fazenda(tipo_fazenda: String, quantos: int = 1) -> DadosItem:
	var item := DadosItem.new()
	item.tipo = tipo_fazenda
	item.id = StringName(tipo_fazenda)
	if tipo_fazenda.begins_with(Plantas.PREFIXO_SEMENTE):
		item.categoria = "semente"
		item.quantidade = maxi(quantos, 1)
		var planta := tipo_fazenda.trim_prefix(Plantas.PREFIXO_SEMENTE)
		item.raridade = String(Plantas.PLANTAS.get(planta, {}).get("raridade", "comum"))
	else:
		item.categoria = "ferramenta"
	return item

func eh_semente() -> bool:
	return categoria == "semente"

func eh_ferramenta() -> bool:
	return categoria == "ferramenta"

## Id da planta de um item de semente ("" nos outros)
func planta() -> String:
	return tipo.trim_prefix(Plantas.PREFIXO_SEMENTE) if eh_semente() else ""

## Vara de pesca da mochila (2026-10-17): um item por jogador, sem pilha. O nível e a raridade (a cor da casa e do ícone)
## acompanham o refinamento em Varas; quem cuida disso é ModeloInventario.sincronizar_vara.
const TIPO_VARA := "vara_pesca"

static func de_vara(nivel_vara: int = 1) -> DadosItem:
	var item := DadosItem.new()
	item.tipo = TIPO_VARA
	item.id = StringName(TIPO_VARA)
	item.categoria = "vara"
	item.aplicar_nivel_vara(nivel_vara)
	return item

func aplicar_nivel_vara(nivel_vara: int) -> void:
	nivel = clampi(nivel_vara, 1, Raridades.ORDEM.size())
	raridade = Raridades.ORDEM[nivel - 1]

func nome() -> String:
	if categoria == "comida":
		return String(preload("res://codigo/dados/refeicoes.gd").dados(conteudo()).get("nome","COMIDA"))
	if categoria == "receita":
		return "RECEITA: " + preload("res://codigo/dados/forja_armas.gd").nome(conteudo())
	if categoria == "material":
		return String(preload("res://codigo/dados/forja_armas.gd").MATERIAIS.get(conteudo(), {}).get("nome", conteudo().to_upper()))
	if categoria == "produto":
		return {"ovo":"OVO","feno":"FENO"}.get(conteudo(),conteudo().to_upper())
	if categoria == "colheita":
		return String(Plantas.PLANTAS.get(conteudo(), {}).get("nome", conteudo().to_upper()))
	if categoria == "pocao":
		return String(preload("res://codigo/dados/pocoes.gd").dados(conteudo()).get("nome", conteudo().to_upper()))
	if categoria == "vara":
		return "VARA DE PESCA"
	if categoria == "peixe":
		return preload("res://codigo/pesca/peixes.gd").nome(peixe())
	if eh_semente():
		return "SEMENTE: %s" % String(Plantas.PLANTAS.get(planta(), {}).get("nome", planta().to_upper()))
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		return conjunto.TIPOS[tipo]["nome"]
	return NOMES.get(tipo, tipo.to_upper())

func conteudo() -> String:
	return tipo.get_slice(":", 1)

func empilhavel() -> bool:
	return categoria in ["semente", "peixe", "material", "receita", "colheita", "pocao", "produto", "comida"]

static func de_coletavel(categoria_item: String, conteudo_item: String, quantos := 1) -> DadosItem:
	var item := DadosItem.new()
	item.tipo = categoria_item + ":" + conteudo_item
	item.id = StringName(item.tipo)
	item.categoria = categoria_item
	item.quantidade = maxi(quantos, 1)
	if categoria_item == "receita":
		item.raridade = "raro"
	elif conteudo_item in ["nucleo", "pedra_vara", "moeda_forja"]:
		item.raridade = "epico"
	return item

func cor_raridade() -> Color:
	return Raridades.cor(raridade)

func nome_raridade() -> String:
	return Raridades.nome(raridade)

func multiplicador_raridade() -> float:
	return Raridades.multiplicador(raridade)

## Valor de um afixo deste item (0 se não tiver)
func afixo(id: String) -> float:
	return float(afixos.get(id, 0.0))

# O ícone não entra no dicionário: ele é recuperado a partir do tipo
func para_dict() -> Dictionary:
	return {
		"id": String(id),
		"tipo": tipo,
		"categoria": categoria,
		"nivel": nivel,
		"raridade": raridade,
		"duas_maos": duas_maos,
		"encantamento": encantamento,
		"nivel_encantamento": nivel_encantamento,
		"afixos": afixos.duplicate(),
		"quantidade": quantidade,
		"qualidade": qualidade,
	}

static func de_dict(d: Dictionary) -> DadosItem:
	var item := DadosItem.new()
	item.id = StringName(str(d.get("id", "")))
	item.tipo = str(d.get("tipo", item.tipo))
	item.categoria = str(d.get("categoria", item.categoria))
	item.nivel = int(d.get("nivel", 1))
	item.raridade = str(d.get("raridade", "comum"))
	item.duas_maos = bool(d.get("duas_maos", false))
	item.encantamento = str(d.get("encantamento", ""))
	# O encantamento vampírico foi trocado pelo elétrico: saves antigos mantêm o nível
	if item.encantamento == "vampirico":
		item.encantamento = "eletrico"
	item.nivel_encantamento = int(d.get("nivel_encantamento", 0))
	# Arcos perderam os encantamentos (25/10/2026): os já encantados voltam a ser arcos comuns de efeito
	if item.tipo.begins_with("arco_"):
		item.encantamento = ""
		item.nivel_encantamento = 0
	item.quantidade = maxi(int(d.get("quantidade", 1)), 1)
	item.qualidade = clampi(int(d.get("qualidade",0)),0,3)
	# Raridade desconhecida (save de outra versão) cai em comum; afixos só valem como dicionário de números
	if not Raridades.valida(item.raridade):
		item.raridade = "comum"
	var guardados = d.get("afixos", {})
	if guardados is Dictionary:
		for chave in guardados:
			if Raridades.AFIXOS.has(str(chave)):
				item.afixos[str(chave)] = float(guardados[chave])
	return item

func peixe() -> String:
	return tipo.trim_prefix("peixe:") if categoria == "peixe" else ""

static func de_peixe(especie: String, qualidade_peixe := 0, quantos := 1) -> DadosItem:
	var item := DadosItem.new()
	item.tipo = "peixe:"+especie
	item.id = StringName(item.tipo+":"+str(clampi(qualidade_peixe,0,3)))
	item.categoria = "peixe"
	item.qualidade = clampi(qualidade_peixe,0,3)
	item.quantidade = maxi(1,quantos)
	item.raridade = preload("res://codigo/pesca/peixes.gd").raridade(especie)
	return item
