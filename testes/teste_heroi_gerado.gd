extends SceneTree

var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar.call_deferred()

func _conferir(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)

func _quadros(n := 5) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Teste exige saves isolados.")
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(320, 180)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await _quadros(20)
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var aparencia := [jogador.cabelo_atual, jogador.roupa_atual]
	var painel := root.get_node("PainelDebug")
	var corpo := jogador.get_node("CompositeSprites")
	painel._ativar_heroi_gerado(false)
	var visual := jogador.get_node("HeroiGerado")
	visual.set_process(false)
	_conferir(visual.visible and not corpo.visible, "F3 ativa o personagem gerado")
	_conferir(is_equal_approx(visual.scale.x, 1.0 / 16.0), "Escala aparente de 34 unidades")
	jogador.velocity = Vector2(64, 0)
	for i in 6:
		visual._em_movimento = true
		visual._estado_visual = visual.EstadoVisual.MOVENDO
		visual._tempo_ms = i * 160.0
		visual._process(0.0)
		_conferir(visual.frame == i, "Caminhada mostra quadro %d" % i)
	jogador._direcao_ataque = Vector2.LEFT
	visual._process(0.0)
	_conferir(visual.flip_h and visual.visible, "Esquerda espelha a arte")
	jogador._direcao_ataque = Vector2.UP
	visual._process(0.0)
	_conferir(not visual.visible and corpo.visible, "Direção vertical usa a base existente")
	jogador._direcao_ataque = Vector2.RIGHT
	jogador.esta_em_acao_fazenda = true
	visual._process(0.0)
	_conferir(not visual.visible and corpo.visible, "Ferramentas usam a animação existente")
	jogador.esta_em_acao_fazenda = false
	painel._ativar_heroi_gerado(true)
	_conferir(jogador.get_node("HeroiGerado") == visual and visual.correndo, "F3 troca para correr sem duplicar o personagem")
	var tempo := 0.0
	for i in 9:
		visual._em_movimento = true
		visual._estado_visual = visual.EstadoVisual.MOVENDO
		visual._tempo_ms = tempo
		visual._process(0.0)
		_conferir(visual.frame == i, "Corrida mostra quadro %d" % i)
		tempo += visual.DURACOES_CORRIDA[i]
	_conferir(tempo == 640.0, "Corrida preserva a duração e inclui o braço abaixando")
	for direcao in [Vector2.UP, Vector2.DOWN]:
		jogador._direcao_ataque = direcao
		visual._em_movimento = true
		visual._estado_visual = visual.EstadoVisual.MOVENDO
		visual._tempo_ms = 520.0
		visual._process(0.0)
		_conferir(visual.visible and not corpo.visible, "Corrida vertical mantém o personagem gerado")
		var nome := "cima" if direcao.y < 0 else "baixo"
		_conferir(visual.texture.resource_path.ends_with("correr_" + nome + ".png"), "Folha de corrida para " + nome)
		_conferir(not visual.flip_h and visual.frame == 7, "Virar preserva a fase do braço e evita espelho vertical")
		for i in 9:
			var acumulado := 0
			var duracoes: Array = visual.DURACOES_CORRIDA_BAIXO if direcao.y > 0 else visual.DURACOES_CORRIDA
			for anterior in i:
				acumulado += duracoes[anterior]
			visual._tempo_ms = acumulado
			visual._process(0.0)
			_conferir(visual.frame == i, "Corrida %s mostra pose %d" % [nome, i])
		if direcao.y > 0:
			for instante in [160.0, 520.0]:
				visual._tempo_ms = instante
				visual._process(0.0)
				_conferir(visual.frame in [2, 7], "Braços passam pela pose baixa nas duas trocas")
	_testar_idle(jogador, visual)
	_testar_espada(jogador, visual, painel)
	jogador._direcao_ataque = Vector2.RIGHT
	# Exercita a função real de movimento com o input do jogo, sem mover o corpo pela física.
	Input.action_press("move_right")
	jogador.velocity = Vector2.ZERO
	for i in 80:
		jogador.mover()
	var velocidade_corrida: float = jogador.velocity.length()
	painel._ativar_heroi_gerado(false)
	jogador.velocity = Vector2.ZERO
	for i in 80:
		jogador.mover()
	_conferir(velocidade_corrida > jogador.velocity.length(), "Andar e correr aplicam velocidades distintas")
	Input.action_release("move_right")
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	var luz := current_scene.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	var camera := Camera2D.new()
	camera.position = Vector2(376, 244)
	current_scene.add_child(camera)
	camera.make_current()
	jogador.position = Vector2(376, 256)
	jogador.velocity = Vector2(64, 0)
	visual._em_movimento = true
	visual._estado_visual = visual.EstadoVisual.MOVENDO
	visual._tempo_ms = 0.0
	visual._process(0.0)
	await _quadros()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/personagens/exemplo_alta_qualidade/"))
	root.get_texture().get_image().save_png("res://arte/previas/personagens/exemplo_alta_qualidade/no_jogo.png")
	# Captura os dois contatos laterais no cenário para revisar qual perna avança.
	for corrida in [false, true]:
		painel._ativar_heroi_gerado(corrida)
		visual.set_process(false)
		for direcao in [Vector2.RIGHT, Vector2.LEFT]:
			jogador._direcao_ataque = direcao
			jogador.velocity = direcao * 64.0
			for metade in 2:
				visual._em_movimento = true
				visual._estado_visual = visual.EstadoVisual.MOVENDO
				visual._tempo_ms = metade * (320.0 if corrida else 480.0)
				visual._process(0.0)
				await _quadros(2)
				await RenderingServer.frame_post_draw
				var acao := "correr" if corrida else "andar"
				var lado := "direita" if direcao.x > 0 else "esquerda"
				root.get_texture().get_image().save_png("res://arte/previas/personagens/exemplo_alta_qualidade/%s_%s_contato_%d.png" % [acao, lado, metade])
	if "--capturar-ciclos" in OS.get_cmdline_user_args():
		var pasta := "/tmp/algoland-bracos-no-jogo/"
		DirAccess.make_dir_recursive_absolute(pasta)
		for corrida in [false, true]:
			painel._ativar_heroi_gerado(corrida)
			visual.set_process(false)
			jogador._direcao_ataque = Vector2.RIGHT
			jogador.velocity = Vector2.RIGHT * 64.0
			var acao := "correr" if corrida else "andar"
			for quadro in (32 if corrida else 48):
				visual._em_movimento = true
				visual._estado_visual = visual.EstadoVisual.MOVENDO
				visual._tempo_ms = quadro * 40.0
				visual._process(0.0)
				await _quadros(1)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().get_region(Rect2i(350, 180, 260, 220)).save_png(pasta + "%s_%02d.png" % [acao, quadro])
	painel._ativar_heroi_gerado(true)
	visual.set_process(false)
	for direcao in [Vector2.UP, Vector2.DOWN]:
		jogador._direcao_ataque = direcao
		jogador.velocity = direcao * 114.0
		visual._em_movimento = true
		visual._estado_visual = visual.EstadoVisual.MOVENDO
		visual._tempo_ms = 0.0
		visual._process(0.0)
		await _quadros()
		await RenderingServer.frame_post_draw
		var nome := "cima" if direcao.y < 0 else "baixo"
		root.get_texture().get_image().save_png("res://arte/previas/personagens/exemplo_alta_qualidade/corrida_" + nome + "_no_jogo.png")
	if "--capturar-espada" in OS.get_cmdline_user_args():
		await _capturar_espada_no_jogo(jogador, visual)
	if "--capturar-idle" in OS.get_cmdline_user_args():
		await _capturar_idle_no_jogo(jogador, visual)
	painel._alternar_heroi_tiny()
	_conferir(jogador.has_node("HeroiTiny") and not jogador.has_node("HeroiGerado"), "Tiny substitui o protótipo gerado")
	painel._ativar_heroi_gerado(false)
	_conferir(not jogador.has_node("HeroiTiny") and jogador.has_node("HeroiGerado"), "Gerado substitui Tiny")
	painel._reaplicar_personagem()
	_conferir(not jogador.has_node("HeroiTiny") and not jogador.has_node("HeroiGerado") and corpo.visible, "Mana Seed restaura o personagem original")
	_conferir(aparencia == [jogador.cabelo_atual, jogador.roupa_atual], "Aparência salva preservada")
	print("HEROI GERADO: %d verificações, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)

func _testar_idle(jogador, visual) -> void:
	for direcao in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		visual._reiniciar_estado()
		jogador._direcao_ataque = direcao
		jogador.velocity = Vector2.ZERO
		visual._process(0.0)
		var nome := "lado" if direcao.x != 0 else ("cima" if direcao.y < 0 else "baixo")
		_conferir(visual.visible and visual.texture.resource_path.ends_with("idle_" + nome + ".png"), "Idle próprio para " + str(direcao))
		_conferir(visual.frame == 0 and visual.vframes == 2, "Idle começa apoiado, com grade 2x2")
		_conferir(visual.flip_h == (direcao == Vector2.LEFT), "Idle espelha apenas a esquerda")
		visual._process(0.7)
		_conferir(visual.frame == 1, "Idle passa pela respiração")
		visual._process(0.7)
		_conferir(visual.frame == 0, "Respiração fecha o ciclo")
		jogador.velocity = direcao * 64.0
		visual._process(0.0)
		_conferir(visual.frame == 2 and visual._estado_visual == visual.EstadoVisual.SAINDO, "Corrida sai pela preparação")
		_conferir(jogador.velocity == direcao * 64.0, "Preparação não bloqueia o deslocamento")
		visual._process(0.054)
		_conferir(visual.frame == 2, "Preparação permanece antes do impulso")
		visual._process(0.002)
		_conferir(visual.frame == 3, "Impulso vem após a preparação")
		visual._process(0.064)
		_conferir(visual._estado_visual == visual.EstadoVisual.MOVENDO and visual.frame == 0 and visual.vframes == 5, "Impulso entra na primeira passada")
		visual._process(0.64)
		_conferir(visual.frame == 0 and visual._estado_visual == visual.EstadoVisual.MOVENDO, "Preparação não repete na emenda do ciclo")
		jogador.velocity = Vector2.ZERO
		visual._process(0.0)
		_conferir(visual.frame == 3 and visual._estado_visual == visual.EstadoVisual.PARANDO, "Parada inicia a acomodação")
		visual._process(0.056)
		_conferir(visual.frame == 2, "Parada retorna à base flexionada")
		visual._process(0.064)
		_conferir(visual.frame == 0 and visual._estado_visual == visual.EstadoVisual.PARADO, "Parada termina no idle apoiado")
	visual._reiniciar_estado()
	jogador._direcao_ataque = Vector2.RIGHT
	jogador.velocity = Vector2.RIGHT * 64.0
	visual._process(0.3)
	_conferir(is_equal_approx(visual._tempo_ms, 180.0), "Delta longo conserva o tempo excedente da transição")
	visual._reiniciar_estado()
	visual._process(0.07)
	jogador._direcao_ataque = Vector2.UP
	visual._process(0.0)
	_conferir(visual.frame == 3 and is_equal_approx(visual._tempo_transicao_ms, 70.0) and visual.texture == visual._idle_cima, "Virar durante o impulso conserva a fase")
	jogador.esta_em_acao_fazenda = true
	visual._process(0.0)
	_conferir(not visual.visible and visual._estado_visual == visual.EstadoVisual.PARADO, "Ação original interrompe a transição")
	jogador.esta_em_acao_fazenda = false
	visual._process(0.02)
	jogador.velocity = Vector2.ZERO
	visual._process(0.0)
	_conferir(visual.frame == 2, "Toque curto não inventa um impulso depois de parar")
	visual._process(0.08)
	_conferir(visual.frame == 0, "Toque curto volta ao idle")
	jogador.velocity = Vector2.UP * 64.0
	visual._process(0.12)
	jogador.velocity = Vector2.ZERO
	visual._process(0.02)
	jogador.velocity = Vector2.UP * 64.0
	visual._process(0.0)
	_conferir(visual.frame == 3 and visual._estado_visual == visual.EstadoVisual.SAINDO, "Retomar durante a parada conserva o impulso")

func _capturar_idle_no_jogo(jogador, visual) -> void:
	var saida := "res://arte/previas/personagens/exemplo_alta_qualidade/idle_transicao/"
	var pasta := "/tmp/algoland-idle-fazenda/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	DirAccess.make_dir_recursive_absolute(pasta)
	for nome in ["direita", "esquerda", "baixo", "cima"]:
		var direcao: Vector2 = {"direita": Vector2.RIGHT, "esquerda": Vector2.LEFT, "baixo": Vector2.DOWN, "cima": Vector2.UP}[nome]
		visual._reiniciar_estado()
		jogador._direcao_ataque = direcao
		for quadro in 100:
			var tempo := quadro * 40
			jogador.velocity = direcao * 114.0 if tempo >= 1400 and tempo < 2800 else Vector2.ZERO
			visual._process(0.0 if quadro == 0 else 0.04)
			await _quadros(1)
			await RenderingServer.frame_post_draw
			var imagem := root.get_texture().get_image()
			imagem.get_region(Rect2i(350, 180, 260, 220)).save_png(pasta + "%s_%03d.png" % [nome, quadro])
			if tempo in [0, 1400, 1480, 1520, 2800, 2880, 2920]:
				imagem.save_png(saida + "%s_etapa_%04d_no_jogo.png" % [nome, tempo])

func _testar_espada(jogador, visual, painel) -> void:
	var usando: bool = jogador.usando_espada
	var modo: bool = jogador.modo_fazenda
	var bloqueio: int = jogador._sem_acao_ate_ms
	jogador.usando_espada = true
	jogador.velocity = Vector2.ZERO
	var area = jogador.get_node("AreaAtaque")
	var colisao = area.get_node("CollisionShape2D")
	var id_arma: int = visual._espada_sprite.get_instance_id()
	for direcao in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		jogador._direcao_ataque = direcao
		jogador._esta_atacando = true
		visual.iniciar_ataque_espada(0.3)
		var forma = colisao.shape
		var posicao: Vector2 = colisao.position
		var monitorando: bool = area.monitoring
		var fases: Array = visual.FASES_ESPADA_DIREITA if direcao == Vector2.RIGHT else visual.FASES_ESPADA
		for i in fases.size():
			visual._tempo_espada_ms = fases[i] * 300.0 + 0.01
			visual._process(0.0)
			_conferir(visual.visible and visual.frame == i and visual.vframes == (5 if direcao == Vector2.RIGHT else 3), "Espada mostra pose %d em %s" % [i, direcao])
			if direcao == Vector2.RIGHT:
				_conferir(not visual._espada_sprite.visible and not visual._mao_espada.visible and not visual._rastro_espada.visible and not visual._borda_rastro.visible, "Ataque direito usa apenas a arma já desenhada na mão, sem sobreposição")
				continue
			var vista := "lado" if direcao.x != 0 else ("cima" if direcao.y < 0 else "baixo")
			var ponto: Array = visual._encaixes_espada[vista][i]
			var mao := Vector2(ponto[0], ponto[1]) - Vector2(512, 704)
			if direcao == Vector2.LEFT:
				mao.x = -mao.x
			_conferir(visual._espada_sprite.get_instance_id() == id_arma and visual._espada_sprite.texture.resource_path.ends_with("espada_arma.png"), "Uma única espada em todos os quadros e direções")
			_conferir(visual._espada_sprite.position.distance_to(mao) < 0.01, "Cabo permanece no encaixe da mesma mão")
			if direcao.y != 0:
				_conferir((ponto[0] > 512) == (direcao.y < 0), "Mão direita mantém o lado anatômico de frente/costas")
		var nome := "direita" if direcao == Vector2.RIGHT else ("lado" if direcao.x != 0 else ("cima" if direcao.y < 0 else "baixo"))
		_conferir(visual.texture.resource_path.ends_with("espada_" + nome + ".png"), "Espada carrega a vista correta")
		_conferir(visual.flip_h == (direcao == Vector2.LEFT), "Espada espelha só para esquerda")
		_conferir(colisao.shape == forma and colisao.position == posicao and area.monitoring == monitorando, "Renderização não substitui a área de dano")
		jogador._direcao_ataque = -direcao
		visual._process(0.0)
		_conferir(visual._direcao_espada == direcao, "Golpe conserva direção até terminar")
		jogador._esta_atacando = false
		visual._process(0.0)
		_conferir(not visual._espada_ativa and not visual._espada_sprite.visible and visual.frame == 0 and visual.vframes == 2, "Fim do ataque retorna ao idle")
	# Exercita o ponto de entrada real, com a direção definida pela mira do jogo.
	jogador.modo_fazenda = false
	jogador._fase_combo = 1
	jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1", 0.3)
	jogador._temporizador.stop()
	_conferir(visual._espada_ativa and not visual._espada_demonstracao and is_equal_approx(visual._duracao_espada_ms, 300.0), "Ataque real inicia arte sincronizada ao temporizador")
	_conferir(visual._direcao_espada == jogador._direcao_ataque and area.monitoring, "Mira e área de combate continuam no sistema original")
	jogador.ataque_enfileirado = true
	jogador._on_temporizador_ataque_timeout()
	jogador._temporizador.stop()
	visual._process(0.0)
	_conferir(jogador._fase_combo == 2 and visual._combo_espada == 2 and visual.frame == 2, "Combo reinicia visual pelo contato, sem antecipação fora da janela")
	jogador.ataque_enfileirado = false
	jogador._on_temporizador_ataque_timeout()
	visual._process(0.0)
	_conferir(not jogador._esta_atacando and not area.monitoring and not visual._espada_ativa, "Fim real encerra arte e combate")
	# A opção de fazenda é apenas demonstração; não equipa arma nem liga colisão.
	jogador.modo_fazenda = true
	jogador._sem_acao_ate_ms = 0
	painel._ativar_espada_gerada()
	visual.set_process(false)
	var evento := InputEventAction.new()
	evento.action = jogador.acao_evento("attack")
	evento.pressed = true
	visual._unhandled_input(evento)
	visual._process(0.0)
	var ataque_direita: bool = absf(jogador._direcao_ataque.x) > absf(jogador._direcao_ataque.y) and jogador._direcao_ataque.x > 0
	_conferir(visual.teste_espada and visual._espada_demonstracao and visual.vframes == (5 if ataque_direita else 3), "F3 permite demonstrar espada pelo botão de ataque")
	_conferir(not jogador._esta_atacando and not area.monitoring, "Prévia de fazenda não causa dano")
	visual._unhandled_input(evento)
	visual._process(0.3)
	_conferir(visual._espada_ativa and visual._combo_espada == 2, "Prévia aceita o próximo golpe enfileirado")
	visual._process(0.31)
	_conferir(not visual._espada_ativa and visual.vframes == 2, "Prévia encerra e volta ao idle")
	visual.iniciar_ataque_espada(0.3, true)
	jogador.esta_em_acao_fazenda = true
	visual._process(0.0)
	_conferir(not visual.visible and not visual._espada_ativa, "Ferramenta interrompe o golpe de demonstração")
	jogador.esta_em_acao_fazenda = false
	painel._ativar_heroi_gerado(true)
	visual._unhandled_input(evento)
	_conferir(not visual.teste_espada and not visual._espada_ativa, "Sair do modo espada devolve o botão à ferramenta")
	jogador.usando_espada = false
	jogador._esta_atacando = true
	visual._process(0.0)
	_conferir(not visual.visible, "Outras armas continuam com a animação original")
	jogador._esta_atacando = false
	jogador.usando_espada = usando
	jogador.modo_fazenda = modo
	jogador._sem_acao_ate_ms = bloqueio
	visual._process(0.0)

func _capturar_espada_no_jogo(jogador, visual) -> void:
	var saida := "res://arte/previas/personagens/exemplo_alta_qualidade/ataque_espada/"
	var pasta := "/tmp/algoland-espada-fazenda/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	DirAccess.make_dir_recursive_absolute(pasta)
	for nome in ["direita", "esquerda", "baixo", "cima"]:
		visual._reiniciar_estado()
		visual._interromper_espada()
		jogador._direcao_ataque = {"direita": Vector2.RIGHT, "esquerda": Vector2.LEFT, "baixo": Vector2.DOWN, "cima": Vector2.UP}[nome]
		jogador.velocity = Vector2.ZERO
		for quadro in 50:
			var tempo := quadro * 20
			if quadro == 10:
				visual.iniciar_ataque_espada(0.3, true)
			visual._process(0.0 if quadro in [0, 10] else 0.02)
			await _quadros(1)
			await RenderingServer.frame_post_draw
			var imagem := root.get_texture().get_image()
			imagem.get_region(Rect2i(300, 130, 360, 360)).save_png(pasta + "%s_%03d.png" % [nome, quadro])
			if tempo in [0, 200, 240, 280, 320, 400, 460, 500]:
				imagem.save_png(saida + "%s_etapa_%04d_no_jogo.png" % [nome, tempo])
