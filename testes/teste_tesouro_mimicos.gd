extends SceneTree

var falhas := 0
var capturar := false

func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-tesouro-" + nome + ".png")

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	var premios = load("res://codigo/fendas/premios_tesouro.gd")
	root.get_node("Progresso").apagar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("BauCasa")._limpar()
	var rng := RandomNumberGenerator.new()
	rng.seed = 70419
	var raros := 0
	var validos := true
	var tipos := {}
	var categorias := {}
	for i in 20000:
		var item: DadosItem = premios.sortear_premio(rng, 20)
		if item != null:
			categorias[item.categoria]=true
			validos = validos and item.categoria in ["receita","pocao","comida","material"] and item.quantidade==1
			if item.categoria=="material": validos = validos and item.conteudo()=="moeda_forja"
			if item.categoria == "receita":
				raros += 1
				tipos[item.tipo] = true
				validos = validos and load("res://codigo/dados/conjuntos_armadura.gd").de_tipo(item.conteudo()) != null
	verificar("sorteio de 5 por cento produz apenas receitas de conjunto (%d/20000)" % raros, raros > 850 and raros < 1150 and validos and tipos.size() == 12)
	verificar("tesouro varia entre receitas, poções, comida e moedas",categorias.size()==4)
	var portais := 0
	for i in 20000:
		if rng.randf()<premios.CHANCE_PORTAL: portais+=1
	verificar("portal raro aparece perto de 2 por cento",portais>320 and portais<480)
	var prematuro := false
	for i in 1000: prematuro = prematuro or premios.sortear_premio(rng,1).categoria=="receita"
	verificar("andar inicial não adianta receitas de conjunto",not prematuro)
	var progresso := root.get_node("Progresso")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena = false
	progresso.iniciar_partida()
	progresso.portais_tesouro["1"] = "disponivel"
	change_scene_to_file("res://cenas/fendas/andar_01.tscn")
	await quadros(20)
	var gerente := current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.iniciar_onda(true)
	await quadros(15)
	var tesouro: Node = gerente.tesouro
	verificar("portal sorteado aparece na chegada do andar", is_instance_valid(tesouro.portal))
	if not is_instance_valid(tesouro.portal):
		quit(1)
		return
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.invulneravel = true
	jogador.temporizador_invul = 10000
	jogador.set_physics_process(false)
	jogador.global_position = tesouro.portal.global_position + Vector2(35,16)
	var retorno: Vector2 = jogador.global_position
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.zoom = Vector2.ONE
	jogador.camera.reset_smoothing()
	var estacoes: Node = current_scene.get_node("Terrains/Estacoes")
	if capturar: await create_timer(3.5).timeout
	var quadro_antes: int = tesouro.portal.sprite.frame_coords.y
	await create_timer(0.15).timeout
	verificar("portal anima os quadros do redemoinho", tesouro.portal.sprite.frame_coords.y != quadro_antes)
	for estacao in 4:
		estacoes.definir_estacao(estacao, true)
		await quadros()
		verificar("portal integrado à estação %d" % estacao, tesouro.portal.sprite.frame_coords.x == estacao)
		await foto("portal_" + str(estacao))
	var pontos: int = gerente.pontos
	var vivos: int = gerente.inimigos_vivos
	var andar: int = gerente.onda_atual
	var concluidas: int = progresso.ondas_concluidas
	var chefes: int = progresso.chefes
	var checkpoint: int = progresso.checkpoint_max
	var inimigo_original: Node = current_scene.get_node("enemySpawner")._populacao[0]
	var modo_original: int = inimigo_original.process_mode
	await tesouro.entrar()
	verificar("entrada consome portal e suspende combate original", tesouro.ativo and progresso.portais_tesouro["1"] == "consumido" and inimigo_original.process_mode == Node.PROCESS_MODE_DISABLED)
	verificar("sala tem mímicos e um baú gigante", tesouro.vivos.size() == 7 and tesouro.vivos[-1].eh_chefe and tesouro.vivos[-1].scale.x > 1.5)
	var gigante: Node = tesouro.vivos[-1]
	var caminho := NavigationServer2D.map_get_path(jogador.get_world_2d().navigation_map, jogador.global_position, gigante.global_position, true, 1)
	verificar("trilha do portal à clareira tem navegação contínua", caminho.size() > 1 and caminho[-1].distance_to(gigante.global_position) < 24)
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 14
	consulta.shape = forma
	consulta.collision_mask = 64
	var livres := true
	for inimigo in tesouro.vivos:
		consulta.transform = Transform2D(0, inimigo.global_position)
		livres = livres and jogador.get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()
	verificar("mímicos e baú gigante nascem fora das árvores e obstáculos", livres)
	for inimigo in tesouro.vivos: inimigo.set_physics_process(false)
	var entrada_bonus: Vector2 = jogador.global_position
	if capturar:
		jogador.camera.set_as_top_level(true)
		jogador.camera.limit_left = -100000
		jogador.camera.limit_right = 100000
		jogador.camera.limit_top = -100000
		jogador.camera.limit_bottom = 100000
		jogador.camera.global_position = Vector2(12000, 0)
		jogador.camera.zoom = Vector2(0.38,0.38)
		await create_timer(4).timeout
	for estacao in 4:
		estacoes.definir_estacao(estacao, true)
		await quadros()
		verificar("mapa do tesouro integrado à estação %d" % estacao, tesouro.sala.get_node("Estacoes").estacao_atual == estacao)
		await foto("mapa_" + str(estacao))
	if capturar:
		jogador.camera.set_as_top_level(false)
		jogador.camera.position = Vector2.ZERO
		jogador.camera.zoom = Vector2.ONE
		jogador.global_position = gigante.global_position + Vector2(70,48)
		jogador.camera.reset_smoothing()
		await foto("clareira")
		jogador.global_position = entrada_bonus
	var ouro: int = root.get_node("DadosJogo").moedas
	var mimico: Node = tesouro.vivos[0]
	# O sinal extra exercita a proteção de recompensa antes de o inimigo sair da árvore.
	mimico.inimigo_morreu.connect(func(): tesouro._premiar(mimico, false))
	mimico.receber_dano(999999)
	await mimico.tree_exited
	verificar("mímico dá cinco vezes o ouro comum", root.get_node("DadosJogo").moedas - ouro == gerente.ouro_por_abate(andar) * 5)
	var ouro_depois: int = root.get_node("DadosJogo").moedas
	verificar("recompensa não se repete", root.get_node("DadosJogo").moedas == ouro_depois)
	# Exercita a recompensa elegível sem alterar a população carregada pelo teste.
	tesouro._andar = 20
	for semente in 100:
		rng.seed = semente
		if premios.sortear_premio(rng, 20).categoria == "receita":
			tesouro._rng.seed = semente
			break
	gigante.receber_dano(999999)
	await gigante.tree_exited
	verificar("baú gigante não altera checkpoint nem chefes do andar", progresso.chefes == chefes and progresso.checkpoint_max == checkpoint)
	var premio_no_chao: Node
	for drop in get_nodes_in_group("equipamento_drop"):
		if tesouro.sala.is_ancestor_of(drop): premio_no_chao = drop
	verificar("acertar os 5 por cento solta pergaminho no chão", is_instance_valid(premio_no_chao) and premio_no_chao.item.categoria == "receita")
	if is_instance_valid(premio_no_chao): premio_no_chao.set_process(false)
	tesouro._andar = andar
	await tesouro.sair()
	await quadros()
	verificar("retorno preserva andar, população e progresso", gerente.onda_atual == andar and gerente.pontos == pontos and gerente.inimigos_vivos == vivos and progresso.ondas_concluidas == concluidas)
	verificar("retorno restaura jogador e inimigos", jogador.global_position.is_equal_approx(retorno) and inimigo_original.process_mode == modo_original and not tesouro.ativo)
	verificar("portal consumido não permite outra entrada", not tesouro.pode_entrar())
	verificar("retorno preserva prêmio sem espaço para coleta", is_instance_valid(premio_no_chao) and premio_no_chao.get_parent() == current_scene)
	# Forçar uma segunda oportunidade apenas no teste para conferir a viagem conjunta.
	root.get_node("Cooperativo").entrar(99)
	await quadros(20)
	var p2: Node2D = root.get_node("Cooperativo").jogador2()
	p2.set_physics_process(false)
	p2.invulneravel = true
	p2.temporizador_invul = 10000
	var retorno_p2 := p2.global_position
	progresso.portais_tesouro["1"] = "disponivel"
	await tesouro.entrar()
	for inimigo in tesouro.vivos: inimigo.set_physics_process(false)
	verificar("coop viaja junto para a sala bônus", jogador.global_position.x > 10000 and p2.global_position.x > 10000 and jogador.global_position.distance_to(p2.global_position) < 96)
	await foto("coop")
	await tesouro.sair()
	verificar("coop retorna às posições originais", jogador.global_position.is_equal_approx(retorno) and p2.global_position.is_equal_approx(retorno_p2))
	gerente.parar_ondas()
	root.get_node("Cooperativo").sair()
	current_scene.queue_free()
	await quadros()
	print("Tesouro dos mímicos: %d falhas" % falhas)
	quit(1 if falhas else 0)
