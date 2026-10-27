extends SceneTree
## Integração real, com entradas do jogador e gravação do viewport da fazenda.
const Cartoon := preload("res://codigo/jogador/heroi_cartoon.gd")
const SAIDA := "res://arte/previas/personagens/raven_cartoon/no_jogo/"
var falhas := 0
var verificacoes := 0
var jogador: Node
var visual: Node
var vistos := {}
var captura := false
var indice_captura := 0
var inicio_captura := 0
var proxima_captura := 0
var tempos := []
var deslocamentos := []
var imagens: Array[Image] = []
var ultima_captura := ""
var poses_porte := {}
var porte_sincronizado := true
var porte_oculto_no_golpe := true
var tamanho_porte_constante := true
var velocidade_cartoon := 0.0
var velocidade_padrao := 0.0
var distancia_anterior := -1.0
var posicao_anterior := Vector2.ZERO
var direcao_anterior := ""
var fase_acompanha_chao := true
var fase_na_frenagem := true
var velocidade_anterior := 0.0
var amostras_frenagem := 0
var com_armadura := false
var encaixe_armadura := true

func _initialize() -> void:
	rodar.call_deferred()

func conferir(ok: bool, mensagem: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error(mensagem)

func esperar(quantidade: int) -> void:
	for i in quantidade:
		await process_frame

func tocar_ataque() -> void:
	for pressionado in [true, false]:
		var evento := InputEventAction.new()
		evento.action = "attack"
		evento.pressed = pressionado
		Input.parse_input_event(evento)

func acompanhar(segundos: float) -> void:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio < segundos*1000.0:
		await RenderingServer.frame_post_draw
		var chave: String = visual.acao_atual+":"+visual.direcao_atual+":"+str(visual.corpo.frame)
		vistos[chave] = true
		if com_armadura:
			var textura: AtlasTexture = visual.corpo.sprite_frames.get_frame_texture(visual.corpo.animation,visual.corpo.frame)
			encaixe_armadura = encaixe_armadura and visual.armadura.rosto.visible and visual.armadura.rosto.texture.region == textura.region and visual.armadura.rosto.position == visual.corpo.offset
			for camada in visual.armadura.camadas:
				encaixe_armadura = encaixe_armadura and camada.visible and camada.texture.region == textura.region and camada.position == visual.corpo.offset
		var arma: Sprite2D = visual._arma_costas
		tamanho_porte_constante = tamanho_porte_constante and arma.scale.abs().is_equal_approx(Vector2(0.01408,0.012))
		if visual.acao_atual == "correr":
			velocidade_cartoon = maxf(velocidade_cartoon, jogador.velocity.length())
			if distancia_anterior >= 0.0 and direcao_anterior == visual.direcao_atual:
				var avanco: float = visual._distancia_corrida-distancia_anterior
				fase_acompanha_chao = fase_acompanha_chao and absf(avanco-posicao_anterior.distance_to(jogador.global_position)) < 0.02
				if jogador.velocity.length() < velocidade_anterior-0.5:
					amostras_frenagem += 1
					fase_na_frenagem = fase_na_frenagem and avanco >= -0.001
			distancia_anterior = visual._distancia_corrida
			posicao_anterior = jogador.global_position
			direcao_anterior = visual.direcao_atual
			velocidade_anterior = jogador.velocity.length()
			var pose := Vector3(arma.position.x, arma.position.y, arma.rotation)
			if poses_porte.has(chave):
				porte_sincronizado = porte_sincronizado and pose.is_equal_approx(poses_porte[chave])
			poses_porte[chave] = pose
		elif visual.acao_atual.begins_with("espada"):
			porte_oculto_no_golpe = porte_oculto_no_golpe and not arma.visible
		if visual.acao_atual != "correr":
			distancia_anterior = -1.0
		if captura and (Time.get_ticks_msec() >= proxima_captura or (visual.acao_atual != "parado" and chave != ultima_captura)):
			var agora := Time.get_ticks_msec()
			var ancora: Vector2 = jogador.get_global_transform_with_canvas().origin*Vector2(root.size)/Vector2(root.content_scale_size)
			imagens.append(root.get_texture().get_image())
			ultima_captura = chave
			tempos.append({"indice": indice_captura, "tempo_ms": agora-inicio_captura,
				"acao": visual.acao_atual, "direcao": visual.direcao_atual, "quadro": visual.corpo.frame,
				"posicao": [jogador.position.x, jogador.position.y], "ancora_tela": [ancora.x, ancora.y],
				"passada": {"distancia": visual._distancia_corrida, "ciclo": visual.distancia_ciclo_corrida(), "velocidade": jogador.velocity.length()},
				"porte": {"posicao": [arma.position.x, arma.position.y], "angulo": arma.rotation,
					"escala": [arma.scale.x, arma.scale.y], "visivel": arma.visible}})
			indice_captura += 1
			proxima_captura = agora+40
		await process_frame

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes cartoon fazenda"))
	assert(DisplayServer.get_name() != "headless")
	captura = "--capturar" in OS.get_cmdline_user_args()
	com_armadura = "--armadura" in OS.get_cmdline_user_args()
	if captura:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
		FileAccess.open(SAIDA+"gravacao_em_andamento.json",FileAccess.WRITE).store_string(JSON.stringify({"inicio":Time.get_unix_time_from_system()}))
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1152, 720)
	root.get_node("Introducao").pular_prologo()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.get_node("Fazenda").apagar()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(40)
	root.get_node("Transicao").limpar()
	jogador = current_scene.get_node("Jogador")
	var painel = root.get_node("PainelDebug")
	var mochila_antes = jogador.inventario.fotografar_mochila()
	var energia_antes: int = root.get_node("Fazenda").energia_de()
	painel._ativar_cartoon(com_armadura)
	await esperar(3)
	visual = jogador.get_node("HeroiCartoon")
	conferir(visual.visible and not jogador.get_node("HeroiRaven").visible, "Um único visual do jogador")
	conferir(not jogador.get_node("CompositeSprites").visible, "Camadas antigas ocultas")
	conferir(jogador.modo_fazenda, "Conserva modo e regras da fazenda")
	if com_armadura:
		var textura_original = visual.corpo.sprite_frames.get_frame_texture(visual.corpo.animation,visual.corpo.frame)
		for mascara in [0,1,2,4,8,15]:
			visual.armadura.definir_pecas(mascara)
			await esperar(2)
			for i in 4:
				conferir(visual.armadura.camadas[i].visible == ((mascara & (1 << i)) != 0), "Peça independente: %d/%d" % [mascara,i])
			conferir((visual.corpo.material == null) == (mascara == 0), "Máscara do corpo acompanha peças: "+str(mascara))
			conferir(visual.corpo.has_meta("luvas_armadura") == ((mascara & 4) != 0), "Punho acompanha luvas: "+str(mascara))
			conferir(visual.armadura.rosto.visible == ((mascara & 1) != 0), "Rosto independente acompanha o elmo: "+str(mascara))
			if captura:
				await RenderingServer.frame_post_draw
				var imagem := root.get_texture().get_image()
				var ancora: Vector2 = jogador.get_global_transform_with_canvas().origin*Vector2(root.size)/Vector2(root.content_scale_size)
				var recorte := imagem.get_region(Rect2i(Vector2i(ancora)-Vector2i(80,100),Vector2i(160,160)))
				recorte.save_png("res://arte/previas/armaduras/cavaleiro_aco_cartoon/pecas_mascara_%02d.png" % mascara)
		conferir(visual.corpo.sprite_frames.get_frame_texture(visual.corpo.animation,visual.corpo.frame) == textura_original, "Corpo original preservado ao equipar peças")
		conferir(visual.armadura.rosto.get_index() < visual.armadura.camadas[0].get_index(), "Rosto desenhado sob a armadura original")
	var velocidade_guardada: Vector2 = jogador.velocity
	jogador.velocity = Vector2(97.2,0)
	visual._process(0.25)
	var fase_sem_deslocamento: float = visual._distancia_corrida
	jogador.velocity = Vector2(10,0)
	visual._process(0.25)
	conferir(is_equal_approx(visual._distancia_corrida,fase_sem_deslocamento), "Sem deslocamento real, o pé não avança mesmo com velocidade solicitada")
	jogador.velocity = velocidade_guardada
	visual._process(0.0)
	for caso in [[0.0,0], [0.159,0], [0.16,1], [0.22,2], [0.29,3], [0.49,3]]:
		conferir(Cartoon.quadro_golpe(caso[0]) == caso[1], "Fase do golpe: "+str(caso))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA+"quadros/"))
	# A mesma seleção é conferida na UI real, inclusive em tela estreita.
	painel._area.select(2)
	painel._selecionar_area(2)
	painel._categoria.select(0)
	painel._selecionar_categoria(0)
	painel._acao.select(2 if com_armadura else 1)
	painel._selecionar_acao(2 if com_armadura else 1)
	painel._painel.show()
	for tamanho in [Vector2i(576,360), Vector2i(288,512)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await esperar(8)
		painel._ajustar_altura()
		await esperar(3)
		var caixa: Rect2 = painel._painel.get_global_rect()
		conferir(Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(caixa), "Painel cabe: "+str(tamanho))
		conferir(caixa.grow(-10).encloses(painel._acao.get_global_rect()), "Margens da ação cartoon: "+str(tamanho))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA+"f3_%dx%d.png" % [tamanho.x,tamanho.y])
	painel._painel.hide()
	var tela_inteira := "--tela-inteira" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i(480,300) if tela_inteira else Vector2i(576,360)
	root.size = root.content_scale_size*2
	jogador.camera.zoom = Vector2(2,2)
	jogador.camera.reset_smoothing()
	var luz = current_scene.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	await esperar(8)
	inicio_captura = Time.get_ticks_msec()
	proxima_captura = inicio_captura
	await acompanhar(0.4)
	for trecho in [["move_right", "direita", 0.9], ["move_down", "frente", 0.7],
			["move_left", "esquerda", 0.9], ["move_up", "costas", 0.7]]:
		var antes: Vector2 = jogador.global_position
		Input.action_press(trecho[0])
		await acompanhar(trecho[2])
		Input.action_release(trecho[0])
		await acompanhar(0.15)
		# A física desacelera por passo; aguardar o repouso real em máquinas mais lentas.
		for i in 24:
			if visual.acao_atual == "parado": break
			await acompanhar(0.05)
		conferir(visual._arma_costas.visible and visual._arma_costas.position.is_equal_approx(Vector2(3 if trecho[1] == "esquerda" else -3,-21)), "Retoma porte em repouso: "+trecho[1])
		var distancia := antes.distance_to(jogador.global_position)
		deslocamentos.append({"direcao": trecho[1], "distancia": distancia})
		conferir(distancia > 25.0, "Caminha fisicamente para "+trecho[1])
		tocar_ataque()
		await acompanhar(0.16)
		tocar_ataque()
		await acompanhar(0.95)
		for golpe in [1,2]:
			for q in 4:
				conferir(vistos.has("espada%d:%s:%d" % [golpe,trecho[1],q]), "Combo/fase na fazenda: %d/%s/%d" % [golpe,trecho[1],q])
	await acompanhar(0.3)
	captura = false
	if com_armadura: conferir(encaixe_armadura, "Armadura acompanha região, pivô e quadro em todas as animações")
	conferir(porte_sincronizado, "Mesmo quadro sempre usa o mesmo encaixe, sem oscilador independente")
	conferir(porte_oculto_no_golpe, "Espada sai das costas durante os golpes")
	conferir(tamanho_porte_constante, "Porte conserva tamanho em todos os quadros e direções")
	conferir(fase_acompanha_chao, "Avanço da passada acompanha a distância física, inclusive ao acelerar")
	conferir(amostras_frenagem >= 4 and fase_na_frenagem, "Frenagem não rebobina o ciclo: "+str(amostras_frenagem)+" amostras")
	for direcao in ["frente", "costas", "direita", "esquerda"]:
		var poses := []
		for q in 4:
			var chave := "correr:%s:%d" % [direcao,q]
			conferir(poses_porte.has(chave), "Encaixe de corrida observado: "+chave)
			if poses_porte.has(chave): poses.append(poses_porte[chave])
		conferir(poses.size() == 4 and not poses.all(func(p): return p.is_equal_approx(poses[0])), "Espada acompanha o tronco em "+direcao)
	for q in 4:
		var direita: Vector3 = poses_porte.get("correr:direita:%d" % q, Vector3.ZERO)
		var esquerda: Vector3 = poses_porte.get("correr:esquerda:%d" % q, Vector3.ZERO)
		conferir(is_equal_approx(esquerda.x,-direita.x-Cartoon.ESCALA) and is_equal_approx(esquerda.y,direita.y) and is_equal_approx(esquerda.z,-direita.z), "Porte espelhado junto da célula: "+str(q))
	var perfil_inicio: Vector3 = poses_porte.get("correr:direita:0", Vector3.ZERO)
	var perfil_baixo: Vector3 = poses_porte.get("correr:direita:3", Vector3.ZERO)
	conferir(perfil_baixo.y-perfil_inicio.y > 1.0 and perfil_baixo.x-perfil_inicio.x > 0.8, "Arma acompanha descida e avanço do tronco no quarto quadro")
	conferir(jogador.inventario.fotografar_mochila() == mochila_antes, "Teste não altera a mochila")
	conferir(root.get_node("Fazenda").energia_de() == energia_antes, "Teste não gasta energia de ferramenta")
	conferir(not jogador.get_node("AreaAtaque").monitoring, "Demonstração da fazenda sem hitbox de dano")
	conferir(not current_scene.get_node("Terrains/Plantio")._cursor_visivel, "Espada sem marcador de ferramenta no solo")
	# Fora do modo de ferramenta, exercita o combo real e seus temporizadores.
	jogador.modo_fazenda = false
	jogador.id_arma_atual = "espada_basica"
	jogador.usando_espada = true
	var golpes_reais := []
	jogador.acao_visual.connect(func(acao, duracao, combo):
		if acao == "ataque": golpes_reais.append([combo,duracao]))
	tocar_ataque()
	await acompanhar(0.16)
	conferir(jogador.get_node("AreaAtaque").monitoring, "Combo real ativa área de ataque")
	tocar_ataque()
	await acompanhar(1.0)
	conferir(golpes_reais == [[1,0.49],[2,0.49]], "Dois golpes reais nos tempos aprovados: "+str(golpes_reais))
	conferir(jogador._fase_combo == 0 and not jogador._esta_atacando, "Combo real encerra sem travar")
	painel._reaplicar_personagem()
	await esperar(3)
	conferir(not jogador.has_node("HeroiCartoon") and jogador.get_node("HeroiRaven").visible, "Restaura compositor anterior")
	# A redução é aplicada ao movimento real e termina ao remover o modo cartoon.
	jogador.modo_fazenda = true
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
		velocidade_padrao = maxf(velocidade_padrao, jogador.velocity.length())
	Input.action_release("move_right")
	conferir(velocidade_padrao > 0.0 and absf(velocidade_cartoon/velocidade_padrao-0.8) < 0.02,
		"Movimento cartoon 20%% mais lento; restauração recupera velocidade: %s/%s" % [velocidade_cartoon,velocidade_padrao])
	await esperar(20)
	# Exportação fora do percurso: compressão não interfere no tempo do jogo.
	for i in imagens.size():
		imagens[i].save_png(SAIDA+"quadros/quadro_%04d.png" % i)
		imagens[i] = null
		if i % 20 == 0:
			await process_frame
	FileAccess.open(SAIDA+"gravacao.json", FileAccess.WRITE).store_string(JSON.stringify({"capturas": tempos, "deslocamentos": deslocamentos,
		"verificacoes": verificacoes, "falhas": falhas, "armadura": com_armadura, "save": OS.get_user_data_dir(), "cena": "res://cenas/fazenda.tscn",
		"velocidades": {"cartoon": velocidade_cartoon, "padrao": velocidade_padrao},
		"captura": "viewport real, controles e física do jogador; sem teletransporte durante o percurso"}, "\t"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAIDA+"gravacao_em_andamento.json"))
	print("CARTOON NO JOGO: %d verificações, %d falhas, %d capturas." % [verificacoes,falhas,indice_captura])
	if falhas == 0 and "--deixar-aberto" in OS.get_cmdline_user_args():
		jogador.modo_fazenda = true
		painel._ativar_cartoon(com_armadura)
		print("SESSÃO ABERTA: Cartoon ativo na fazenda; WASD move, espaço/clique golpeia, segundo toque encadeia.")
		return
	visual = null
	jogador = null
	current_scene.queue_free()
	current_scene = null
	await esperar(4)
	quit(1 if falhas else 0)
