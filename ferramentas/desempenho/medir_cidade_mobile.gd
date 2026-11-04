extends SceneTree
## Executar em cópia descartável com Dispositivo.celular() simulado; GPU continua sendo a do PC.
## Não força FPS fixo nem adiciona atrasos artificiais para fingir um telefone lento.
var cena: Node2D
var medidas: Array[Dictionary] = []
var saida := "/tmp/algoland-cidade-mobile-resultado"
var falhas: Array[String] = []
var casas: Array[Node] = []
var clima: Node
var _texturas_encontradas: Dictionary = {}

func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--saida="): saida = argumento.trim_prefix("--saida=")
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n: await process_frame

func memoria() -> Dictionary:
	var rss := 0
	var status: Array = []
	OS.execute("cat",["/proc/%d/status" % OS.get_process_id()],status)
	for linha in (str(status[0]) if not status.is_empty() else "").split("\n"):
		if linha.begins_with("VmRSS:"):
			rss = linha.trim_prefix("VmRSS:").strip_edges().split(" ",false)[0].to_int()
	return {"rss_mb":rss/1024.0,"estatica_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"texturas_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"buffers_mb":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0}

func medir(nome: String, movimento := false, segundos := 3.0) -> void:
	if not cena.interface._telas_abertas.is_empty() or paused:
		falhas.append("Interface interrompeu a medição: "+nome)
	await create_timer(0.65).timeout
	var tempos: Array[float] = []
	var chamadas := 0.0
	var primitivas := 0.0
	var cpu := 0.0
	var fisica := 0.0
	var inicio := Time.get_ticks_usec()
	var anterior := inicio
	var posicao_anterior: Vector2 = cena.jogador.position
	var distancia := 0.0
	while Time.get_ticks_usec()-inicio < segundos*1000000:
		if movimento: root.get_node("Controle").vetor_toque = Vector2.RIGHT if sin((Time.get_ticks_usec()-inicio)/500000.0)>0 else Vector2.LEFT
		await process_frame
		var agora := Time.get_ticks_usec()
		tempos.append((agora-anterior)/1000.0)
		anterior = agora
		distancia += cena.jogador.position.distance_to(posicao_anterior)
		posicao_anterior = cena.jogador.position
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitivas += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		fisica += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	root.get_node("Controle").vetor_toque = Vector2.ZERO
	var soma := 0.0
	var acima_60 := 0
	var acima_30 := 0
	for t in tempos:
		soma += t
		if t>16.667: acima_60 += 1
		if t>33.333: acima_30 += 1
	tempos.sort()
	var n := tempos.size()
	var r := {"cenario":nome,"quadros":n,"fps_medio_pc":1000.0*n/soma,"mediana_ms":tempos[n/2],"p95_ms":tempos[mini(n-1,ceili(n*0.95)-1)],"p99_ms":tempos[mini(n-1,ceili(n*0.99)-1)],"max_ms":tempos[-1],"cpu_process_ms":cpu/n,"cpu_fisica_ms":fisica/n,"draw_calls_media":chamadas/n,"primitivas_media":primitivas/n,"quadros_acima_16_67_pct":100.0*acima_60/n,"quadros_acima_33_33_pct":100.0*acima_30/n,"memoria":memoria()}
	medidas.append(r)
	r["jogador_moveu_px"] = distancia
	r["telas_abertas"] = cena.interface._telas_abertas.duplicate()
	if movimento and distancia<1: falhas.append("Jogador não se moveu: "+nome)
	print("MEDIDA_CIDADE ",JSON.stringify(r))
	FileAccess.open(saida.path_join("parcial.json"),FileAccess.WRITE).store_string(JSON.stringify(medidas,"\t"))

func posicionar(p: Vector2) -> void:
	cena.jogador.position = p
	cena.jogador.get_node("Camera2D").reset_smoothing()
	await quadros(8)

func fotografar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome+".png"))

