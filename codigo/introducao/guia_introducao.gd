extends CharacterBody2D

## Bento durante o prólogo: animação original, rota sobre colisões reais e espera por quem ficou para trás.
signal passo_dado(ponto: Vector2)

const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var cena: Node2D
var jogador: Node2D
var sprite: Sprite2D
var caminho := PackedVector2Array()
var chegou := true
var esperar_jogador := true
var navegacao := AStarGrid2D.new()
const VELOCIDADE_TUTORIAL := 96.0
const DISTANCIA_ESPERAR := 240.0
const DISTANCIA_RETORNAR := 120.0
var esperando_companhia := false
var _tempo := 0.0
var _linha := 0
var _colunas := 7
var _quadros := 6
var _alvo := Vector2.ZERO
var _recalcular := 0.0
var _grid_pronta := false

func _ready() -> void:
	name = "BentoGuia"
	collision_layer = 0
	collision_mask = 64
	var geometria := Dados.geometria_sprite("bento")
	_colunas = int(geometria.grade[0])
	_quadros = int(geometria.quadros_andar)
	sprite = Sprite2D.new()
	var clima := preload("res://codigo/cenario/clima.gd")
	var chovendo := clima.eh_chuva(clima.clima_do_mundo(Calendario.estacao()))
	sprite.texture = load(geometria.folha_chuva if chovendo else Dados.caminho_sprite("bento"))
	sprite.hframes = _colunas
	sprite.vframes = int(geometria.grade[1])
	sprite.scale = Vector2.ONE * float(geometria.escala_mapa)
	sprite.position.y = 9 - (float(geometria.pes_y) - 32) * float(geometria.escala_mapa)
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 5
	forma.shape = circulo
	forma.position.y = 9
	add_child(forma)
	load("res://codigo/cidade/sombra_cidade.gd").contato(self, 17, 3, Vector2(0, 10))

func _montar_grid() -> void:
	var limites: Rect2 = cena.get("limites") if cena.get("limites") != null else Rect2(0, 0, 800, 600)
	navegacao.cell_size = Vector2(8, 8)
	navegacao.offset = Vector2(4, 4)
	navegacao.region = Rect2i(Vector2i.ZERO, Vector2i(limites.size / 8))
	navegacao.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navegacao.update()
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 6
	consulta.shape = forma
	consulta.collision_mask = 96
	var terreno := cena.get_node_or_null("Terrains/Terreno") as TileMapLayer
	var espaco := get_world_2d().direct_space_state
	for y in navegacao.region.size.y:
		for x in navegacao.region.size.x:
			var celula := Vector2i(x, y)
			var pes := cena.to_global(navegacao.get_point_position(celula) + Vector2(0, 9))
			consulta.transform = Transform2D(0, pes)
			if terreno != null and cena.scene_file_path == "res://cenas/cidade.tscn":
				var fonte := terreno.get_cell_source_id(terreno.local_to_map(terreno.to_local(pes)))
				if fonte not in [1, 2]:
					navegacao.set_point_weight_scale(celula, 8.0)
			if not espaco.intersect_shape(consulta, 1).is_empty():
				navegacao.set_point_solid(celula)
	_grid_pronta = true

func _livre(ponto: Vector2) -> Vector2i:
	var centro := Vector2i(ponto / 8)
	for raio in range(16):
		for y in range(-raio, raio + 1):
			for x in range(-raio, raio + 1):
				var celula := centro + Vector2i(x, y)
				if navegacao.is_in_boundsv(celula) and not navegacao.is_point_solid(celula):
					return celula
	return Vector2i(-1, -1)

func ir_ate(destino: Vector2, esperar := true) -> bool:
	if not _grid_pronta:
		_montar_grid()
	esperar_jogador = esperar
	_alvo = destino
	var de := _livre(position)
	var ate := _livre(destino)
	if de.x < 0 or ate.x < 0:
		return false
	caminho = navegacao.get_point_path(de, ate)
	if caminho.is_empty():
		return false
	# Evita prender o guia se um ponto de entrada antigo ficou sobre a borda de uma colisão.
	if position.distance_to(caminho[0]) > 12:
		position = caminho[0]
	_aparar_inicio()
	chegou = false
	return true

## A rota nasce no centro da célula atual, que pode ficar atrás do Bento; ao recalcular no meio do passo
## ele recuava alguns pixels (e virava de costas). Pula esses pontos quando a reta até o seguinte está livre.
func _aparar_inicio() -> void:
	while caminho.size() > 1:
		var seguinte := caminho[1]
		if position.distance_to(seguinte) > caminho[0].distance_to(seguinte) + 0.5:
			return
		if test_move(global_transform, seguinte - position):
			return
		caminho.remove_at(0)

## Mesma malha e mesmas colisões para o jogador que acompanha o guia.
func caminho_para(inicio: Vector2, fim: Vector2) -> PackedVector2Array:
	var de := _livre(inicio)
	var ate := _livre(fim)
	if de.x < 0 or ate.x < 0:
		return PackedVector2Array()
	return navegacao.get_point_path(de, ate)

func _physics_process(delta: float) -> void:
	_tempo += delta
	_recalcular -= delta
	var andando := false
	var ocupado := Introducao.cinematica and esperar_jogador
	var distancia := global_position.distance_to(jogador.global_position) if is_instance_valid(jogador) else 0.0
	if not esperar_jogador:
		esperando_companhia = false
	elif esperando_companhia:
		esperando_companhia = distancia > DISTANCIA_RETORNAR
	else:
		esperando_companhia = distancia > DISTANCIA_ESPERAR
	if not ocupado and not esperando_companhia:
		# Consome todo o deslocamento deste quadro, mesmo cruzando vários pontos de 8 px.
		# Retirar um ponto da rota não pode roubar um quadro e interromper a animação.
		var velocidade := 64.0 if esperar_jogador and distancia > 120 else VELOCIDADE_TUTORIAL
		var restante := velocidade * delta
		while not caminho.is_empty() and restante > 0:
			var diferenca := caminho[0] - position
			var comprimento := diferenca.length()
			if comprimento <= 0.1:
				caminho.remove_at(0)
				continue
			_linha = direcao(diferenca)
			andando = true
			var passo := minf(restante, comprimento)
			var colisao := move_and_collide(diferenca.normalized() * passo)
			restante -= passo
			if colisao != null:
				if _recalcular <= 0:
					_grid_pronta = false
					ir_ate(_alvo, esperar_jogador)
					_recalcular = 0.5
				break
			passo_dado.emit(position)
			if passo >= comprimento:
				caminho.remove_at(0)
	chegou = caminho.is_empty()
	if chegou and is_instance_valid(jogador):
		_linha = direcao(jogador.global_position - global_position)
	z_index = Profundidade.z_de(global_position.y + 9)
	sprite.frame = _linha * _colunas + (1 + int(_tempo * 11) % _quadros if andando else 0)

func parar_para_conversa() -> void:
	caminho.clear()
	chegou = true
	velocity = Vector2.ZERO
	_linha = direcao(jogador.global_position - global_position)
	sprite.frame = _linha * _colunas

static func direcao(vetor: Vector2) -> int:
	if absf(vetor.x) > absf(vetor.y):
		return 1 if vetor.x > 0 else 3
	return 0 if vetor.y >= 0 else 2
