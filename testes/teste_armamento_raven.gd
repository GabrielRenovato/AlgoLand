extends SceneTree

## Usa apenas armamento Raven; os modelos Mana Seed não fazem parte desta revisão.
var falhas := 0
var capturar := false
var previa: SubViewport
var capturas: Dictionary = {}

func _initialize() -> void:
	rodar.call_deferred()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ", mensagem)

func esperar(n := 4) -> void:
	for i in n: await process_frame

func foto(nome: String, jogador: Node2D) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	# Captura pequena do mesmo World2D; grava só depois para não travar o golpe.
	capturas[nome] = previa.get_texture().get_image()

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use save isolado para revisar o armamento Raven.")
		quit(1)
		return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-armamento")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	root.get_node("Transicao").limpar()
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.modo_fazenda = false
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = jogador.global_position - Vector2(0,12)
	jogador.aparencia_raven = {"versao":1,"pele":0,"cabelo":1,"roupa":1,"cor":[1,1,1,1]}
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	visual.set_process(false)
	if capturar:
		previa=SubViewport.new()
		previa.size=Vector2i(128,128)
		previa.world_2d=current_scene.get_world_2d()
		previa.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(previa)
		var camera := Camera2D.new()
		camera.position=jogador.global_position-Vector2(0,12)
		previa.add_child(camera)
		await esperar()
	var arma = jogador.inventario.equipados.get("arma")
	if arma == null:
		jogador.inventario.criar_itens_iniciais()
		arma = jogador.inventario.equipados.arma
	var direcoes := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	var tipos := [] if "--so-escudo" in OS.get_cmdline_user_args() else (["arco"] if "--so-arco" in OS.get_cmdline_user_args() else ["espada","espada_dupla","machado","lanca","arco"])
	for tipo in tipos:
		jogador.usando_espada = tipo in ["espada","espada_dupla","machado"]
		jogador.usando_lanca = tipo == "lanca"
		jogador.usando_arco = tipo == "arco"
		jogador.usando_escudo = false
		arma.duas_maos = tipo == "espada_dupla"
		jogador.id_arma_atual = "machado" if tipo == "machado" else "espada_basica"
		for d in 4:
			jogador._direcao_ataque = direcoes[d]
			jogador.velocity = Vector2.ZERO
			jogador._esta_atacando = false
			jogador._temporizador.stop()
			visual._process(0.0)
			verificar(visual._porte_arma.is_empty() and visual._animacao == "parado", tipo+": repouso sem arma na mão")
			verificar(visual.visible and not jogador.get_node("CompositeSprites").visible,"somente o corpo Raven aparece")
			await foto("%s_%d_parado" % [tipo,d],jogador)
			jogador.velocity = direcoes[d]*110
			for q in 4:
				visual._tempo = q*0.11
				visual._process(0.0)
				verificar(visual._animacao == "correr" and visual._porte_arma.is_empty(),tipo+": corre sem arma na mão")
				await foto("%s_%d_correr_%d" % [tipo,d,q],jogador)
			jogador.velocity = Vector2.ZERO
			jogador._fase_combo = 1
			var disparos := [0]
			var conferir_soltura := func(_direcao: Vector2):
				visual._process(0.0)
				disparos[0] += 1
				verificar(visual._animacao == "arco" and visual.frame%4 == 2,"flecha sai na pose Raven de soltura")
			if tipo == "arco":
				jogador.no_arco.visible = true
				jogador.no_arco.disparo_liberado.connect(conferir_soltura)
				jogador.no_arco.disparar(direcoes[d],0.5)
			elif tipo == "lanca": jogador.iniciar_slash_ataque_lanca("AtaqueLancaSlash_2",jogador._tempo_slash_lanca_2)
			else: jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",jogador._tempo_slash_1)
			var vistos := {}
			var limite := Time.get_ticks_msec()+1800
			while Time.get_ticks_msec()<limite:
				visual._process(0.0)
				if visual._animacao == tipo:
					var q := visual.frame%4
					if not vistos.has(q):
						vistos[q]=true
						await foto("%s_%d_ataque_%d" % [tipo,d,q],jogador)
				if tipo == "arco":
					if not jogador.no_arco.esta_disparando(): break
				elif not jogador._esta_atacando: break
				await process_frame
			verificar(vistos.size()==4,tipo+": quatro poses reais do ataque, direção%d" % d)
			if tipo == "arco":
				verificar(disparos[0] == 1,"uma flecha por ciclo do arco Raven")
				jogador.no_arco.disparo_liberado.disconnect(conferir_soltura)
			jogador.no_arco.parar_disparo()
			jogador._esta_atacando=false
			jogador._temporizador.stop()
			jogador.defesa.estado = jogador.defesa.Estado.GUARDA
			jogador.defesa.direcao_guarda = direcoes[d]
			visual._process(0.0)
			verificar(not visual._escudo_ativo,tipo+": guarda sem escudo não inventa escudo")
			await foto("%s_%d_guarda" % [tipo,d],jogador)
			jogador.defesa.cancelar()
		print("OK armamento Raven: ",tipo)
	# Espada e escudo: porte, guarda sustentada, golpe e escudada real.
	arma.duas_maos=false
	jogador.usando_espada=true
	jogador.usando_lanca=false
	jogador.usando_arco=false
	jogador.usando_escudo=true
	jogador.id_arma_atual="espada_basica"
	for d in 4:
		jogador._direcao_ataque=direcoes[d]
		jogador.velocity=Vector2.ZERO
		visual._process(0.0)
		verificar(visual._animacao=="parado" and not visual._escudo_ativo,"escudo oculto em repouso")
		await foto("escudo_%d_parado" % d,jogador)
		jogador.velocity=direcoes[d]*110
		for q in 4:
			visual._tempo=q*0.11
			visual._process(0.0)
			verificar(visual._animacao=="correr" and not visual._escudo_ativo,"escudo oculto ao correr")
			await foto("escudo_%d_correr_%d" % [d,q],jogador)
		jogador.velocity=Vector2.ZERO
		jogador._fase_combo=1
		jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",jogador._tempo_slash_1)
		var golpes := {}
		while jogador._esta_atacando:
			visual._process(0.0)
			verificar(not visual._escudo_ativo and visual._animacao=="espada","golpe comum não mostra escudo")
			var q := visual.frame%4
			if not golpes.has(q):
				golpes[q]=true
				await foto("escudo_%d_ataque_%d" % [d,q],jogador)
			await process_frame
		verificar(golpes.size()==4,"espada com escudo percorre quatro poses")
		jogador.defesa.estado=jogador.defesa.Estado.GUARDA
		jogador.defesa.direcao_guarda=direcoes[d]
		visual._process(0.0)
		verificar(visual._animacao=="bloquear" and visual.frame%4==3 and visual._escudo_ativo,"guarda sustentada usa a pose final")
		verificar(visual._camadas[7].z_index<0 and visual._camadas[8].z_index>visual._camadas[6].z_index,"escudo respeita corpo e cabelo")
		await foto("escudo_%d_guarda" % d,jogador)
		jogador.defesa._iniciar_escudada()
		var vistos := {}
		var limite_escudada := Time.get_ticks_msec()+2000
		while jogador.defesa.escudando() and Time.get_ticks_msec()<limite_escudada:
			visual._process(0.0)
			verificar(visual._animacao=="bloquear" and visual._escudo_ativo,"escudada não vira ataque de espada")
			var q := visual.frame%4
			if not vistos.has(q):
				vistos[q]=true
				await foto("escudo_%d_escudada_%d" % [d,q],jogador)
			jogador.defesa.atualizar(root.get_process_delta_time())
			await process_frame
		verificar(vistos.size()==4,"escudada percorre quatro poses")
		jogador.defesa.cancelar()
		visual._process(0.0)
		verificar(visual._animacao=="parado" and not visual._escudo_ativo,"escudo some ao terminar o aparo")
	for nome in capturas:
		capturas[nome].save_png("/tmp/algoland-raven-armamento/"+nome+".png")
	print("ARMAMENTO_RAVEN: ",falhas," falhas; ",tipos.size()," armas nativas e escudo nas quatro direções.")
	quit(1 if falhas else 0)
