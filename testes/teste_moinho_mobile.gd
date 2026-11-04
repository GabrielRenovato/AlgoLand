extends SceneTree
## Perfil de toque no desktop. Não representa desempenho de um aparelho Android/iOS.
var falhas := 0
var verificacoes := 0
var cena: Node2D
var toque_ui: Node
var capturas := "res://arte/previas/campanha/moinho_mobile"
var medidas: Array[Dictionary] = []

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	if not ok: falhas += 1
	print("OK " if ok else "FALHA ",nome)

func quadros(n := 4) -> void:
	for i in n: await process_frame

func tocar(posicao: Vector2, pressionado: bool, dedo := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = dedo
	ev.position = toque_ui.transform*posicao
	ev.pressed = pressionado
	root.push_input(ev,true)
	Input.flush_buffered_events()

func arrastar(posicao: Vector2, dedo := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = dedo
	ev.position = toque_ui.transform*posicao
	root.push_input(ev,true)
	Input.flush_buffered_events()

func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png")) == OK)

func medir(nome: String) -> void:
	# Aquecimento e capturas ficam fora da janela de medição.
	await quadros(15)
	var tempos: Array[float] = []
	var anterior := Time.get_ticks_usec()
	var chamadas := 0.0
	var primitivas := 0.0
	var cpu := 0.0
	for i in 90:
		await process_frame
		var agora := Time.get_ticks_usec()
		tempos.append(float(agora-anterior)/1000.0)
		anterior = agora
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitivas += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	tempos.sort()
	var soma := 0.0
	for tempo in tempos: soma += tempo
	var r := {"cenario":nome,"quadros":tempos.size(),"fps_medio_pc":1000.0/(soma/tempos.size()),"quadro_p95_ms":tempos[85],"quadro_max_ms":tempos[-1],"cpu_process_ms":cpu/90.0,"draw_calls_media":chamadas/90.0,"primitivas_media":primitivas/90.0,"memoria_estatica_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"memoria_video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}
	medidas.append(r)
	print("MEDIDA ",JSON.stringify(r))

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		push_error("Use projeto gráfico com save isolado AlgoLand testes.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(capturas)
	root.get_node("Controle").usando_toque = true
	root.get_node("Controle")._tirar_mouse_das_acoes()
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	var progresso: RefCounted = load("res://codigo/campanha/progresso_campanha.gd").new()
	verificar("save descartavel inicia",progresso.iniciar("user://percurso_primeira_raiz","prototipo") == OK)
	for missao in ["sobreviver_queda","estrada_interrompida","acolhimento","pomar_sulcos","defesa_da_vila"]:
		for objetivo in catalogo.missoes[missao].objetivos: progresso.registrar_objetivo(missao,objetivo.id)
	progresso.registrar_objetivo("moinho_vazao","margem")
	progresso.recompensas = progresso._concluidas.duplicate()
	progresso.salvar_retorno("moinho",Vector2(-320,-96))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1280,720)
	set_meta("dicas_vistas",{"golpe":true,"rebento":true})
	set_meta("campanha_destino","moinho")
	set_meta("campanha_nova_instancia",false)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(60)
	cena = current_scene
	verificar("mapa do moinho carregado",is_instance_valid(cena) and cena.regiao == "moinho" and is_instance_valid(cena.terreno))
	if not is_instance_valid(cena) or not is_instance_valid(cena.terreno):
		quit(1)
		return
	cena.jogador.invulneravel = true
	for no in get_nodes_in_group("controles_toque"):
		if no.get_viewport() == cena.get_viewport(): toque_ui = no
	verificar("controles de toque reais presentes",is_instance_valid(toque_ui))
	if not is_instance_valid(toque_ui):
		quit(1)
		return
	await create_timer(.4).timeout
	verificar("controles ativos",toque_ui._ativo)
	for perfil in [{"nome":"paisagem-16x9","logico":Vector2i(576,324),"janela":Vector2i(1280,720)},{"nome":"paisagem-20x9","logico":Vector2i(720,324),"janela":Vector2i(1440,648)},{"nome":"retrato","logico":Vector2i(288,512),"janela":Vector2i(720,1280)}]:
		root.content_scale_size = perfil.logico
		root.size = perfil.janela
		await quadros(12)
		toque_ui._organizar()
		var area := Rect2(Vector2.ZERO,toque_ui._tamanho)
		var visiveis: Array[Dictionary] = []
		for b in toque_ui._botoes:
			if not b.visivel: continue
			visiveis.append(b)
			verificar(perfil.nome+" botao cabe: "+str(b.acao),area.encloses(Rect2(b.centro-Vector2.ONE*b.raio,Vector2.ONE*b.raio*2.0)))
		for i in visiveis.size():
			for j in range(i+1,visiveis.size()):
				verificar(perfil.nome+" botoes separados "+str(visiveis[i].acao)+"/"+str(visiveis[j].acao),visiveis[i].centro.distance_to(visiveis[j].centro) >= visiveis[i].raio+visiveis[j].raio)
		cena.jogador.position = Vector2(-320,-96)
		await quadros(8)
		var origem := Vector2(48,area.size.y*.70)
		var antes: Vector2 = cena.jogador.position
		tocar(origem,true)
		arrastar(origem+Vector2(46,0))
		await quadros(12)
		verificar(perfil.nome+" joystick move personagem",cena.jogador.position.x > antes.x+1.0 and root.get_node("Controle").vetor_toque.x > .8)
		var ataque: Dictionary = toque_ui._botao_da_acao(&"attack")
		tocar(ataque.centro,true,1)
		await quadros(2)
		verificar(perfil.nome+" multitoque movimento e ataque",Input.is_action_pressed("attack") and root.get_node("Controle").vetor_toque.x > .8)
		tocar(ataque.centro,false,1)
		tocar(origem,false)
		await quadros(4)
		verificar(perfil.nome+" soltar dedos limpa entrada",not Input.is_action_pressed("attack") and root.get_node("Controle").vetor_toque == Vector2.ZERO)
		await medir(perfil.nome)
		await foto(perfil.nome)
	# Um toque em AGIR deve alterar o registro real, sem invocar o método do puzzle.
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1280,720)
	cena.jogador.position = cena.alvos.registro_entrada.no.position
	await quadros(10)
	var anterior: int = cena.terreno.roteiro.posicoes[0]
	var agir: Dictionary = toque_ui._botao_da_acao(&"open_menu")
	tocar(agir.centro,true,2)
	await quadros(3)
	tocar(agir.centro,false,2)
	await quadros(3)
	verificar("AGIR por toque ajusta registro do puzzle",cena.terreno.roteiro.posicoes[0] != anterior)
	cena.terreno.aplicar_descobertas(["comporta"])
	verificar("roda liga apos abertura da comporta",cena.terreno._roda_moinho.ligado)
	cena.jogador.position = Vector2(-456,-280)
	await medir("moinho-agua-roda-ligada")
	await foto("moinho-agua-roda-ligada")
	var relatorio := {"escopo":"Simulacao de resolucoes e eventos de toque no desktop; nao valida hardware mobile.","aparelho_fisico":false,"gpu":RenderingServer.get_video_adapter_name(),"save":OS.get_user_data_dir(),"verificacoes":verificacoes,"falhas":falhas,"medidas":medidas}
	FileAccess.open(capturas.path_join("resultado.json"),FileAccess.WRITE).store_string(JSON.stringify(relatorio,"\t"))
	print("MOBILE_MOINHO ",JSON.stringify(relatorio))
	quit(1 if falhas else 0)
