extends Node2D
## Apresentação dos bosques com os materiais da cidade/fazenda, na geometria existente.
const NOMES := ["primavera", "verao", "outono", "inverno"]
const NAT := "res://assets/cenario/fazenda/natureza_detalhada/"
const ACAB := "res://assets/cenario/fazenda/acabamento_detalhado/"
const Limite := preload("res://codigo/cenario/limite_plantio.gd")
const ARTE := preload("res://codigo/fendas/arte_floresta.gdshader")
const SUPERFICIE := preload("res://codigo/fendas/superficie_floresta.gdshader")
var estacao := -1
var area := Rect2()
var _terreno: Node2D
var _estacoes: Node
var _chao: TileMapLayer
var _terra: TileMapLayer
var _solo: ShaderMaterial
var _mascaras := {}
var _artes: Array[Dictionary] = []
var _flores: Flores
var _materiais_arte := {}
var _imagens := {}

class Flores extends Node2D:
	var celulas := {}
	var texturas: Array[Texture2D] = []
	func _draw() -> void:
		for celula in celulas:
			draw_texture_rect(texturas[celulas[celula]], Rect2(Vector2(celula * 16), Vector2(16, 16)), false)


func _ready() -> void:
	_terreno = get_parent()
	_estacoes = _terreno.get_node("Estacoes")
	_chao = _terreno.get_node("Chao")
	_terra = _terreno.get_node("Terra")
	var usado := _chao.get_used_rect()
	area = Rect2(Vector2(usado.position * 16), Vector2(usado.size * 16))
	z_index = _chao.z_index
	_terreno.move_child(self, _chao.get_index() + 1)
	_solo = ShaderMaterial.new()
	_solo.shader = preload("res://codigo/cenario/chao_fazenda.gdshader")
	_solo.set_shader_parameter("origem", area.position)
	_solo.set_shader_parameter("tamanho", area.size)
	material = _solo
	_flores = Flores.new()
	_flores.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_flores)
	for dados in _estacoes._grama_continua._celulas:
		if dados.camada == _chao and dados.banco > 0: _flores.celulas[dados.celula] = posmod(dados.atlas.x + dados.atlas.y, 2)
	for objeto in _terreno.get_node("Objetos3D").get_children():
		if not objeto is Sprite2D or not objeto.texture is AtlasTexture: continue
		var atlas: AtlasTexture = objeto.texture
		var peca := ""
		if objeto.get_meta("arvore_gentle", false):
			peca = "carvalho" if atlas.region.position.x == 0 else "pinheiro"
		elif atlas.resource_name in ["arvore", "arvore_var"]:
			peca = "carvalho" if atlas.resource_name == "arvore" else "pinheiro"
		elif atlas.resource_name == "amostra" and atlas.region == Rect2(176, 0, 80, 112): peca = "carvalho"
		elif objeto.has_meta("decoracao_fenda"):
			var id := int(atlas.region.position.y / 64) * 4 + int(atlas.region.position.x / 64)
			if id in [8, 9, 11, 13]: peca = "pedra_%d" % (id % 4)
		if peca.is_empty(): continue
		var acabamento := _arte(atlas, peca)
		objeto.material = acabamento
		objeto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		objeto.set_meta("arte_floresta", peca)
	var detalhes: TileMapLayer = _terreno.get_node("Detalhes")
	# Compartilhar TileData com o chão não deve mudar árvores nem outros mapas.
	detalhes.tile_set = detalhes.tile_set.duplicate(true)
	for celula in detalhes.get_used_cells():
		var coordenada := detalhes.get_cell_atlas_coords(celula)
		if coordenada.x != 4 or coordenada.y < 6 or coordenada.y > 9: continue
		var fonte := detalhes.tile_set.get_source(detalhes.get_cell_source_id(celula)) as TileSetAtlasSource
		fonte.use_texture_padding = false
		var atlas := AtlasTexture.new()
		atlas.atlas = fonte.texture
		atlas.region = Rect2(Vector2(coordenada * 16), Vector2(16, 16))
		fonte.get_tile_data(coordenada, 0).material = _arte(atlas, "pedra_%d" % (coordenada.y - 6))
	_estacoes.estacao_mudou.connect(aplicar)
	aplicar(_estacoes.estacao_atual)
	_imagens.clear()

