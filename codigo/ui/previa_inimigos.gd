extends TextureRect

## Lê somente a arte da cena: nenhuma IA, colisão ou efeito de combate é instanciado.
static var _cache := {}
var especies: Array[String] = []
var _grupos: Array = []
var _tempo := 0.0
var quadro := 0

func preparar(cenas: Array[PackedScene]) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_IGNORE
	for cena in cenas:
		especies.append(cena.resource_path.get_file().get_basename())
		_grupos.append(_quadros_da_cena(cena))
	_atualizar()

static func _quadros_da_cena(cena: PackedScene) -> Array:
	if _cache.has(cena.resource_path): return _cache[cena.resource_path]
	var estado := cena.get_state()
	var textura: Texture2D
	var colunas := 1
	var linhas := 1
	var animacoes := {}
	for no in estado.get_node_count():
		for propriedade in estado.get_node_property_count(no):
			var chave: StringName = estado.get_node_property_name(no,propriedade)
			var valor = estado.get_node_property_value(no,propriedade)
			if no == 0 and chave == &"anims": animacoes = valor
			if estado.get_node_type(no) != &"Sprite2D" or String(estado.get_node_name(no)) != "Texture": continue
			match chave:
				&"texture": textura = valor
				&"hframes": colunas = valor
				&"vframes": linhas = valor
	var resultado: Array = []
	if textura == null: return resultado
	var indices: Array = animacoes.get("andar_baixo",range(colunas))
	var tamanho := Vector2i(textura.get_width()/colunas,textura.get_height()/linhas)
	var imagem := textura.get_image()
	var recorte := Rect2i()
	for indice: int in indices:
		var origem := Vector2i(indice%colunas,indice/colunas)*tamanho
		var usado := imagem.get_region(Rect2i(origem,tamanho)).get_used_rect()
		if usado.has_area(): recorte = usado if not recorte.has_area() else recorte.merge(usado)
	if not recorte.has_area(): recorte = Rect2i(Vector2i.ZERO,tamanho)
	for indice: int in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(Vector2i(indice%colunas,indice/colunas)*tamanho+recorte.position,recorte.size)
		resultado.append(atlas)
	_cache[cena.resource_path] = resultado
	return resultado

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _grupos.is_empty(): return
	_tempo += delta
	_atualizar()

func _atualizar() -> void:
	if _grupos.is_empty(): return
	var quadros: Array = _grupos[int(_tempo/1.5)%_grupos.size()]
	if quadros.is_empty(): return
	quadro = int(_tempo/0.14)%quadros.size()
	texture = quadros[quadro]
