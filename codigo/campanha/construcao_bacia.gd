extends Node2D
## Construção por células de 16px. Cada fonte é uma peça reutilizável,
## nunca um recorte exclusivo de uma posição do mapa.
const FONTE := "res://assets/cenario/campanha/bacia_tiles/componentes.png"
const FONTE_MOINHO := "res://assets/cenario/campanha/moinho_modular/componentes.png"
const PECAS_MOINHO := {
	"m_telhado_esquerdo": [Rect2i(0, 0, 314, 314), Vector2i(3, 3)],
	"m_telha": [Rect2i(334, 105, 273, 152), Vector2i.ONE],
	"m_telhado_direito": [Rect2i(627, 0, 314, 314), Vector2i(3, 3)],
	"m_beiral": [Rect2i(320, 1034, 300, 165), Vector2i.ONE],
	"m_frontao": [Rect2i(328, 320, 291, 311), Vector2i(4, 3)],
	"m_oculo": [Rect2i(966, 352, 256, 247), Vector2i(2, 2)],
	"m_fundacao": [Rect2i(320, 688, 304, 216), Vector2i.ONE],
	"m_reboco": [Rect2i(150, 720, 130, 105), Vector2i.ONE],
	"m_mancal": [Rect2i(949, 678, 295, 236), Vector2i(2, 2)],
	"m_viga": [Rect2i(28, 648, 277, 37), Vector2i.ONE],
}
var partes_moinho: Dictionary = {}
var mecanismos: Array[Node2D] = []
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
var pontes_3d: Array[Node2D] = []
var ruinas_3d: Array[Node2D] = []
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
	var original_moinho := load(FONTE_MOINHO).get_image() as Image
	for id in PECAS_MOINHO:
		var tamanho: Vector2i = PECAS_MOINHO[id][1]
		var imagem := original_moinho.get_region(PECAS_MOINHO[id][0])
		imagem.resize(64 * tamanho.x, 64 * tamanho.y, Image.INTERPOLATE_LANCZOS)
		var fonte := TileSetAtlasSource.new()
		fonte.texture = ImageTexture.create_from_image(imagem)
		fonte.texture_region_size = Vector2i(64, 64)
		fonte.create_tile(Vector2i.ZERO, tamanho)
		fonte.get_tile_data(Vector2i.ZERO, 0).texture_origin = -Vector2i((tamanho.x - 1) * 32, (tamanho.y - 1) * 32)
		fontes[id] = conjunto.add_source(fonte)
		if tamanho != Vector2i.ONE: tamanhos[id] = tamanho
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
	bloco(parede, origem, Vector2i(10, 6), "m_reboco")
	bloco(parede, origem + Vector2i(0, 5), Vector2i(10, 1), "m_fundacao")
	var estrutura := camada("MoinhoEstrutura", base)
	for x in [0, 3, 6, 9]:
		bloco(estrutura, origem + Vector2i(x, 0), Vector2i(1, 5), "viga")
	_sprite_moinho("FrechalDaFachada", "m_viga", Vector2(origem * 16) + Vector2(80, 4), Vector2(160, 6), base)
	_sprite_moinho("AmarracaoDaFachada", "m_viga", Vector2(origem * 16) + Vector2(80, 76), Vector2(160, 5), base)
	var esquadrias := camada("MoinhoEsquadrias", base)
	bloco(esquadrias, origem + Vector2i(1, 2), Vector2i(2, 2), "janela")
	bloco(esquadrias, origem + Vector2i(7, 2), Vector2i(2, 2), "janela")
	bloco(esquadrias, origem + Vector2i(4, 3), Vector2i(1, 3), "porta_esquerda")
	bloco(esquadrias, origem + Vector2i(5, 3), Vector2i(1, 3), "porta_direita")
	var teto := camada("MoinhoTelhado", base)
	cobertura(teto, (origem.y - 3) * 16.0)
	teto.material.set_shader_parameter("telhado", true)
	_fecho_telhado(Vector2((origem + Vector2i(-1, -3)) * 16), false, teto.material, teto.z_index - 1)
	_fecho_telhado(Vector2((origem + Vector2i(8, -3)) * 16), true, teto.material, teto.z_index - 1)
	bloco(teto, origem + Vector2i(-1, -3), Vector2i(3, 3), "m_telhado_esquerdo")
	bloco(teto, origem + Vector2i(2, -3), Vector2i(6, 3), "m_telha")
	bloco(teto, origem + Vector2i(8, -3), Vector2i(3, 3), "m_telhado_direito")
	bloco(teto, origem + Vector2i(2, -1), Vector2i(6, 1), "m_beiral")
	var frontao := camada("MoinhoFrontao", base)
	cobertura(frontao, (origem.y - 2) * 16.0)
	bloco(frontao, origem + Vector2i(3, -2), Vector2i(4, 3), "m_frontao")
	var sotao := camada("MoinhoJanelaSotao", base)
	bloco(sotao, origem + Vector2i(4, -1), Vector2i(2, 2), "m_oculo")
	barreira(Rect2(Vector2(origem * 16), Vector2(160, 96)))
	_montar_eixo(origem)

