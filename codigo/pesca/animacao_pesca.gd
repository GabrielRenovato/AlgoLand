extends Node2D

## Página 3 Mana Seed normalizada: 8 poses × quatro direções, pivô central de 64 px.
## Corpo, vestimenta e cabelo usam o mesmo compositor das outras ações do jogador.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Objetos := preload("res://codigo/dados/objetos_refinados.gd")
const Arco := preload("res://codigo/jogador/arco_jogador.gd")
const VARA := preload("res://assets/personagens/Pesca/vara.png")
var vara: Sprite2D
var _camadas: Array[Sprite2D] = []
var _linha := 0
var _pose := 0
var _pontas: Array[Vector2] = []

func iniciar(jogador: Node2D, direcao: Vector2) -> void:
	name = "AnimacaoPesca"
	_linha = Arco.linha_da_direcao(direcao)
	jogador.add_child(self)
	for z in [3,4,5,6]:
		var camada := Sprite2D.new()
		camada.hframes = 8
		camada.vframes = 8
		camada.z_index = z
		camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(camada)
		_camadas.append(camada)
	var roupa: int = jogador.roupa_atual
	var pecas: int = jogador.pecas_cavaleiro
	var raizes: Dictionary = jogador.raizes_armadura
	Aparencia.aplicar_corpo(_camadas[0],"pesca",roupa,pecas,raizes)
	Aparencia.aplicar_roupa(_camadas[1],roupa,"pesca",pecas,raizes)
	Aparencia.aplicar_cabelo(_camadas[2],jogador.cabelo_atual,"pesca",roupa,pecas,raizes)
	_camadas[2].modulate = jogador.cor_cabelo
	Aparencia.aplicar_cartola(_camadas[2],_camadas[1],"pesca",roupa,pecas,raizes)
	vara = _camadas[3]
	Objetos.aplicar(vara,VARA)
	var nv := preload("res://codigo/pesca/varas.gd").nivel(jogador)
	if nv > 1:
		var material_vara := ShaderMaterial.new()
		material_vara.shader = preload("res://codigo/pesca/cor_vara.gdshader")
		material_vara.set_shader_parameter("cor_nivel",preload("res://codigo/pesca/varas.gd").CORES[nv-1])
		vara.material = material_vara
	var imagem := VARA.get_image()
	for coluna in 8:
		var ponta := Vector2(32,32)
		var distancia := -1.0
		for y in 64:
			for x in 64:
				if imagem.get_pixel(coluna*64+x,_linha*64+y).a < 0.5:
					continue
				var ponto := Vector2(x,y)
				var d := ponto.distance_squared_to(Vector2(32,34))
				if d > distancia:
					distancia = d
					ponta = ponto
		_pontas.append(ponta-Vector2(32,32))
	pose(0)

func pose(indice: int) -> void:
	_pose = clampi(indice,0,7)
	for camada in _camadas:
		camada.frame = _linha*8+_pose

func ponta() -> Vector2:
	return _pontas[_pose]
