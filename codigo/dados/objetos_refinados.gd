extends RefCounted

## Superfícies das armas e ferramentas; dados e transformações de combate usam os moldes nativos.
const Acabamento := preload("res://codigo/dados/acabamento_refinado.gd")
const RAIZ := "res://assets/personagens/refinado/objetos/"
static var _cache := {}
static var _refinadas := {}

static func caminho(nativa: Texture2D) -> String:
	return RAIZ+nativa.resource_path.md5_text()+".png"

static func textura(nativa: Texture2D) -> Texture2D:
	if nativa == null:
		return null
	if _refinadas.has(nativa.get_instance_id()) or nativa.resource_path.begins_with(RAIZ):
		return nativa
	var chave := nativa.get_instance_id()
	if not _cache.has(chave):
		var arquivo := caminho(nativa)
		var pronta: Texture2D
		if ResourceLoader.exists(arquivo):
			pronta = load(arquivo)
		else:
			pronta = ImageTexture.create_from_image(Acabamento.refinar(nativa.get_image(),true,true))
		_cache[chave] = pronta
		_refinadas[pronta.get_instance_id()] = true
	return _cache[chave]

static func aplicar(sprite: Sprite2D, nativa: Texture2D) -> void:
	sprite.texture = textura(nativa)
	if nativa == null:
		return
	sprite.scale = Vector2(0.5,0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
