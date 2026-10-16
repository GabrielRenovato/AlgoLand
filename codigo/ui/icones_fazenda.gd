extends RefCounted

## Texturas da fazenda: tira de cada planta, saco de semente e item colhido (do "All Crops.png" do Farm RPG, que o
## pack guarda em células de 16x16) e os ícones das ferramentas (assets/ui/fazenda/icones_ferramentas.png, 16x16 lado a lado).
## Tudo em cache: a barra do HUD, as telas de compra/venda e o plantio pedem os mesmos recortes várias vezes.

const Plantas := preload("res://codigo/dados/plantas.gd")
const FOLHA_FERRAMENTAS := preload("res://assets/ui/fazenda/icones_ferramentas.png")
const LADO := 16
const COLUNA_FERRAMENTA := {"enxada": 0, "regador": 1, "machadinha": 3, "picareta": 4}

static var _cache: Dictionary = {}

## Tira da planta (quadros lado a lado: 16x16, ou 16x32 nas altas)
static func tira(id: String) -> Texture2D:
	var chave := "tira:" + id
	if not _cache.has(chave):
		_cache[chave] = load(Plantas.TIRAS + String(Plantas.PLANTAS[id]["tira"]))
	return _cache[chave]

## Quantos quadros tem a tira da planta
static func quadros_da_tira(id: String) -> int:
	return int(tira(id).get_width() / LADO)

static func saco_de_semente(id: String) -> Texture2D:
	return _celula("saco:" + id, Plantas.PLANTAS[id]["saco"])

static func item_colhido(id: String) -> Texture2D:
	return _celula("item:" + id, Plantas.PLANTAS[id]["item"])

## Ícone de uma ferramenta da barra: "enxada", "regador", "machadinha", "picareta" ou "semente:<id>"
static func da_ferramenta(ferramenta: String) -> Texture2D:
	if ferramenta.begins_with(Plantas.PREFIXO_SEMENTE):
		return saco_de_semente(ferramenta.trim_prefix(Plantas.PREFIXO_SEMENTE))
	var chave := "ferramenta:" + ferramenta
	if not _cache.has(chave):
		var atlas := AtlasTexture.new()
		atlas.atlas = FOLHA_FERRAMENTAS
		atlas.region = Rect2(int(COLUNA_FERRAMENTA.get(ferramenta, 0)) * LADO, 0, LADO, LADO)
		_cache[chave] = atlas
	return _cache[chave]

static func _celula(chave: String, celula: Vector2i) -> Texture2D:
	if not _cache.has(chave):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(Plantas.FOLHA_ICONES)
		atlas.region = Rect2(celula.x * LADO, celula.y * LADO, LADO, LADO)
		_cache[chave] = atlas
	return _cache[chave]
