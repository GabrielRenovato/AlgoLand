extends Node2D

## Raiz da cena da fazenda (cenas/fazenda.tscn, gerada por ferramentas/fazenda/gerar_fazenda.py): prende a câmera
## ao mapa, para a tela nunca mostrar o vazio além da borda da grama. A casa (casa.tscn) não precisa disso: o cômodo
## é menor que a tela e fica cercado de escuro.

## Retângulo do mapa em coordenadas do terreno (o gerador escreve o valor certo)
@export var limites: Rect2 = Rect2(0, 0, 960, 672)
## A cidade também herda este roteiro para limitar a câmera; a comparação pertence só à fazenda.
@export var comparar_visual_fazenda := false

func _ready() -> void:
	if comparar_visual_fazenda:
		var natureza := preload("res://codigo/cenario/natureza_fazenda.gd").new()
		natureza.configurar(get_node("Terrains"))
		var comparacao := preload("res://codigo/cenario/fazenda_tiny.gd").new()
		comparacao.name = "ComparacaoTiny"
		add_child(comparacao)
		_montar_chao_detalhado()
		_montar_pesca_lago()
		var galinheiro := preload("res://codigo/fazenda/galinheiro_exterior.gd").new()
		galinheiro.position = Vector2(176,224)
		add_child(galinheiro)
		_montar_carpinteiro.call_deferred()
	if Comercio.liberado:
		_montar_carroca()
	var jogador := get_node_or_null("Jogador")
	if jogador == null or jogador.get("camera") == null:
		return
	var canto := to_global(limites.position)
	var camera: Camera2D = jogador.camera
	camera.limit_left = int(canto.x)
	camera.limit_top = int(canto.y)
	camera.limit_right = int(canto.x + limites.size.x)
	camera.limit_bottom = int(canto.y + limites.size.y)
	camera.reset_smoothing()

## Carroça do comércio (escondida enquanto Comercio.liberado for false)
func _montar_carroca() -> void:
	var carroca := preload("res://codigo/comercio/carroca.gd").new()
	carroca.name = "Carroca"
	carroca.position = Vector2(528, 288)
	add_child(carroca)
	var chegada := Marker2D.new()
	chegada.name = "Chegada_carroca"
	chegada.add_to_group("chegada")
	chegada.position = Vector2(520, 310)
	add_child(chegada)
	if Comercio.em_viagem:
		_retomar_comercio.call_deferred()

func _retomar_comercio() -> void:
	# O cooperativo monta os viewports e as interfaces depois do ready da cena.
	for i in 4:
		await get_tree().process_frame
	if not Comercio.em_viagem:
		return
	for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
		if jogador != null:
			jogador.global_position = Vector2(520, 310)
			EventosJogo.abrir_tela_para(jogador, "comercio")

## Grama e terra no acabamento da cidade, trocadas junto com a estação.
func _montar_chao_detalhado() -> void:
	var estacoes := get_node("Terrains/Estacoes")
	var chao := preload("res://codigo/cenario/chao_fazenda.gd").new()
	chao.configurar(get_node("Terrains"),estacoes)
	estacoes.estacao_mudou.connect(chao.aplicar)
	chao.aplicar(maxi(estacoes.estacao_atual,0))

## O lago existente também fornece as espécies de água doce do catálogo do Nilo.
func _montar_pesca_lago() -> void:
	var lago := get_node_or_null("Terrains/Lago")
	if lago == null:
		return
	var ponto := preload("res://codigo/pesca/ponto_pesca.gd").new()
	ponto.name = "PescaLago"
	ponto.position = to_local(lago.global_position)+Vector2(0,-46)
	ponto.direcao = Vector2.DOWN
	ponto.ambiente = "rio"
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(28,20)
	forma.shape = retangulo
	ponto.add_child(forma)
	add_child(ponto)

func _montar_carpinteiro() -> void:
	add_child(preload("res://codigo/fazenda/ambiente_obra.gd").new())
