extends SceneTree

# Cena mínima: testa a onda real, tiros, obstáculos e limpeza sem carregar a partida salva.
var _falhas := 0
var _arena: Node2D
var _jogador: JogadorTeste

class JogadorTeste extends Node2D:
	var estaMorto := false
	var invulneravel := true
	var dano_recebido := 0
	func receber_dano(dano: int, _forca: Vector2) -> void:
		dano_recebido += dano

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	_arena = Node2D.new()
	_arena.name = "cenario"
	root.add_child(_arena)
	current_scene = _arena
	_jogador = JogadorTeste.new()
	_jogador.name = "Jogador"
	_jogador.position = Vector2(1000, 1000)
	_arena.add_child(_jogador)
	var mercador := Node2D.new()
	mercador.name = "Merchant"
	_arena.add_child(mercador)
	var spawner: Node = load("res://Codigos/Logicas/slime_spawner.gd").new()
	spawner.name = "enemySpawner"
	spawner.atraso_spawn = 0.02
	spawner.add_child(Marker2D.new())
	var gerenciador: Node = load("res://Codigos/Logicas/Gerenciador-de-ondas.gd").new()
	gerenciador.name = "GerenciadorOndas"
	gerenciador.chance_onda_bonus = 0.0
	gerenciador.chance_evento = 0.0
	spawner.add_child(gerenciador)
	_arena.add_child(spawner)
	for i in 4:
		await process_frame
	await create_timer(0.1).timeout
	for onda in [17, 18, 33, 34]:
		var pool: Array = spawner.obter_pool_especies(onda)
		_verificar("onda %d usa somente os três esqueletos" % onda, pool.size() == 3 and pool.all(func(c): return c.resource_path.get_file().begins_with("esqueleto_")))
	var rodadas_ok := true
	for rodada in 20:
		var vistos := {}
		for i in 3:
			vistos[spawner._sortear_especie(17).resource_path] = true
		rodadas_ok = rodadas_ok and vistos.size() == 3
	_verificar("cada rodada traz as três classes antes de repetir", rodadas_ok)
	gerenciador.onda_atual = 17
	gerenciador.iniciar_onda()
	await create_timer(0.9).timeout
	var classes := {}
	for inimigo in get_nodes_in_group("enemy"):
		classes[inimigo.scene_file_path] = true
		_verificar("esqueleto recebe drops e contagem da onda", inimigo.get_signal_connection_list("inimigo_morreu").size() == 3)
	_verificar("onda real começa com guerreiro, arqueiro e mago", classes.size() == 3)
	var total: int = gerenciador.total_inimigos_onda
	var tentativas := 0
	while gerenciador.onda_em_andamento and tentativas < 60:
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and not inimigo.esta_morto:
				inimigo.receber_dano(99999)
		await create_timer(0.2).timeout
		tentativas += 1
	_verificar("onda termina após os abates de todas as classes", not gerenciador.onda_em_andamento and gerenciador.onda_atual == 18)
	_verificar("todos os esqueletos contam como abate", root.get_node("Progresso").abates == total)
	gerenciador.parar_ondas()
	await process_frame
	await _testar_tiros()
	print("Falhas: ", _falhas)
	quit(_falhas)

func _testar_tiros() -> void:
	_jogador.position = Vector2(120, 0)
	var area := Area2D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	var colisao := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 8.0
	colisao.shape = forma
	area.add_child(colisao)
	_jogador.add_child(area)
	var roteiro = load("res://Codigos/Inimigos/projetil_esqueleto.gd")
	for tipo in ["arqueiro", "mago"]:
		var inimigo: Node2D = load("res://cenas/inimigos/esqueleto_%s.tscn" % tipo).instantiate()
		_arena.add_child(inimigo)
		inimigo.set_physics_process(false)
		var antes := _jogador.dano_recebido
		var tiros := [0]
		inimigo.child_entered_tree.connect(func(filho):
			if filho.get_script() == roteiro:
				tiros[0] += 1
		)
		inimigo._iniciar_ataque(Vector2.RIGHT)
		await create_timer(1.8).timeout
		_verificar(tipo + " dispara no ataque e causa dano uma vez", tiros[0] == 1 and _jogador.dano_recebido == antes + inimigo.obter_dano())
		inimigo.free()
	var parado: Node2D = load("res://cenas/inimigos/esqueleto_arqueiro.tscn").instantiate()
	_jogador.position = Vector2(60, 0)
	_arena.add_child(parado)
	parado.pode_atacar = false
	await create_timer(0.4).timeout
	_verificar("arqueiro parado na distância de tiro usa repouso, sem pedalar", parado.get_real_velocity().length() < 1.5 and parado.sprite.frame == 2)
	parado.free()
	_jogador.position = Vector2(120, 0)
	var parede := StaticBody2D.new()
	parede.collision_layer = 64
	parede.position = Vector2(60, 0)
	var forma_parede := RectangleShape2D.new()
	forma_parede.size = Vector2(6, 80)
	var colisao_parede := CollisionShape2D.new()
	colisao_parede.shape = forma_parede
	parede.add_child(colisao_parede)
	_arena.add_child(parede)
	await physics_frame
	await physics_frame
	for tipo in ["flecha", "magia"]:
		var antes := _jogador.dano_recebido
		var tiro: Node2D = roteiro.new()
		tiro.tipo = tipo
		tiro.dano = 9
		tiro.alvo = _jogador
		tiro.destino = _jogador.position
		_arena.add_child(tiro)
		_verificar(tipo + " usa sprite com filtro de pixels nítidos", tiro._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and tiro._sprite.texture != null)
		if tipo == "magia":
			_verificar("esfera usa três quadros do efeito Mana Seed", tiro._sprite.hframes == 3 and tiro._sprite.texture is AtlasTexture)
		else:
			_verificar("flecha usa o mesmo asset do arco do jogador", tiro._sprite.texture.resource_path == "res://CharacterSprites/Arco/flecha.png")
		await create_timer(0.8).timeout
		_verificar(tipo + " para no obstáculo sem atingir o jogador", not is_instance_valid(tiro) and _jogador.dano_recebido == antes)
	var arqueiro: Node2D = load("res://cenas/inimigos/esqueleto_arqueiro.tscn").instantiate()
	_arena.add_child(arqueiro)
	arqueiro._iniciar_ataque(Vector2.RIGHT)
	_verificar("arqueiro não começa um tiro através de uma parede", not arqueiro.esta_atacando)
	await physics_frame
	await physics_frame
	_verificar("arqueiro aproxima-se para buscar visada", arqueiro.raio_parada == 7.0)
	arqueiro.free()
	parede.free()
