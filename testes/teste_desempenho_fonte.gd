extends SceneTree
## Regressão de custo de desenho, simulação e visibilidade da fonte, com GPU real.
const AguaFonte := preload("res://codigo/cidade/agua_fonte.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	print("OK " if ok else "FALHA ", mensagem)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n: await process_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(576,324)
	root.content_scale_size = Vector2i(576,324)
	var pai := Node2D.new()
	pai.position = Vector2(144,18)
	pai.scale = Vector2(3,3)
	root.add_child(pai)
	var imagem := Sprite2D.new()
	imagem.centered = false
	imagem.scale = Vector2.ONE / 4
	imagem.texture = load("res://assets/cenario/cidade/enfeites_detalhados/fonte/primavera.png")
	pai.add_child(imagem)
	var agua := AguaFonte.new()
	agua.imagem = imagem
	pai.add_child(agua)
	agua.set_process(false)
	await quadros()
	var custo_us := 0
	var chamadas := 0.0
	for i in 120:
		var inicio := Time.get_ticks_usec()
		agua._process(1.0/60)
		custo_us += Time.get_ticks_usec() - inicio
		await RenderingServer.frame_post_draw
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		await process_frame
	verificar(agua.passos > 35 and agua.impactos > 3, "ondas e jatos continuam ativos")
	verificar(agua.lotes_desenho <= 15, "orçamento de até 15 lotes para todos os jatos, ondas e gotas")
	verificar(chamadas / 120.0 <= 16, "fonte isolada não ultrapassa 16 chamadas de renderização por quadro")
	var superior := 0.0
	var inferior := 0.0
	for i in agua.ativos:
		if not is_finite(agua.altura[i]) or absf(agua.altura[i]) > .95:
			verificar(false, "campo de ondas instável")
		if i / AguaFonte.N < 27: superior += absf(agua.altura[i])
		else: inferior += absf(agua.altura[i])
	verificar(superior > .01 and inferior > .01, "as duas bacias continuam recebendo ondas")
	for estacao in ["primavera", "verao", "outono", "inverno"]:
		imagem.texture = load("res://assets/cenario/cidade/enfeites_detalhados/fonte/%s.png" % estacao)
		for i in 8:
			agua._process(1.0/60)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-fonte-%s.png" % estacao)
	pai.position.x += 5000
	await quadros(12)
	var passos := agua.passos
	agua._process(.1)
	verificar(agua.passos == passos, "fora da tela não simula nem atualiza a textura")
	# No cooperativo, basta a outra câmera enxergar a fonte para manter a animação.
	var vp := SubViewport.new()
	vp.size = Vector2i(320,324)
	vp.world_2d = pai.get_world_2d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera := Camera2D.new()
	camera.position = pai.position + Vector2(144,144)
	vp.add_child(camera)
	camera.make_current()
	await quadros(12)
	agua._process(.1)
	verificar(agua.passos > passos, "fonte visível apenas na segunda câmera continua animada")
	passos = agua.passos
	agua._process(10)
	verificar(agua.passos - passos <= 4, "uma travada não acumula centenas de passos de simulação")
	print(JSON.stringify({"processo_us_por_quadro":custo_us/120.0,"draw_calls_por_quadro":chamadas/120.0,"falhas":falhas}))
	vp.queue_free()
	pai.queue_free()
	await quadros()
	quit(1 if falhas else 0)
