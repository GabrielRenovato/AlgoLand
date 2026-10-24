extends SceneTree
## Exercita a cena real em save isolado e captura os estados renderizados.
var falhas := 0
func _initialize() -> void:
	rodar.call_deferred()
func verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		falhas += 1
		push_error(descricao)
func esperar(n: int) -> void:
	for i in n:
		await process_frame
func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	var jogador := current_scene.get_node("Jogador")
	if "--personalizado" in OS.get_cmdline_user_args():
		jogador.aplicar_dados_carregados({"aparencia_raven":{"versao":1,"pele":2,"cabelo":28,"roupa":8,"cor":[0.35,0.60,1.0,1.0]}})
	jogador.set_physics_process(false)
	var visual := jogador.get_node("HeroiRaven")
	visual.set_process(false)
	jogador.usando_escudo = false # A matriz sem escudo mantém os estados básicos; defesa tem teste próprio.
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-quadros")
	for direcao in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		jogador._direcao_ataque = direcao
		jogador.velocity = Vector2.ZERO
		visual._process(0.0)
		verificar(visual.visible and not jogador.get_node("CompositeSprites").visible,"Raven deve substituir a base na cena real")
		verificar(visual.scale == Vector2.ONE and visual.offset == Vector2(-40,-47),"Escala e pivô nativos")
		for nome in ["parado","correr","espada","lanca","picareta","machado","enxada","regar","arco","esquiva"]:
			jogador.velocity = direcao*80 if nome == "correr" else Vector2.ZERO
			jogador._esta_atacando = nome in ["espada","lanca"]
			jogador.usando_lanca = nome == "lanca"
			jogador.usando_espada = nome == "espada"
			jogador.esta_em_dash = nome == "esquiva"
			jogador.esta_em_acao_fazenda = false
			if nome in ["picareta","machado","enxada","regar"]:
				jogador.no_fazenda.tocar(nome,direcao)
				jogador.esta_em_acao_fazenda = true
			if nome == "arco":
				jogador.usando_arco = true
				jogador.no_arco.disparar(direcao,1.0)
			visual._process(0.1)
			verificar(visual._animacao == nome,"Estado Raven: "+nome)
			var quantidade := 6 if nome == "correr" else 4
			verificar(visual.hframes == quantidade and visual.frame >= 0 and visual.frame < quantidade*4,"Quadro fora da folha: "+nome)
			for camada in visual._camadas:
				verificar(camada.hframes == quantidade and camada.frame == visual.frame,"Camada dessincronizada: "+nome)
			if DisplayServer.get_name() != "headless" and direcao == Vector2.DOWN and nome in ["parado","correr","picareta","espada"]:
				for i in quantidade:
					visual.frame = i
					for camada in visual._camadas: camada.frame = i
					await esperar(2)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/algoland-raven-quadros/%s-%d.png" % [nome,i])
			jogador.no_fazenda.parar()
			jogador.no_arco.parar_disparo()
			jogador.usando_arco = false
		jogador._esta_atacando = false
		jogador.esta_em_dash = false
		jogador.esta_em_acao_fazenda = false
		# Pesca usa o novo ponto da vara e esconde a folha anterior.
		var pesca := preload("res://codigo/pesca/animacao_pesca.gd").new()
		pesca.iniciar(jogador,direcao)
		for pose in 8:
			pesca.pose(pose)
			visual._process(0.0)
			verificar(visual._animacao == "pescar" and not pesca.visible,"Pesca Raven sem corpo duplicado")
			verificar(pesca.ponta() == visual.ponta_pesca(pose,pesca._linha),"Linha conectada à vara Raven")
		jogador.remove_child(pesca)
		pesca.free()
	# Encadear os dois golpes reais do Raven e encerrar mesmo com outro clique na fila.
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-combo")
	var direcoes := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	for d in 4:
		jogador._direcao_ataque = direcoes[d]
		jogador.velocity = Vector2.ZERO
		jogador.usando_espada = true
		jogador.usando_lanca = false
		jogador.id_arma_atual = "espada_basica"
		jogador._fase_combo = 1
		jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",jogador._tempo_slash_1)
		jogador.ataque_enfileirado = true
		var vistos := {}
		var fases_vistas := {}
		var capturas := {}
		var limite := Time.get_ticks_msec()+2000
		while jogador._esta_atacando and Time.get_ticks_msec()<limite:
			visual._process(root.get_process_delta_time())
			var fase: int = jogador._fase_combo
			fases_vistas[fase] = true
			verificar(fase in [1,2],"Raven não deve iniciar terceiro golpe")
			verificar(visual._animacao == ("espada_2" if fase == 2 else "espada"),"Animação própria de cada golpe")
			if fase == 2: jogador.ataque_enfileirado = true
			var chave := "%d-%d" % [fase,visual.frame%4]
			if not vistos.has(chave):
				vistos[chave] = true
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					capturas[chave] = root.get_texture().get_image()
			await process_frame
		verificar(fases_vistas.has(1) and fases_vistas.has(2),"Os dois golpes devem ser reproduzidos, direção %d" % d)
		for chave: String in capturas:
			capturas[chave].save_png("/tmp/algoland-raven-combo/%d-%s.png" % [d,chave])
		verificar(not jogador._esta_atacando and jogador._fase_combo == 0,"Combo termina após os dois golpes")
		visual._process(0.0)
	if DisplayServer.get_name() != "headless":
		# Reprodução pelo controlador com delta real, incluindo o fechamento do ciclo.
		DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-movimento")
		var numero := 0
		for direcao in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
			jogador._direcao_ataque = direcao
			jogador.velocity = direcao*114.0
			for i in 24:
				await process_frame
				visual._process(root.get_process_delta_time())
				await RenderingServer.frame_post_draw
				var captura := root.get_texture().get_image()
				var centro := Vector2i(captura.get_width()/2,captura.get_height()/2)
				captura.get_region(Rect2i(centro-Vector2i(120,120),Vector2i(240,240))).save_png("/tmp/algoland-raven-movimento/%03d.png" % numero)
				numero += 1
	print("RAVEN: ",falhas," falhas; quatro direções, cena real, combo Raven de dois golpes, ferramentas e pesca.")
	current_scene.queue_free()
	await esperar(5)
	# A revisão também descarta os bancos antigos sem pai criados pelo jogador.
	for id in Node.get_orphan_node_ids():
		var orfao = instance_from_id(id)
		if is_instance_valid(orfao) and orfao is Node:
			orfao.free()
	quit.call_deferred(1 if falhas else 0)
