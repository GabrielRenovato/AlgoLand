extends Node2D
## Construção por células de 16px. Cada fonte é uma peça reutilizável,
## nunca um recorte exclusivo de uma posição do mapa.
const FONTE := "res://assets/cenario/campanha/bacia_tiles/componentes.png"
const PROF := preload("res://codigo/globais/profundidade.gd")
const RECORTES := {
	"pedra": Rect2i(178, 70, 80, 48),
	"capitel": Rect2i(168, 31, 128, 32),
	"fundacao": Rect2i(1118, 370, 128, 72),
	"madeira": Rect2i(166, 353, 128, 67),
	"telha": Rect2i(653, 502, 42, 36),
	"beiral": Rect2i(1112, 572, 128, 43),
	"cumeeira": Rect2i(164, 695, 128, 42),
	"tabuas": Rect2i(166, 811, 128, 101),
	"viga": Rect2i(806, 1142, 128, 50),
	"pilar": Rect2i(842, 992, 46, 40),
	"capitel_pilar": Rect2i(816, 955, 83, 31),
	"base_pilar": Rect2i(815, 1040, 91, 34),
	"degrau": Rect2i(651, 207, 116, 42),
	"grade": Rect2i(1110, 960, 128, 112),
	"inscricao": Rect2i(486, 953, 133, 121),
	"janela": Rect2i(507, 339, 101, 125),
	"porta_esquerda": Rect2i(815, 335, 93, 129),
	"porta_direita": Rect2i(969, 335, 93, 129),
	"breu": Rect2i(844, 210, 14, 12),
	"comporta": Rect2i(322, 1110, 126, 120),
	"engrenagem": Rect2i(641, 1110, 128, 123),
}
var camadas: Array[TileMapLayer] = []
var fontes: Dictionary = {}
var tamanhos: Dictionary = {"janela": Vector2i(2, 2), "porta_esquerda": Vector2i(1, 3), "porta_direita": Vector2i(1, 3), "comporta": Vector2i(4, 2)}
var conjunto: TileSet
var terreno: Node2D
var estacao := 0
var material_sazonal := ShaderMaterial.new()
var materiais_expostos: Array[ShaderMaterial] = []

func _ready() -> void:
	material_sazonal.shader = preload("res://codigo/campanha/arquitetura_sazonal.gdshader")
	conjunto = TileSet.new()
	conjunto.tile_size = Vector2i(16, 16)
	var original := load(FONTE).get_image() as Image
	for id in RECORTES:
		# Normalização técnica da peça, conservando o original e o catálogo de recortes.
		var imagem := original.get_region(RECORTES[id])
		var tamanho: Vector2i = tamanhos.get(id, Vector2i.ONE)
		imagem.resize(64 * tamanho.x, 64 * tamanho.y, Image.INTERPOLATE_LANCZOS)
		var fonte := TileSetAtlasSource.new()
		fonte.texture = ImageTexture.create_from_image(imagem)
		fonte.texture_region_size = Vector2i(64, 64)
		fonte.create_tile(Vector2i.ZERO, tamanho)
		fonte.get_tile_data(Vector2i.ZERO, 0).texture_origin = -Vector2i((tamanho.x - 1) * 32, (tamanho.y - 1) * 32)
		fontes[id] = conjunto.add_source(fonte)
	# O TileSet usa 64px gráficos por célula; escala 1/4 conserva grade lógica 16px.
	conjunto.tile_size = Vector2i(64, 64)

func camada(nome_camada: String, base_y: float, piso := false) -> TileMapLayer:
	var c := TileMapLayer.new()
	c.name = nome_camada
	c.tile_set = conjunto
	c.material = material_sazonal
	c.scale = Vector2.ONE / 4.0
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	c.z_as_relative = false
	c.z_index = PROF.Z_CHAO + 3 if piso else PROF.z_de(base_y)
	add_child(c)
	camadas.append(c)
	return c

func bloco(c: TileMapLayer, origem: Vector2i, tamanho: Vector2i, tipo: String) -> void:
	if tamanhos.has(tipo):
		c.set_cell(origem, fontes[tipo], Vector2i.ZERO)
		return
	for y in range(origem.y, origem.y + tamanho.y):
		for x in range(origem.x, origem.x + tamanho.x):
			c.set_cell(Vector2i(x, y), fontes[tipo], Vector2i.ZERO)