func visores(no: Node) -> Array[SubViewport]:
	var resultado: Array[SubViewport] = []
	for filho in no.get_children():
		if filho is SubViewport: resultado.append(filho)
		resultado.append_array(visores(filho))
	return resultado

func registrar_textura(textura: Texture2D) -> void:
	if textura is AtlasTexture: textura = textura.atlas
	if not textura: return
	var chave := textura.get_rid().get_id()
	_texturas_encontradas[chave] = {"arquivo":textura.resource_path,"classe":textura.get_class(),"largura":textura.get_width(),"altura":textura.get_height(),"pixels":textura.get_width()*textura.get_height()}

func coletar_texturas(no: Node) -> void:
	for propriedade in no.get_property_list():
		if propriedade.name == "texture" and no.get("texture") is Texture2D: registrar_textura(no.get("texture"))
	for filho in no.get_children(): coletar_texturas(filho)

func rodar() -> void:
	create_timer(180.0).timeout.connect(func(): push_error("Tempo limite do diagnóstico."); quit(1))
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		push_error("Use projeto gráfico e saves isolados.")
		quit(1)
		return
	if not load("res://codigo/globais/dispositivo.gd").celular():
		push_error("Selecione ajustes de celular somente na cópia descartável; não altere o projeto original.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(saida)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1280,720)
	root.get_node("Controle").usando_toque = true
	var antes := memoria()
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	var progresso = load("res://codigo/campanha/progresso_campanha.gd").new()
	progresso.iniciar("user://percurso_primeira_raiz","prototipo")
	for missao in ["sobreviver_queda","estrada_interrompida","acolhimento"]:
		for objetivo in catalogo.missoes[missao].objetivos: progresso.registrar_objetivo(missao,objetivo.id)
	progresso.salvar_retorno("vila",Vector2(0,180))
	set_meta("campanha_destino","vila")
	set_meta("campanha_nova_instancia",false)
	set_meta("dicas_vistas",{"golpe":true,"rebento":true})
	var inicio := Time.get_ticks_usec()
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	while not is_instance_valid(current_scene) or not is_instance_valid(current_scene.get("terreno")):
		await process_frame
	cena = current_scene
	await RenderingServer.frame_post_draw
	var carga_ms := (Time.get_ticks_usec()-inicio)/1000.0
	cena.jogador.invulneravel = true
	for no in cena.get_children():
		if no.has_method("pular") and no.get("ativa"): no.pular()
	for filho in cena.terreno.get_children():
		if filho.get_script() == load("res://codigo/campanha/casa_vila_3d.gd"): casas.append(filho)
	if casas.size()!=10: falhas.append("Esperadas 10 casas 3D, encontradas %d" % casas.size())
	clima = get_first_node_in_group("clima")
	if clima: clima.modo_economico = true
	cena.terreno.definir_estacao(0)
	await create_timer(2.0).timeout
	cena.registro_run.apresentada = true
	for nome in cena.interface._telas_abertas.duplicate(): cena.interface._fechar_tela(nome)
	paused = false
	cena.jogador.desabilitar_todas_acoes(false)
	await quadros(8)
	var grama: Node = cena.terreno._grama_3d
	var config_grama := {"resolucao":grama.resolucao_grama,"passo_tufo":grama.passo_tufo,"fator":grama._fator_grama,"passo_vento":grama._passo_vento,"blocos":grama._visores.size()}
	var memoria_carregada := memoria()
	print("CARGA_CIDADE ",JSON.stringify({"ms":carga_ms,"memoria":memoria_carregada,"grama":config_grama}))
	if "--somente-carga" in OS.get_cmdline_user_args():
		FileAccess.open(saida.path_join("carga.json"),FileAccess.WRITE).store_string(JSON.stringify({"ms":carga_ms,"memoria":memoria_carregada,"grama":config_grama},"\t"))
		quit()
		return
	for tamanho in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = tamanho
		var prefixo := "%dx%d" % [tamanho.x,tamanho.y]
		await posicionar(Vector2(0,180))
		await medir(prefixo+"-praca-movimento",true)
		await fotografar(prefixo+"-praca")
		await posicionar(Vector2(-360,170))
		await medir(prefixo+"-oficinas-fogo")
		await fotografar(prefixo+"-oficinas")
		await posicionar(Vector2(510,-65))
		await medir(prefixo+"-moradias-grama",true)
		await fotografar(prefixo+"-moradias")
	# Comparação de render: recursos seguem residentes, portanto isto NÃO mede a memória sem casas.
	root.size = Vector2i(1280,720)
	await posicionar(Vector2(-360,170))
	await medir("diagnostico-completo")
	for casa in casas:
		casa.hide()
		casa._construcao.set_process(false)
		for v in visores(casa): v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await medir("diagnostico-sem-render-casas")
	grama.hide()
	grama.set_process(false)
	for v in grama._visores: v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await medir("diagnostico-sem-render-casas-e-grama")
	for casa in casas:
		casa.show()
		for v in visores(casa): v.render_target_update_mode = SubViewport.UPDATE_ONCE
		if casa.id == "forja": casa._construcao.set_process(true)
	await medir("diagnostico-casas-sem-grama")
	grama.show()
	grama.set_process(true)
	cena.terreno.definir_estacao(3)
	await posicionar(Vector2(510,-65))
	await medir("1280x720-inverno-moradias",true)
	await fotografar("1280x720-inverno")
	var estado_visores: Array[Dictionary] = []
	for casa in casas:
		estado_visores.append({"id":casa.id,"triangulos":casa._construcao.triangulos,"superficies":casa._construcao._instancias.size(),"objetos":casa._objetos.size(),"viewport":str(casa.visor.size),"modo_final":casa.visor.render_target_update_mode})
	coletar_texturas(root)
	for item in cena.terreno._sazonais:
		for textura in item.get("texturas",[]):
			if textura is Texture2D: registrar_textura(textura)
	for textura in cena.terreno._fontes_arte.values(): registrar_textura(textura)
	var texturas := _texturas_encontradas.values()
	texturas.sort_custom(func(a,b): return a.pixels>b.pixels)
	var antes_liberacao := memoria()
	grama.queue_free()
	await quadros(12)
	await create_timer(0.5).timeout
	var sem_grama := memoria()
	for casa in casas: casa.queue_free()
	await quadros(12)
	await create_timer(0.5).timeout
	var sem_casas := memoria()
	var relatorio := {"escopo":"Configuração mobile e toque simulados no PC; OpenGL ES no driver da GPU desktop. Não mede um Android físico.","aparelho_fisico":false,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"motor":Engine.get_version_info().string,"save_isolado":OS.get_user_data_dir(),"celular_simulado":true,"android_nativo":OS.has_feature("android"),"logico":"576x324","vsync":false,"fps_limitado":false,"carga_primeiro_quadro_cidade_ms":carga_ms,"memoria_antes":antes,"memoria_carregada":memoria_carregada,"grama":config_grama,"casas":estado_visores,"falhas":falhas,"medidas":medidas}
	FileAccess.open(saida.path_join("resultado.json"),FileAccess.WRITE).store_string(JSON.stringify(relatorio,"\t"))
	relatorio["liberacao_recursos"] = {"antes":antes_liberacao,"apos_remover_grama":sem_grama,"apos_remover_grama_e_casas":sem_casas,"observacao":"Diferenças de recursos liberados; caches e materiais compartilhados continuam residentes."}
	relatorio["texturas_maiores"] = texturas.slice(0,30)
	relatorio["texturas_observacao"] = "Lista parcial por dimensões: nós de imagem, sazonais e atlas do terreno; não equivale a uma contagem de bytes GPU nem inclui todos os materiais/fontes do motor."
	FileAccess.open(saida.path_join("resultado.json"),FileAccess.WRITE).store_string(JSON.stringify(relatorio,"\t"))
	print("FIM_CIDADE_MOBILE ",JSON.stringify({"falhas":falhas,"carga_ms":carga_ms,"memoria":memoria_carregada}))
	quit(1 if not falhas.is_empty() else 0)
