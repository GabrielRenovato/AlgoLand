extends RefCounted
## Modelos próprios da família de duas mãos. Raridade inicial não muda a identidade visual.
const RAIZ := "res://assets/personagens/armas/montantes/"
const DENSIDADE := 2
const MODELOS := {
	"montante_ferro": {"nome":"Montante de Ferro", "duas_maos":true, "raridade":"comum", "andar":8, "dano":[9,13,20,30,43], "preco":400, "materiais":{"ferro":5,"madeira":16,"fragmento":8}},
	"montante_sentinela": {"nome":"Montante da Sentinela", "duas_maos":true, "raridade":"incomum", "andar":12, "dano":[10,14,21,31,44], "preco":650, "materiais":{"ferro":10,"madeira":20,"fragmento":12,"nucleo":1}},
	"montante_geada": {"nome":"Montante da Geada", "duas_maos":true, "raridade":"raro", "andar":18, "dano":[11,16,23,34,48], "preco":1000, "encantamento":"gelo", "nivel_encantamento":1, "materiais":{"ferro":18,"madeira":24,"fragmento":20,"nucleo":2}},
	"montante_trovao": {"nome":"Montante do Trovao", "duas_maos":true, "raridade":"epico", "andar":25, "dano":[12,17,25,37,52], "preco":1600, "encantamento":"raio", "nivel_encantamento":1, "materiais":{"ferro":28,"madeira":28,"fragmento":32,"nucleo":4}},
	"montante_astral": {"nome":"Montante Astral", "duas_maos":true, "raridade":"lendario", "andar":35, "dano":[13,19,28,41,58], "preco":2500, "encantamento":"eletrico", "nivel_encantamento":2, "materiais":{"ferro":40,"madeira":32,"fragmento":48,"nucleo":8}},
}
static var _cache := {}

static func folha(tipo: String) -> Texture2D:
	if not _cache.has(tipo): _cache[tipo] = load(RAIZ+tipo+"/espada_dupla.png")
	return _cache[tipo]

static func porte(tipo: String, cabo: bool=false, acao: String="parado", direcao: int=0, quadro: int=0) -> Texture2D:
	var correndo := acao=="correr"
	var arquivo := ("cabo" if cabo else "porte")+("_correr" if correndo else "")
	var chave := "%s:%s:%d:%d" % [tipo,arquivo,direcao,quadro]
	if not _cache.has(chave):
		var fonte := tipo+":"+arquivo
		if not _cache.has(fonte): _cache[fonte] = load(RAIZ+tipo+"/"+arquivo+".png")
		var atlas := AtlasTexture.new()
		atlas.atlas = _cache[fonte]
		atlas.region = Rect2(quadro*160,direcao*160,160,160)
		atlas.filter_clip = true
		_cache[chave] = atlas
	return _cache[chave]