func barreira(ret: Rect2) -> void:
	terreno._colisao(ret)

func moinho(origem: Vector2i) -> void:
	var base := origem.y * 16.0 + 96.0
	var parede := camada("MoinhoParedes", base)
	bloco(parede, origem, Vector2i(10, 6), "madeira")
	bloco(parede, origem + Vector2i(0, 5), Vector2i(10, 1), "fundacao")
	for x in [0, 3, 6, 9]:
		bloco(parede, origem + Vector2i(x, 0), Vector2i(1, 5), "viga")
	var esquadrias := camada("MoinhoEsquadrias", base)
	bloco(esquadrias, origem + Vector2i(1, 2), Vector2i(2, 2), "janela")
	bloco(esquadrias, origem + Vector2i(7, 2), Vector2i(2, 2), "janela")
	bloco(esquadrias, origem + Vector2i(4, 3), Vector2i(1, 3), "porta_esquerda")
	bloco(esquadrias, origem + Vector2i(5, 3), Vector2i(1, 3), "porta_direita")
	var teto := camada("MoinhoTelhado", base + 1)
	cobertura(teto, (origem.y - 3) * 16.0)
	teto.material.set_shader_parameter("telhado", true)
	bloco(teto, origem + Vector2i(-1, -3), Vector2i(12, 5), "telha")
	bloco(teto, origem + Vector2i(-1, -3), Vector2i(12, 1), "cumeeira")
	bloco(teto, origem + Vector2i(-1, 1), Vector2i(12, 1), "beiral")
	barreira(Rect2(Vector2(origem * 16), Vector2(160, 96)))

func ruina(origem: Vector2i) -> void:
	var muro := camada("DungeonAlvenaria", origem.y * 16.0 + 64)
	cobertura(muro, origem.y * 16.0)
	bloco(muro, origem, Vector2i(12, 4), "pedra")
	bloco(muro, origem, Vector2i(12, 1), "capitel")
	for x in [0, 3, 8, 11]:
		bloco(muro, origem + Vector2i(x, -1), Vector2i(1, 5), "pilar")
		bloco(muro, origem + Vector2i(x, -1), Vector2i.ONE, "capitel_pilar")
		bloco(muro, origem + Vector2i(x, 3), Vector2i.ONE, "base_pilar")
	for y in range(1, 4):
		for x in range(4, 8): muro.erase_cell(origem + Vector2i(x, y))
	var abertura := camada("DungeonPortal", origem.y * 16.0 + 1)
	bloco(abertura, origem + Vector2i(4, 1), Vector2i(4, 3), "breu")
	var escada := camada("DungeonEscadaria", 0, true)
	bloco(escada, origem + Vector2i(4, 4), Vector2i(4, 2), "degrau")
	barreira(Rect2(Vector2(origem * 16), Vector2(64, 64)))
	barreira(Rect2(Vector2((origem + Vector2i(8, 0)) * 16), Vector2(64, 64)))
	barreira(Rect2(Vector2((origem + Vector2i(4, 0)) * 16), Vector2(64, 16)))
	for lado in [-1, 1]:
		var x := origem.x - 1 if lado == -1 else origem.x + 12
		var lateral := camada("DungeonMuroLateral" + str(lado), (origem.y + 7) * 16.0)
		bloco(lateral, Vector2i(x, origem.y + 3), Vector2i(1, 4), "pedra")
		barreira(Rect2(Vector2(x * 16, (origem.y + 3) * 16), Vector2(16, 64)))

