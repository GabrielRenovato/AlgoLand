extends SceneTree

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Teste requer saves isolados.")
		quit(1)
		return
	var inventario := root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	var arena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador = arena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador._arvore_animacao.active = false
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	arena.add_child(chefe)
	chefe.set_physics_process(false)
	chefe.global_position = Vector2(4000, 4000)
	chefe.vida = 10000
	chefe.vida_maxima = 10000
	verificar("área de acerto separada do movimento e contato", chefe.collision_layer == 0 and chefe._area_dano.collision_layer == 4 and not chefe.get_node("ataque").monitoring)
	verificar("área de acerto não vira segundo inimigo no grupo", not chefe._area_dano.is_in_group("enemy"))
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.collision_mask = 4
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = true
	for linha in 4:
		chefe._linha = linha
		chefe._tocar_quadro("movimento", 0)
		var ponto := _ponto_corpo(chefe)
		await physics_frame
		await physics_frame
		consulta.position = ponto
		var encontrados: Array = chefe.get_world_2d().direct_space_state.intersect_point(consulta)
		verificar("vista %d recebe golpes no corpo acima dos pés" % linha, encontrados.any(func(resultado): return resultado.collider == chefe._area_dano) and ponto.y < chefe.global_position.y - 20)
		consulta.position = chefe.sprite.to_global(Vector2(-62, -62))
		verificar("vista %d não acerta o canto transparente da folha" % linha, chefe.get_world_2d().direct_space_state.intersect_point(consulta).is_empty())
		for arma in ["espada", "lanca"]:
			var vida_antes: int = chefe.vida
			if arma == "espada":
				jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1", 2.0)
			else:
				jogador.iniciar_slash_ataque_lanca("AtaqueLancaSlash_2", 2.0)
			# Usa a AreaAtaque real e seus sinais, com uma sonda curta no corpo.
			var ataque: Area2D = jogador.get_node("AreaAtaque")
			var forma: CollisionShape2D = ataque.get_node("CollisionShape2D")
			forma.shape = CircleShape2D.new()
			forma.shape.radius = 3
			forma.position = Vector2.ZERO
			forma.scale = Vector2.ONE
			forma.disabled = false
			ataque.global_position = ponto
			await physics_frame
			await physics_frame
			await process_frame
			verificar("%s acerta pela área real na vista %d" % [arma, linha], chefe.vida < vida_antes)
			var vida_apos: int = chefe.vida
			jogador._on_area_entrou_area_ataque(chefe._area_dano)
			verificar("%s não duplica dano na mesma habilidade" % arma, chefe.vida == vida_apos)
			ataque.monitoring = false
			ataque.global_position = jogador.global_position
			await physics_frame
			await physics_frame
		var vida_antes_flecha: int = chefe.vida
		var flecha = load("res://Codigos/Jogador/flecha.gd").new()
		arena.add_child(flecha)
		flecha.iniciar(jogador, Vector2.RIGHT)
		flecha.global_position = ponto - Vector2(30, 0)
		await create_timer(0.2).timeout
		verificar("flecha em movimento acerta o corpo na vista %d" % linha, chefe.vida < vida_antes_flecha and not is_instance_valid(flecha))
		var vida_antes_escudo: int = chefe.vida
		jogador.global_position = ponto
		jogador.defesa.direcao_guarda = Vector2.RIGHT
		jogador.defesa._impacto_escudada()
		verificar("escudada considera o corpo visível na vista %d" % linha, chefe.vida < vida_antes_escudo)
	var contornos_validos := true
	for pagina in ["movimento", "sopro", "cauda", "asas", "voo", "patada"]:
		for linha in 4:
			chefe._linha = linha
			for quadro in 6:
				chefe._tocar_quadro(pagina, quadro)
				contornos_validos = contornos_validos and chefe._contorno_dano.polygon.size() >= 3 and chefe._area_dano.position == chefe.sprite.position
	verificar("área de acerto acompanha todos os 144 quadros", contornos_validos)
	chefe.queue_free()
	await process_frame
	arena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)

func _ponto_corpo(chefe: Node2D) -> Vector2:
	var imagem: Image = chefe.sprite.texture.get_image()
	var linha: int = chefe._linha
	for raio in 32:
		for y in range(64 - raio, 65 + raio):
			for x in range(64 - raio, 65 + raio):
				if imagem.get_pixel(x, linha * 128 + y).a > 0 and imagem.get_pixel(x + 2, linha * 128 + y).a > 0 and imagem.get_pixel(x, linha * 128 + y + 2).a > 0:
					return chefe.sprite.to_global(Vector2(x - 64, y - 64))
	return chefe.global_position