func _imagem(textura: Texture2D) -> Image:
	if not _imagens.has(textura):
		var imagem := textura.get_image()
		if imagem.is_compressed(): imagem.decompress()
		_imagens[textura] = imagem
	return _imagens[textura]

func _arte(atlas: AtlasTexture, peca: String) -> ShaderMaterial:
	var chave := str(atlas.atlas.get_instance_id()) + str(atlas.region) + peca
	if _materiais_arte.has(chave): return _materiais_arte[chave]
	var acabamento := ShaderMaterial.new()
	acabamento.shader = ARTE
	var tamanho := atlas.atlas.get_size()
	var recorte := _imagem(atlas.atlas).get_region(Rect2i(atlas.region)).get_used_rect()
	var nova: Texture2D = load(NAT + "primavera/" + peca + ".png")
	var base := _imagem(nova).get_used_rect()
	for nome in NOMES:
		base = base.merge(_imagem(load(NAT + nome + "/" + peca + ".png")).get_used_rect())
	acabamento.set_shader_parameter("origem", (atlas.region.position + Vector2(recorte.position)) / tamanho)
	acabamento.set_shader_parameter("tamanho", Vector2(recorte.size) / tamanho)
	var origem_arte := Vector2(base.position) / nova.get_size()
	var tamanho_arte := Vector2(base.size) / nova.get_size()
	acabamento.set_shader_parameter("recorte", Vector4(origem_arte.x, origem_arte.y, tamanho_arte.x, tamanho_arte.y))
	_materiais_arte[chave] = acabamento
	_artes.append({"material": acabamento, "peca": peca})
	return acabamento

func _mascara(indice: int) -> ImageTexture:
	if _mascaras.has(indice): return _mascaras[indice]
	var imagem := Image.create(int(area.size.x), int(area.size.y), false, Image.FORMAT_RGBA8)
	imagem.fill(Color(1, 0, 0, 1))
	for celula in _terra.get_used_cells():
		var atlas: Vector2i = _estacoes._terra_continua.atlas_original(celula)
		var base := celula * 16 - Vector2i(area.position)
		if atlas in Limite.CENTROS:
			imagem.fill_rect(Rect2i(base, Vector2i(16, 16)), Color.BLUE)
		else:
			for y in 16:
				for x in 16:
					if Limite.cobre_pixel(indice, atlas, x, y): imagem.set_pixelv(base + Vector2i(x, y), Color.BLUE)
	var textura := ImageTexture.create_from_image(imagem)
	_mascaras[indice] = textura
	return textura

func aplicar(indice: int) -> void:
	estacao = clampi(indice, 0, 3)
	var grama: Texture2D = load("res://assets/cenario/cidade/chao_detalhado/grama_%s.png" % NOMES[estacao])
	_solo.set_shader_parameter("grama", grama)
	_solo.set_shader_parameter("terra", load(NAT + NOMES[estacao] + "/terra.png"))
	_solo.set_shader_parameter("distribuicao", _mascara(estacao))
	if _estacoes._agua_viva.material != null:
		_estacoes._agua_viva.material.set_shader_parameter("terra", load(NAT + NOMES[estacao] + "/terra.png"))
	for dados in _artes: dados.material.set_shader_parameter("arte", load(NAT + NOMES[estacao] + "/" + dados.peca + ".png"))
	var relevo := _terreno.get_node_or_null("RelevoOriginal")
	if relevo != null:
		for topo in relevo._topos:
			topo.material = ShaderMaterial.new()
			topo.material.shader = SUPERFICIE
			topo.material.set_shader_parameter("arte", grama)
		for face in relevo._faces:
			face.material = ShaderMaterial.new()
			face.material.shader = SUPERFICIE
			face.material.set_shader_parameter("arte", load(NAT + NOMES[estacao] + "/barranco.png"))
			face.material.set_shader_parameter("periodo", Vector2(192, 64))
			# As UVs originais já medem a altura a partir da linha do topo.
			face.material.set_shader_parameter("usar_uv", true)
			face.material.set_shader_parameter("folha", face.texture.get_size())
	_flores.texturas.assign([load(ACAB + NOMES[estacao] + "/flor_0.png"), load(ACAB + NOMES[estacao] + "/flor_1.png")])
	_flores.queue_redraw()
	_chao.hide()
	_terra.hide()
	queue_redraw()

func _draw() -> void:
	draw_rect(area, Color.WHITE)

func _exit_tree() -> void:
	_imagens.clear()
