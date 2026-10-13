class_name DadosItem
extends Resource

const Raridades := preload("res://Codigos/DadosLocais/raridades.gd")
const Conjuntos := preload("res://Codigos/DadosLocais/conjuntos_armadura.gd")

# Sem acentos: as fontes pixel do projeto não os suportam
const NOMES := {
	"espada_basica": "ESPADA",
	"espada_gemea": "ESPADA GEMEA",
	"machado": "MACHADO",
	"maca": "MACA",
	"arco_curto": "ARCO CURTO",
	"arco_curvo": "ARCO CURVO",
	"arco_longo": "ARCO LONGO",
	"lanca_basica": "LANCA",
	"escudo_basico": "ESCUDO",
	"aljava_basica": "ALJAVA",
	"cabeca_basica": "ELMO",
	"armadura_basica": "ARMADURA",
	"luvas_basicas": "LUVAS",
	"botas_basicas": "BOTAS",
}

@export var id: StringName = &""
@export var tipo: String = "espada_basica"
@export_enum("arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas") var categoria: String = "arma"
@export var nivel: int = 1
@export_enum("comum", "incomum", "raro", "epico", "lendario") var raridade: String = "comum"
@export var icone: Texture2D
@export var duas_maos: bool = false
## Vazio = sem encantamento; ver Codigos/DadosLocais/encantamentos.gd
@export var encantamento: String = ""
@export var nivel_encantamento: int = 0
## Bônus extras da raridade: {id do afixo: valor}, ver Raridades.AFIXOS (vazio nos itens comuns e nos saves antigos)
@export var afixos: Dictionary = {}

func nome() -> String:
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		return conjunto.TIPOS[tipo]["nome"]
	return NOMES.get(tipo, tipo.to_upper())

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
	item.nivel_encantamento = int(d.get("nivel_encantamento", 0))
	# Raridade desconhecida (save de outra versão) cai em comum; afixos só valem como dicionário de números
	if not Raridades.valida(item.raridade):
		item.raridade = "comum"
	# O traje de teste do Mordomo era comum; mantém ids e melhorias do save.
	if item.tipo.ends_with("_cavalheiro") and Conjuntos.de_tipo(item.tipo) != null:
		item.raridade = Conjuntos.de_tipo(item.tipo).RARIDADE
	var guardados = d.get("afixos", {})
	if guardados is Dictionary:
		for chave in guardados:
			if Raridades.AFIXOS.has(str(chave)):
				item.afixos[str(chave)] = float(guardados[chave])
	return item