func ponte(origem: Vector2i, tamanho: Vector2i, vertical: bool) -> Rect2:
	var piso := camada("PontePiso" + str(camadas.size()), 0, true)
	bloco(piso, origem, tamanho, "tabuas")
	var ret := Rect2(Vector2(origem * 16), Vector2(tamanho * 16))
	if vertical:
		for x in [origem.x, origem.x + tamanho.x - 1]:
			for y in range(origem.y, origem.y + tamanho.y):
				var lateral := camada("PonteBorda_%d_%d" % [x, y], y * 16.0 + 12)
				bloco(lateral, Vector2i(x, y), Vector2i.ONE, "viga")
			barreira(Rect2(x * 16, ret.position.y, 6, ret.size.y))
	else:
		for y in [origem.y, origem.y + tamanho.y - 1]:
			var lateral := camada("PonteBorda_%d" % y, y * 16.0 + 8)
			bloco(lateral, Vector2i(origem.x, y), Vector2i(tamanho.x, 1), "viga")
			barreira(Rect2(ret.position.x, y * 16, ret.size.x, 6))
	return ret

func comporta(origem: Vector2i) -> TileMapLayer:
	var c := camada("ComportaAlvenaria", origem.y * 16.0 + 48)
	for x in [0, 5]:
		bloco(c, origem + Vector2i(x, 0), Vector2i(1, 3), "pilar")
	var portao := camada("ComportaMovel", origem.y * 16.0 + 47)
	bloco(portao, origem + Vector2i(1, 1), Vector2i(4, 2), "comporta")
	bloco(c, origem + Vector2i(1, 0), Vector2i(4, 1), "viga")
	bloco(c, origem + Vector2i(5, 0), Vector2i.ONE, "engrenagem")
	return portao

func cobertura(c: TileMapLayer, topo: float) -> void:
	var material := material_sazonal.duplicate() as ShaderMaterial
	material.set_shader_parameter("topo_neve", topo)
	c.material = material
	materiais_expostos.append(material)

func definir_estacao(indice: int) -> void:
	estacao = indice
	material_sazonal.set_shader_parameter("estacao", indice)
	for material in materiais_expostos: material.set_shader_parameter("estacao", indice)

func sala_manutencao() -> Rect2:
	var origem := Vector2i(128, -8)
	var fundo := Polygon2D.new()
	fundo.name = "EscuridaoSubsolo"
	fundo.polygon = PackedVector2Array([Vector2(1800, -600), Vector2(2700, -600), Vector2(2700, 600), Vector2(1800, 600)])
	fundo.color = Color("0c1215")
	fundo.z_as_relative = false
	fundo.z_index = PROF.Z_CHAO
	add_child(fundo)
	var piso := camada("SubsoloPiso", 0, true)
	bloco(piso, origem, Vector2i(24, 16), "fundacao")
	piso.modulate = Color(0.48, 0.57, 0.57)
	var paredes := camada("SubsoloParedeNorte", -80)
	bloco(paredes, origem, Vector2i(24, 3), "pedra")
	bloco(paredes, origem, Vector2i(24, 1), "capitel")
	for x in [0, 6, 17, 23]:
		bloco(paredes, origem + Vector2i(x, 0), Vector2i(1, 4), "pilar")
	var estela := camada("InscricoesAntigas", -66)
	bloco(estela, origem + Vector2i(10, 2), Vector2i(4, 2), "inscricao")
	var escada := camada("SubsoloEscada", 0, true)
	bloco(escada, origem + Vector2i(10, 12), Vector2i(4, 3), "degrau")
	for x in [origem.x, origem.x + 23]:
		var lateral := camada("SubsoloLateral" + str(x), 100)
		bloco(lateral, Vector2i(x, origem.y + 3), Vector2i(1, 13), "pedra")
	var ret := Rect2(Vector2(origem * 16), Vector2(384, 256))
	for b in [Rect2(ret.position, Vector2(384, 48)), Rect2(ret.position, Vector2(12, 256)), Rect2(ret.position + Vector2(372, 0), Vector2(12, 256)), Rect2(ret.position + Vector2(0, 244), Vector2(384, 12))]:
		barreira(b)
	return ret

func registro(ponto: Vector2) -> Node2D:
	var no := Node2D.new()
	no.position = ponto
	no.z_as_relative = false
	no.z_index = PROF.z_de(ponto.y)
	add_child(no)
	var textura := conjunto.get_source(fontes.engrenagem).texture as Texture2D
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.scale = Vector2.ONE * 0.3
	sprite.position.y = -12
	sprite.material = material_sazonal
	no.add_child(sprite)
	return no
