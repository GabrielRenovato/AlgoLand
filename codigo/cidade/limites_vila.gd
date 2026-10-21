extends Node2D

## Fecha as bordas sem destino; os vãos oeste e sul acompanham as ruas.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const PASTA := "res://assets/cenario/cidade/complementos/cercas/"
static var _vegetacao: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/decoracao/decoracao.json"))
static var _mascara_agua: Image
var _pecas: Array[Sprite2D] = []
var _estacao := -1

func _ready() -> void:
	name = "LimitesVila"
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	# Margem em terra firme; o topo passa abaixo da linha de árvores.
	# A margem leste tem floresta e o cercado próprio da família. Estender a
	# cerca antiga até lá deixava fragmentos isolados entre as copas.
	var leste := 640
	_horizontal(corpo, 48, leste, 104)
	_horizontal(corpo, 16, 304, 560)
	_horizontal(corpo, 368, leste, 560)
	# Desvio conectado em torno do arbusto oeste, sem deslocar a vegetação.
	_vertical(corpo, 48, 104, 176)
	_horizontal(corpo, 16, 48, 176)
	_vertical(corpo, 16, 176, 248)
	_vertical(corpo, 16, 296, 560)
	_aplicar_estacao(get_parent().estacao_visual())
	var calendario := get_node("/root/Calendario")
	calendario.estacao_mudou.connect(_aplicar_estacao)

func _horizontal(corpo: StaticBody2D, inicio: int, fim: int, y: int) -> void:
	for x in range(inicio, fim, 16):
		if not area_livre(get_parent(),Rect2(x-4,y-23,24,23)): continue
		_peca(Vector2(x,y), "horizontal", Vector2(-4,-23))
		_peca(Vector2(x+16,y), "poste", Vector2(-4,-23))
		_colisao(corpo,Rect2(x-4,y-4,24,4))

func _vertical(corpo: StaticBody2D, x: int, inicio: int, fim: int) -> void:
	# A peça vertical conecta postes separados por 24 pixels, com base no poste inferior.
	for y in range(inicio+24, fim+1, 24):
		_peca(Vector2(x,y), "vertical", Vector2(-4,-47))
	_peca(Vector2(x,inicio), "poste", Vector2(-4,-23))
	_colisao(corpo, Rect2(x-4,inicio-4,8,fim-inicio+4))

func _colisao(corpo: StaticBody2D, retangulo: Rect2) -> void:
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = retangulo.size
	forma.shape = caixa
	forma.position = retangulo.get_center()
	corpo.add_child(forma)

func _peca(base: Vector2, tipo: String, deslocamento: Vector2) -> void:
	var tamanho:=Vector2(8,47) if tipo=="vertical" else (Vector2(8,23) if tipo=="poste" else Vector2(16,23))
	var area := Rect2(base+deslocamento,tamanho)
	if not area_livre(get_parent(),area):
		return
	var sprite := Sprite2D.new()
	sprite.position = base
	sprite.centered = false
	sprite.offset = deslocamento*4
	sprite.scale = Vector2(.25,.25)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_as_relative = false
	sprite.z_index = Profundidade.z_de(base.y)
	sprite.set_meta("peca",tipo)
	add_child(sprite)
	_pecas.append(sprite)

func _aplicar_estacao(estacao: int) -> void:
	_estacao=clampi(estacao,0,3)
	for sprite in _pecas:
		sprite.texture = load(PASTA + ESTACOES[clampi(estacao,0,3)] + "/" + String(sprite.get_meta("peca")) + ".png")

func _process(_delta: float) -> void:
	var atual: int=get_parent().estacao_visual()
	if atual!=_estacao: _aplicar_estacao(atual)

## Evita peças atravessando a copa, o tronco ou a margem do rio.
static func area_livre(cena: Node, area: Rect2) -> bool:
	var terreno := cena.get_node("Terrains/Terreno") as TileMapLayer
	var agua:=cena.get_node_or_null("Terrains/SuperficieAgua") as TileMapLayer
	if _mascara_agua==null: _mascara_agua=load("res://assets/cenario/algoland_original/mascara_agua.png").get_image()
	for ponto: Vector2 in [Vector2(area.position.x,area.end.y-1),Vector2(area.get_center().x,area.end.y-1),Vector2(area.end.x-1,area.end.y-1)]:
		var celula:=terreno.local_to_map(ponto)
		var camada:=agua if agua!=null and agua.get_cell_source_id(celula)==3 else terreno
		if camada.get_cell_source_id(celula)==3:
			var pixel:=camada.get_cell_atlas_coords(celula)*16+Vector2i(ponto)-celula*16
			if _mascara_agua.get_pixelv(pixel).r>.5: return false
	for item in _vegetacao:
		if not String(item["p"]).begins_with("vegetacao/"):
			continue
		var usado: Array = item["usado"]
		var vegetacao := Rect2(Vector2(item["x"]-float(usado[2])/2,item["y"]-float(usado[3])),Vector2(usado[2],usado[3]))
		if area.intersects(vegetacao.grow(2)):
			return false
	return true
