extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_inimigos_presos.gd [-- completo] [-- diag]
# Sem argumento roda o caso rápido (os tipos mais difíceis, com o jogador no acampamento); "completo" roda todos os tipos, normais e mutantes,
# com o jogador em três lugares (uns 12 minutos).
# Inimigos de chão presos em obstáculos (árvores, lago, pedras, barraca, fogueira...): para cada tipo (normal e mutante) solta uma
# leva de inimigos em pontos espalhados da arena, com o jogador parado em lugares diferentes, deixa perseguirem e confere que todos
# chegam perto dele. Com "diag" imprime onde ficou preso quem não chegou.
# ATENCAO: carrega a cena de jogo (pode regravar user://inventario.json); faça backup do user:// antes.

const TIPOS_COMPLETO := ["slime", "caranguejo", "gremlin", "cogumelo", "mimico", "flor", "golem"]
const TIPOS_RAPIDO := ["caranguejo", "gremlin", "cogumelo", "flor", "golem"]
const PASSO_AMOSTRA := 44.0
const TEMPO_SIMULADO := 14.0
## Preso = andou menos que MOVIMENTO_MINIMO nos últimos JANELA_PRESO segundos, ainda longe do jogador e sem estar levando empurrão
const JANELA_PRESO := 4.0
const MOVIMENTO_MINIMO := 8.0
const DISTANCIA_CHEGOU := 64.0
## Quem pareceu preso é conferido de novo depois deste tempo: parada de um instante (empurrão da multidão, tropeço na quina) não conta
const RECONFERENCIA := 3.0
const MAX_INIMIGOS := 24