func _fecho_telhado(ponto: Vector2, direita: bool, material_telha: ShaderMaterial, ordem: int) -> void:
	# Preenche o canto inclinado com as mesmas telhas repetíveis; a peça de borda
	# cobre a diagonal. Geometria e textura continuam independentes.
	var triangulo := Polygon2D.new()
	triangulo.name = "FechoDireitoTelhado" if direita else "FechoEsquerdoTelhado"
	triangulo.position = ponto
	triangulo.polygon = PackedVector2Array([Vector2.ZERO, Vector2(48, 48), Vector2(0, 48)]) if direita else PackedVector2Array([Vector2(48, 0), Vector2(48, 48), Vector2(0, 48)])
	var coordenadas := PackedVector2Array()
	for vertice in triangulo.polygon: coordenadas.append(vertice * 4.0)
	triangulo.uv = coordenadas
	triangulo.texture = conjunto.get_source(fontes.m_telha).texture
	triangulo.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	triangulo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	triangulo.material = material_telha
	triangulo.z_as_relative = false
	triangulo.z_index = ordem
	add_child(triangulo)

func _sprite_moinho(nome_peca: String, tipo: String, ponto: Vector2, dimensoes: Vector2, profundidade: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = nome_peca
	sprite.texture = conjunto.get_source(fontes[tipo]).texture
	sprite.position = ponto
	sprite.scale = dimensoes / sprite.texture.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.material = material_sazonal
	sprite.z_as_relative = false
	sprite.z_index = PROF.z_de(profundidade)
	add_child(sprite)
	partes_moinho[nome_peca] = sprite
	return sprite

func _montar_eixo(origem: Vector2i) -> void:
	# O mancal da parede, a roda e o apoio externo compartilham o mesmo eixo.
	var parede := Vector2(origem * 16) + Vector2(8, 72)
	var centro := parede + Vector2(-36, 16)
	var apoio := centro + Vector2(-18, 8)
	partes_moinho["centro_roda"] = centro
	var pe := camada("MoinhoApoioPedra", apoio.y + 42)
	var celula := Vector2i((apoio / 16.0).floor()) + Vector2i(-1, 2)
	bloco(pe, celula, Vector2i(2, 1), "m_fundacao")
	var coluna := _sprite_moinho("CavaleteExterno", "m_viga", apoio + Vector2(0, 24), Vector2(48, 12), apoio.y + 18)
	coluna.rotation = PI / 2.0
	var veio := _sprite_moinho("EixoContinuo", "m_viga", apoio.lerp(parede, 0.5), Vector2(apoio.distance_to(parede) + 8, 7), centro.y - 12)
	veio.rotation = (parede - apoio).angle()
	_sprite_moinho("MancalDaParede", "m_mancal", parede, Vector2(22, 26), parede.y + 32)
	_sprite_moinho("MancalExterno", "m_mancal", apoio, Vector2(16, 20), apoio.y + 48)
	barreira(Rect2(apoio + Vector2(-12, 36), Vector2(24, 18)))

func ruina(origem: Vector2i) -> void:
	var entrada := preload("res://codigo/campanha/entrada_dungeon_bacia_3d.gd").new()
	entrada.name = "EntradaDungeon3D"
	entrada.position = Vector2(origem * 16) + Vector2(96, 64)
	entrada.estacao = estacao
	add_child(entrada)
	ruinas_3d.append(entrada)
	# A passagem central e os limites continuam correspondendo ao espaço jogável.
	barreira(Rect2(Vector2(origem * 16), Vector2(64, 64)))
	barreira(Rect2(Vector2((origem + Vector2i(8, 0)) * 16), Vector2(64, 64)))
	barreira(Rect2(Vector2((origem + Vector2i(4, 0)) * 16), Vector2(64, 16)))
	for lado in [-1, 1]:
		var centro := Vector2(origem * 16) + Vector2(96, 64)
		var x := -90.0 if lado == -1 else 58.0
		barreira(Rect2(centro + Vector2(x, -8), Vector2(32, 32)))

func ponte(origem: Vector2i, tamanho: Vector2i, vertical: bool) -> Rect2:
	var ret := Rect2(Vector2(origem * 16), Vector2(tamanho * 16))
	var modelo := preload("res://codigo/campanha/ponte_bacia_3d_no_mapa.gd").new()
	modelo.name = "Ponte3D_%02d" % pontes_3d.size()
	modelo.tamanho_mapa = Vector2i(tamanho * 16)
	modelo.vertical = vertical
	modelo.estacao = estacao
	modelo.position = ret.get_center()
	add_child(modelo)
	pontes_3d.append(modelo)
	if vertical:
		for x in [origem.x, origem.x + tamanho.x - 1]:
			barreira(Rect2(x * 16, ret.position.y, 6, ret.size.y))
	else:
		for y in [origem.y, origem.y + tamanho.y - 1]:
			barreira(Rect2(ret.position.x, y * 16, ret.size.x, 6))
	return ret

func comporta(origem: Vector2i) -> Node2D:
	var estrutura := preload("res://codigo/campanha/mecanismo_bacia_no_mapa.gd").new()
	estrutura.name = "ComportaTransversal"
	# Centro na água; o modelo transversal projeta os apoios nas duas margens.
	estrutura.position = Vector2(origem * 16) + Vector2(48,16)
	add_child(estrutura)
	estrutura.definir_estacao(estacao)
	mecanismos.append(estrutura)
	for base in estrutura.bases_fisicas():
		terreno._colisao_poligono(base)
	var ponto := estrutura.ponto_acionamento()
	terreno.dados.alvos.comporta_moinho.p = [ponto.x,ponto.y]
	return estrutura

func cobertura(c: TileMapLayer, topo: float) -> void:
	var material := material_sazonal.duplicate() as ShaderMaterial
	material.set_shader_parameter("topo_neve", topo)
	c.material = material
	materiais_expostos.append(material)

func definir_estacao(indice: int) -> void:
	estacao = indice
	material_sazonal.set_shader_parameter("estacao", indice)
	for material in materiais_expostos: material.set_shader_parameter("estacao", indice)
	for ponte_3d in pontes_3d:
		ponte_3d.definir_estacao(indice)
	for mecanismo in mecanismos:
		mecanismo.definir_estacao(indice)
	for ruina_3d in ruinas_3d:
		ruina_3d.definir_estacao(indice)

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
	var no := preload("res://codigo/campanha/mecanismo_bacia_no_mapa.gd").new()
	no.tipo = 1
	no.position = ponto
	add_child(no)
	no.definir_estacao(estacao)
	mecanismos.append(no)
	barreira(Rect2(ponto+Vector2(-6,-5),Vector2(12,7)))
	return no
