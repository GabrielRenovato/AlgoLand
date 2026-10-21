extends Node2D

## Cercado e aves da família. Não compartilha nem altera o bando da fazenda do jogador.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const CERCA := "res://assets/cenario/cidade/complementos/cercas/"
const ESTACOES := ["primavera","verao","outono","inverno"]
var cercado: Rect2
var abrigo: Vector2
var _pecas: Array[Sprite2D] = []
var _estacao := -1

func _ready() -> void:
	name = "QuintalCarpinteiro"
	var dados: Dictionary = preload("res://codigo/cidade/dados_cidade.gd")._layout.quintal_carpinteiro
	var r: Array = dados.cercado
	cercado = Rect2(r[0],r[1],r[2],r[3])
	abrigo = Vector2(dados.abrigo[0],dados.abrigo[1])
	var corpo := StaticBody2D.new()
	corpo.name = "ColisoesCercado"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	_horizontal(corpo,cercado.position.x,dados.portao[0],cercado.position.y)
	_horizontal(corpo,dados.portao[1],cercado.end.x,cercado.position.y)
	_horizontal(corpo,cercado.position.x,cercado.end.x,cercado.end.y)
	_vertical(corpo,cercado.position.x,cercado.position.y,cercado.end.y)
	_vertical(corpo,cercado.end.x,cercado.position.y,cercado.end.y)
	# Folhas abertas para dentro: a abertura central continua acessível à cadeira.
	_vertical(corpo,dados.portao[0],cercado.position.y,cercado.position.y+24)
	_vertical(corpo,dados.portao[1],cercado.position.y,cercado.position.y+24)
	var casa := Node2D.new()
	casa.name = "AbrigoDasAves"
	casa.position = abrigo
	casa.z_as_relative = false
	casa.z_index = Profundidade.z_de(abrigo.y)
	add_child(casa)
	var sprite := Sprite2D.new()
	sprite.name = "Imagem"
	sprite.centered = false
	var ambiente: Dictionary = preload("res://codigo/cidade/enfeites_detalhados.gd").dados("mobiliario/galinheiro")
	var usado: Array = [0,0,38,40]
	sprite.offset = Vector2(-float(usado[2])/2,-float(usado[3]))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	casa.add_child(sprite)
	preload("res://codigo/cidade/detalhe_ambiente.gd").instalar(casa,sprite,ambiente)
	_colisao(corpo,Rect2(abrigo-Vector2(18,10),Vector2(36,10)))
	preload("res://codigo/cidade/sombra_cidade.gd").projetar(casa,"objetos/galinheiro",38,30)
	for i in 5:
		var ave := preload("res://codigo/cidade/ave_quintal.gd").new()
		ave.name = "Ave%d" % i
		ave.indice = i
		ave.area = Rect2(cercado.position+Vector2(16,24),Vector2(112,80))
		ave.entrada_abrigo = abrigo+Vector2(0,12)
		ave.position = ave.area.position+Vector2(12+i*20,20+(i%2)*24)
		add_child(ave)
	_atualizar_estacao()

func _horizontal(corpo: Node, inicio: float, fim: float, y: float) -> void:
	for x in range(int(inicio),int(fim),16): _peca(Vector2(x,y),"horizontal",Vector2(-4,-23))
	_peca(Vector2(fim,y),"poste",Vector2(-4,-23))
	_colisao(corpo,Rect2(inicio-4,y-4,fim-inicio+8,4))

func _vertical(corpo: Node, x: float, inicio: float, fim: float) -> void:
	for y in range(int(inicio)+24,int(fim)+1,24): _peca(Vector2(x,y),"vertical",Vector2(-4,-47))
	_peca(Vector2(x,inicio),"poste",Vector2(-4,-23))
	_colisao(corpo,Rect2(x-4,inicio-4,8,fim-inicio+4))

func _colisao(corpo: Node, area: Rect2) -> void:
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = area.size
	forma.shape = retangulo
	forma.position = area.get_center()
	corpo.add_child(forma)

func _peca(ponto: Vector2, tipo: String, deslocamento: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.position = ponto
	sprite.centered = false
	sprite.offset = deslocamento*4
	sprite.scale = Vector2(.25,.25)
	sprite.z_as_relative = false
	sprite.z_index = Profundidade.z_de(ponto.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.set_meta("peca",tipo)
	add_child(sprite)
	_pecas.append(sprite)

func _process(_delta: float) -> void: _atualizar_estacao()

func _atualizar_estacao() -> void:
	var atual: int = get_parent().estacao_visual()
	if atual == _estacao: return
	_estacao = atual
	for sprite in _pecas: sprite.texture = load(CERCA+ESTACOES[atual]+"/"+String(sprite.get_meta("peca"))+".png")
