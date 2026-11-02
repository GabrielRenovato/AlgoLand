extends "res://codigo/cidade/interior_casa.gd"
## Montagem a partir de planta; usa somente a biblioteca própria pintada do AlgoLand.
const MOVEIS_EXCLUSIVOS=preload("res://codigo/cidade/familias/moveis_exclusivos.json")
const PLANTAS=preload("res://codigo/cidade/familias/plantas.json")
class EstadoEstacao extends Node:
	var estacao_atual:=-1
var planta:Dictionary
var moveis:Array[Dictionary]=[]
var colisoes:Array[Rect2]=[]
var _tempo_familia:=0.0
var _estacao_familia:=-2
var _estado_estacao:Node
var recursos_usados:Array[String]=[]

func _ready() -> void:
	assert(PLANTAS.data.casas.has(id))
	planta=PLANTAS.data.casas[id].duplicate(true)
	var terrains:=Node.new()
	terrains.name="Terrains"
	add_child(terrains)
	_estado_estacao=EstadoEstacao.new()
	_estado_estacao.name="Estacoes"
	terrains.add_child(_estado_estacao)
	var fisica:=StaticBody2D.new()
	fisica.name="Obstaculos"
	fisica.collision_layer=64
	fisica.collision_mask=0
	add_child(fisica)
	_montar_sala(planta.geometria)
	_montar_paredes(fisica,planta.geometria)
	for item in planta.itens:_movel_familiar(fisica,item)
	definir_estacao(Calendario.estacao())
	Calendario.estacao_mudou.connect(definir_estacao)

func _retangulo(corpo: StaticBody2D,nome: String,area: Rect2) -> void:
	colisoes.append(area)
	super._retangulo(corpo,nome,area)

func _movel_familiar(fisica: StaticBody2D,item: Dictionary) -> void:
	var ficha:Dictionary=MOVEIS_EXCLUSIVOS.data.get(item.chave,{})
	if ficha.is_empty():ficha=InterioresDetalhados.dados(item.chave)
	assert(not ficha.is_empty())
	for caminho in ficha.texturas:
		assert(str(caminho).begins_with("res://assets/cenario/cidade/interiores_detalhados/"))
		recursos_usados.append(caminho)
	var tamanho:Vector2=Vector2(ficha.canvas_logico[0],ficha.canvas_logico[1])
	if item.has("recorte"):tamanho=Vector2(item.recorte[2],item.recorte[3])
	var sprite:=Sprite2D.new()
	sprite.name=item.get("id",str(item.chave).get_file()).to_pascal_case()
	sprite.position=Vector2(item.x,item.y)
	sprite.centered=false
	sprite.offset=Vector2(-tamanho.x/2,-tamanho.y)*4
	sprite.scale=Vector2.ONE/4
	sprite.hframes=int(ficha.get("quadros",1))
	sprite.z_as_relative=false
	sprite.z_index=Profundidade.z_de(item.y)
	if item.get("no_chao",false):sprite.z_index=Profundidade.Z_CHAO+2
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	moveis.append({"sprite":sprite,"ficha":ficha,"item":item})
	if item.get("sem_colisao",false):return
	var col:Array=item.col
	_retangulo(fisica,sprite.name,Rect2(item.x-col[0]/2.0,item.y-col[1],col[0],col[1]))

func definir_estacao(indice: int) -> void:
	_estado_estacao.estacao_atual=posmod(indice,4)
	_estacao_familia=_estado_estacao.estacao_atual
	for movel in moveis:
		var textura:Texture2D=load(movel.ficha.texturas[_estacao_familia])
		if movel.item.has("recorte"):
			var r:Array=movel.item.recorte
			var atlas:=AtlasTexture.new()
			atlas.atlas=textura
			atlas.region=Rect2(r[0]*4,r[1]*4,r[2]*4,r[3]*4)
			textura=atlas
		movel.sprite.texture=textura
		if movel.ficha.has("variantes"):
			var variante:Dictionary=movel.ficha.variantes[_estacao_familia]
			movel.sprite.scale=Vector2.ONE*float(variante.escala)
			movel.sprite.offset=-Vector2(variante.pivo[0],variante.pivo[1])
	get_node("Sala")._atualizar_materiais()

func _process(delta: float) -> void:
	_tempo_familia+=delta
	for movel in moveis:
		if movel.sprite.hframes>1:
			movel.sprite.frame=int(_tempo_familia*float(movel.ficha.get("fps",8)))%movel.sprite.hframes

func ponto_livre(ponto: Vector2,margem:=6.0) -> bool:
	for retangulo in colisoes:
		if retangulo.grow(margem).has_point(ponto):return false
	return Rect2(0,0,planta.geometria.recorte[2],planta.geometria.recorte[3]).has_point(ponto)
