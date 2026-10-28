extends Node2D
## Ringue do duelo, montado sobre o terreno da arena (cenas/terreno.tscn): retângulo de luta cercado
## (cercas da vila, quatro estações, com colisão) e um anel de árvores do lado de fora que usa o atlas
## sazonal das árvores do próprio terreno. Objetos e obstáculos antigos dentro da área somem.
## Coordenadas no espaço do nó Terrains (filho dele).
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PASTA_CERCA := "res://assets/cenario/cidade/complementos/cercas/"
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
## Área de luta (dentro da cerca): 31x18 tiles, longe do lago e do penhasco do canto superior esquerdo.
## A altura é múltipla de 24 (passo das peças verticais) e a largura de 16 (horizontais).
const AREA := Rect2(224, 112, 496, 288)
const PASSO_VERTICAL := 24
## O que estiver até esta distância da cerca sai do mapa (árvores velhas, pedras, colisões).
const LIMPEZA := 96.0
## Distância das árvores do anel até a cerca, por lado (embaixo mais longe: a copa sobe 127 px).
const AFASTAMENTO_ARVORES := {"cima": 18.0, "baixo": 104.0, "lado": 72.0}
const ESPACO_ARVORES := 44.0

var _pecas: Array[Sprite2D] = []
var _estacoes: Node

func _ready() -> void:
	name = "RingueDuelo"
	var terreno := get_parent()
	_limpar(terreno)
	_cercar()
	_arvores(terreno)
	_estacoes = terreno.get_node_or_null("Estacoes")
	if _estacoes != null:
		_estacoes.estacao_mudou.connect(_aplicar_estacao)
		_aplicar_estacao(maxi(0, int(_estacoes.estacao_atual)))
	else:
		_aplicar_estacao(Calendario.estacao())

## Ponto de nascimento de cada lado (no espaço do Terrains).
static func ponto_do_lado(lado: int) -> Vector2:
	var centro := AREA.get_center()
	return centro + Vector2(-AREA.size.x * 0.3 if lado == 0 else AREA.size.x * 0.3, 0)

## A área onde dá para ficar de pé (um pouco para dentro da cerca).
static func area_jogavel() -> Rect2:
	return AREA.grow_individual(-8, -4, -8, -6)

func _limpar(terreno: Node) -> void:
	var zona := AREA.grow(LIMPEZA)
	var objetos := terreno.get_node_or_null("Objetos3D")
	if objetos != null:
		for no in objetos.get_children():
			# Escondidos, não apagados: o grupo de profundidade do terreno ainda os acompanha.
			if no is Node2D and zona.has_point(no.position):
				no.visible = false
	var obstaculos := terreno.get_node_or_null("Obstaculos")
	if obstaculos != null:
		for forma in obstaculos.get_children():
			if forma is CollisionPolygon2D and forma.polygon.size() > 0:
				var centro := Vector2.ZERO
				for p in forma.polygon: centro += p
				centro /= forma.polygon.size()
				if zona.has_point(forma.position + centro):
					forma.set_deferred("disabled", true)

func _cercar() -> void:
	var corpo := StaticBody2D.new()
	corpo.name = "ColisaoCerca"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	var l := AREA.position.x
	var t := AREA.position.y
	var r := AREA.end.x
	var b := AREA.end.y
	# Em cima e embaixo: horizontais encadeadas (poste + travessa) e o poste do canto direito.
	for y in [t, b]:
		var x := l
		while x < r:
			_peca(Vector2(x, y), "horizontal")
			x += 16
		_peca(Vector2(r, y), "poste")
	# Laterais: cada peça vertical é um poste com a travessa subindo até o poste de cima. Inclui os
	# cantos de baixo (o poste da horizontal não tem travessa para cima: ficava um vão).
	for x in [l, r]:
		var y := t + PASSO_VERTICAL
		while y <= b:
			_peca(Vector2(x, y), "vertical")
			y += PASSO_VERTICAL
	# Colisão rente ao desenho: quatro faixas finas na base das peças.
	_faixa(corpo, Rect2(l - 4, t - 5, r - l + 8, 6))
	_faixa(corpo, Rect2(l - 4, b - 5, r - l + 8, 6))
	_faixa(corpo, Rect2(l - 4, t, 8, b - t))
	_faixa(corpo, Rect2(r - 4, t, 8, b - t))

func _faixa(corpo: StaticBody2D, retangulo: Rect2) -> void:
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = retangulo.size
	forma.shape = caixa
	forma.position = retangulo.get_center()
	corpo.add_child(forma)

func _peca(base: Vector2, tipo: String) -> void:
	var sprite := Sprite2D.new()
	sprite.position = base
	sprite.centered = false
	sprite.offset = Vector2(-16, -188 if tipo == "vertical" else -92)
	sprite.scale = Vector2(.25, .25)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_as_relative = false
	sprite.z_index = Profundidade.z_de(global_position.y + base.y)
	sprite.set_meta("peca", tipo)
	add_child(sprite)
	_pecas.append(sprite)

func _aplicar_estacao(estacao: int) -> void:
	var nome: String = ESTACOES[clampi(estacao, 0, 3)]
	for sprite in _pecas:
		sprite.texture = load(PASTA_CERCA + nome + "/" + str(sprite.get_meta("peca")) + ".png")

## Anel de árvores fora da cerca. Reaproveita a AtlasTexture "arvore" do terreno: o Estacoes troca
## o atlas dela a cada estação, então estas árvores acompanham as outras.
func _arvores(terreno: Node) -> void:
	var textura: AtlasTexture = null
	var objetos := terreno.get_node_or_null("Objetos3D")
	if objetos != null:
		for no in objetos.get_children():
			if no is Sprite2D and no.texture is AtlasTexture and (no.texture as AtlasTexture).resource_name == "arvore":
				textura = no.texture
				break
	if textura == null: return
	var aleatorio := RandomNumberGenerator.new()
	aleatorio.seed = 2810
	var pontos: Array[Vector2] = []
	var l := AREA.position.x - AFASTAMENTO_ARVORES.lado
	var r := AREA.end.x + AFASTAMENTO_ARVORES.lado
	var t := AREA.position.y - AFASTAMENTO_ARVORES.cima
	var b := AREA.end.y + AFASTAMENTO_ARVORES.baixo
	var x := l
	while x <= r:
		pontos.append(Vector2(x, t))
		pontos.append(Vector2(x, b))
		x += ESPACO_ARVORES
	var y := t + ESPACO_ARVORES
	while y < b:
		pontos.append(Vector2(l, y))
		pontos.append(Vector2(r, y))
		y += ESPACO_ARVORES
	for ponto in pontos:
		var arvore := Sprite2D.new()
		arvore.texture = textura
		arvore.centered = false
		arvore.offset = Vector2(-64, -127)
		arvore.position = ponto + Vector2(aleatorio.randf_range(-6, 6), aleatorio.randf_range(-5, 5))
		arvore.flip_h = aleatorio.randf() < 0.5
		arvore.z_as_relative = false
		arvore.z_index = Profundidade.z_de(global_position.y + arvore.position.y)
		add_child(arvore)
