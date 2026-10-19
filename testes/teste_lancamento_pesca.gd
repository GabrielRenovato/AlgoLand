extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func mouse(apertado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = apertado
	evento.position = Vector2(400,180)
	Input.parse_input_event(evento)
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var jogador = current_scene.get_node("Jogador")
	var ponto = current_scene.get_node("PescaPierLeste")
	jogador.global_position = ponto.global_position
	var inventario = root.get_node("InventarioJogador")
	jogador.troca_sem_pose = true
	inventario.equipar(inventario.buscar_por_tipo("espada_basica"))
	Input.action_press("move_right")
	jogador.velocity = Vector2.ZERO
	for i in 30: jogador.mover()
	var velocidade_armado: float = jogador.velocity.length()
	root.get_node("InventarioJogador").definir_vara_na_mao(true)
	jogador.velocity = Vector2.ZERO
	for i in 30: jogador.mover()
	verificar("selecionar vara na praia preserva velocidade",velocidade_armado > 100 and is_equal_approx(jogador.velocity.length(),velocidade_armado))
	jogador.animar()
	jogador._arvore_animacao.advance(0.3)
	verificar("vara selecionada usa animação de corrida",jogador._maquina_estados.get_current_node() == "running")
	if "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-corrida-com-vara.png")
	inventario.desequipar("arma")
	inventario.definir_vara_na_mao(false)
	jogador.velocity = Vector2.ZERO
	for i in 30: jogador.mover()
	verificar("mãos vazias preservam velocidade",is_equal_approx(jogador.velocity.length(),velocidade_armado))
	jogador.animar()
	jogador._arvore_animacao.advance(0.3)
	verificar("mãos vazias usam animação de corrida",jogador._maquina_estados.get_current_node() == "running")
	Input.action_release("move_right")
	jogador.velocity = Vector2.ZERO
	inventario.definir_vara_na_mao(true)
	jogador.troca_sem_pose = false
	await quadros()
	Input.action_press("open_menu")
	await quadros(2)
	Input.action_release("open_menu")
	verificar("F não inicia pesca nem exibe aviso antigo",not jogador.has_node("SessaoPesca") and not ponto._aviso.visible)
	mouse(true)
	await quadros(4)
	var sessao = jogador.get_node_or_null("SessaoPesca")
	verificar("mouse esquerdo inicia carregamento",sessao != null and sessao.estado == sessao.Estado.CARREGANDO and not jogador.movimento_habilitado)
	if sessao == null: quit(1); return
	await create_timer(0.55).timeout
	verificar("segurar aumenta a força",sessao.forca_lancamento > 0.4)
	if "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-pesca-forca.png")
	mouse(false)
	await quadros(2)
	verificar("soltar lança a linha",sessao.estado == sessao.Estado.LANCANDO)
	var alcance: float = (sessao._alvo-Vector2(0,14)).length()
	verificar("força muda distância real da boia",alcance > 64 and alcance < 120)
	sessao._terminar()
	await quadros()
	mouse(true)
	await quadros(2)
	sessao = jogador.get_node("SessaoPesca")
	mouse(false)
	await quadros(2)
	verificar("clique rápido lança mais perto",(sessao._alvo-Vector2(0,14)).length() < alcance)
	sessao._terminar()
	await quadros()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	jogador = current_scene.get_node("Jogador")
	jogador.global_position = current_scene.get_node("PescaLago").global_position
	await quadros()
	root.get_node("InventarioJogador").definir_vara_na_mao(true)
	mouse(true)
	await quadros(3)
	sessao = jogador.get_node_or_null("SessaoPesca")
	verificar("mesmo botão carrega na fazenda sem usar ferramenta",sessao != null and not jogador.esta_em_acao_fazenda)
	if sessao != null:
		sessao.forca_lancamento = 1.0
		sessao._lancar()
		mouse(false)
		var lago = current_scene.get_node("Terrains/Lago")
		verificar("força máxima mantém boia dentro do lago",Geometry2D.is_point_in_polygon(lago.to_local(jogador.to_global(sessao._alvo)),lago.poligono))
		sessao._terminar()
	await quadros()
	verificar("encerrar devolve movimento e ataques",jogador.movimento_habilitado and not jogador.ataques_bloqueados)
	print("FALHAS: ",falhas)
	quit(falhas)
