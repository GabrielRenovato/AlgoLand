class_name DadosItem
extends Resource

const CORES_RARIDADE := {
	"comum": Color(0.92, 0.92, 0.92),
	"incomum": Color(0.35, 0.85, 0.35),
	"raro": Color(0.3, 0.55, 1.0),
	"epico": Color(0.7, 0.35, 1.0),
	"lendario": Color(1.0, 0.6, 0.15),
}
# Sem acentos: as fontes pixel do projeto não os suportam
const NOMES := {
	"espada_basica": "ESPADA",
	"lanca_basica": "LANCA",
	"escudo_basico": "ESCUDO",
	"cabeca_basica": "ELMO",
	"armadura_basica": "ARMADURA",
	"luvas_basicas": "LUVAS",
	"botas_basicas": "BOTAS",
}

@export var id: StringName = &""
@export var tipo: String = "espada_basica"
@export_enum("arma", "escudo", "cabeca", "corpo", "luvas", "botas") var categoria: String = "arma"
@export var nivel: int = 1
@export_enum("comum", "incomum", "raro", "epico", "lendario") var raridade: String = "comum"
@export var icone: Texture2D
@export var duas_maos: bool = false
## Vazio = sem encantamento; ver Codigos/DadosLocais/encantamentos.gd
@export var encantamento: String = ""
@export var nivel_encantamento: int = 0

func nome() -> String:
	return NOMES.get(tipo, tipo.to_upper())

func cor_raridade() -> Color:
	return CORES_RARIDADE.get(raridade, CORES_RARIDADE["comum"])

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
	return item