var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _diag := false

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _rodar() -> void:
	_diag = "diag" in OS.get_cmdline_user_args()
	await process_frame
	root.get_node("Progresso").caminho_save = "user://teste_presos_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_presos_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	for i in 12:
		await process_frame
	await create_timer(0.3).timeout
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	_jogador.invulneravel = true
	_jogador.temporizador_invul = 100000.0
	_jogador.movimento_habilitado = false
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	var terreno: Node = _cena.get_node("Terrains")
	var contorno := terreno.get_node("LimiteArena/Contorno") as CollisionPolygon2D
	var poligono := contorno.polygon
	var caixa := Rect2(poligono[0], Vector2.ZERO)
	for p in poligono:
		caixa = caixa.expand(p)
	var mapa: RID = terreno.get_node("Navegacao").get_navigation_map()
	print("arena: ", caixa)
	# Pontos válidos de largada (dentro da área navegável) e posições do jogador
	var pontos: Array[Vector2] = []
	var y := caixa.position.y
	while y < caixa.end.y:
		var x := caixa.position.x
		while x < caixa.end.x:
			var candidato := contorno.global_transform * Vector2(x, y)
			var fecho := NavigationServer2D.map_get_closest_point(mapa, candidato)
			if fecho.distance_to(candidato) < 1.5:
				pontos.append(candidato)
			x += PASSO_AMOSTRA
		y += PASSO_AMOSTRA
	print("pontos de largada validos: ", pontos.size())
	var posicoes_jogador: Array[Vector2] = [_jogador.global_position]
	# Mais dois lugares do jogador: nos cantos opostos do mapa navegável
	var mais_longe: Vector2 = pontos[0]
	var mais_perto_do_fim: Vector2 = pontos[0]
	for p in pontos:
		if p.x + p.y < mais_longe.x + mais_longe.y:
			mais_longe = p
		if p.x + p.y > mais_perto_do_fim.x + mais_perto_do_fim.y:
			mais_perto_do_fim = p
	posicoes_jogador.append(mais_longe)
	posicoes_jogador.append(mais_perto_do_fim)
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = 4242
	var total_presos := 0
	var completo := "completo" in OS.get_cmdline_user_args()
	for tipo in (TIPOS_COMPLETO if completo else TIPOS_RAPIDO):
		for mutante in ([false, true] if completo else ([false] if tipo == "golem" else [true])):
			if tipo == "golem" and mutante:
				continue   # o golem já é chefe
			for destino in (posicoes_jogador if completo else posicoes_jogador.slice(0, 1)):
				var presos := await _simular(tipo, mutante, destino, pontos, sorteio)
				total_presos += presos
	_verificar("nenhum inimigo de chão fica preso em obstáculo (presos: %d)" % total_presos, total_presos == 0, "")
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	print("--- teste_inimigos_presos: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)

func _simular(tipo: String, mutante: bool, destino: Vector2, pontos: Array[Vector2], sorteio: RandomNumberGenerator) -> int:
	_jogador.global_position = destino
	var cena_inimigo: PackedScene = load("res://cenas/inimigos/%s.tscn" % tipo)
	var lista: Array[Node2D] = []
	var largadas: Array[Vector2] = []
	var candidatos := pontos.duplicate()
	candidatos.shuffle()
	for p in candidatos:
		if lista.size() >= MAX_INIMIGOS:
			break
		if p.distance_to(destino) < DISTANCIA_CHEGOU * 2.0:
			continue
		var inimigo: Node2D = cena_inimigo.instantiate()
		_cena.add_child(inimigo)
		inimigo.global_position = p
		if mutante:
			inimigo.tornar_mutante()
		lista.append(inimigo)
		largadas.append(p)
	var inicio := Time.get_ticks_msec()
	var fim := inicio + int(TEMPO_SIMULADO * 1000.0)
	var antes: Array[Vector2] = []
	var fotografou := false
	while Time.get_ticks_msec() < fim:
		await physics_frame
		_jogador.global_position = destino
		if not fotografou and Time.get_ticks_msec() >= fim - int(JANELA_PRESO * 1000.0):
			fotografou = true
			for inimigo in lista:
				antes.append(inimigo.global_position if is_instance_valid(inimigo) else Vector2.INF)
	var suspeitos: Array[int] = []
	var onde: Array[Vector2] = []
	for i in lista.size():
		var inimigo := lista[i]
		if not is_instance_valid(inimigo) or inimigo.esta_morto or inimigo.global_position.distance_to(destino) <= DISTANCIA_CHEGOU:
			continue
		if inimigo.global_position.distance_to(antes[i]) < MOVIMENTO_MINIMO:
			suspeitos.append(i)
			onde.append(inimigo.global_position)
	var retomada := Time.get_ticks_msec() + int(RECONFERENCIA * 1000.0)
	while not suspeitos.is_empty() and Time.get_ticks_msec() < retomada:
		await physics_frame
		_jogador.global_position = destino
	var presos := 0
	for k in suspeitos.size():
		var i := suspeitos[k]
		var inimigo := lista[i]
		if not is_instance_valid(inimigo) or inimigo.esta_morto or inimigo.global_position.distance_to(destino) <= DISTANCIA_CHEGOU:
			continue
		if inimigo.global_position.distance_to(onde[k]) < MOVIMENTO_MINIMO:
			presos += 1
			if _diag:
				var vizinhos := 0
				for outro in lista:
					if outro != inimigo and is_instance_valid(outro) and outro.global_position.distance_to(inimigo.global_position) < 60.0:
						vizinhos += 1
				var tocando := ""
				for k2 in inimigo.get_slide_collision_count():
					tocando += " " + str(inimigo.get_slide_collision(k2).get_collider().name)
				print("  PRESO %s%s: largou em %s, parou em %s (jogador em %s), %d vizinhos a menos de 60 px, tocando:%s" % [tipo, " mutante" if mutante else "", largadas[i].round(), inimigo.global_position.round(), destino.round(), vizinhos, tocando])
	print("%s%s -> jogador em %s: %d de %d presos" % [tipo, " mutante" if mutante else "", destino.round(), presos, lista.size()])
	for inimigo in lista:
		if is_instance_valid(inimigo):
			inimigo.queue_free()
	await process_frame
	return presos
