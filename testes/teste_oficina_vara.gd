extends SceneTree
const Varas := preload("res://codigo/pesca/varas.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await quadros()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/interface_bosque/"+nome+".png")
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").varas_pesca = {"p1":1,"p2":1}
	var inventario = root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(30)
	var jogador = current_scene.get_node("Jogador")
	current_scene.get_node("Iluminacao").set_process(false)
	current_scene.get_node("Iluminacao").definir_hora(12)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	var ui = root.get_node("EventosJogo").interface_p1()
	root.get_node("Cidade").conversar("nilo",jogador)
	await quadros()
	ui._telas["conversa_cidade"]._ver_vara()
	await quadros()
	var oficina = ui._telas["oficina_vara"]
	verificar("servico abre oficina propria e fecha dialogo",oficina.visible and not ui._telas["conversa_cidade"].visible)
	verificar("sem pedras mostra custo e desabilita refinar",oficina._refinar.disabled and oficina._custo.text.contains("0 / 1"))
	await foto("oficina_vara_sem_pedras_pc")
	inventario.adicionar_coletavel("material","pedra_vara",13)
	await quadros()
	verificar("pickup de pedras atualiza oficina",not oficina._refinar.disabled and oficina._custo.text.contains("13 / 1"))
	verificar("moldura e acao cabem no PC",Rect2(Vector2.ZERO,oficina.size).grow(-7).encloses(Rect2(oficina.painel.position,oficina.painel.size)) and oficina.painel.get_global_rect().grow(-8).encloses(oficina._refinar.get_global_rect()))
	await foto("oficina_vara_pc")
	for tamanho in [Vector2i(288,216),Vector2i(384,240)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros()
		verificar("moldura cabe "+str(tamanho),Rect2(Vector2.ZERO,oficina.size).grow(-7).encloses(Rect2(oficina.painel.position,oficina.painel.size)))
		var a: Control = oficina._comparacao.get_child(0)
		var b: Control = oficina._comparacao.get_child(1)
		verificar("comparacao alinha e separa as varas "+str(tamanho),is_equal_approx(a.position.y,b.position.y) and a.get_rect().end.x+7 <= b.position.x and absf(a.size.x-b.size.x) <= 1)
		verificar("acao e custo preservam margem "+str(tamanho),oficina.painel.get_global_rect().grow(-8).encloses(oficina._refinar.get_global_rect()))
		if tamanho.x == 288: await foto("oficina_vara_mobile")
	oficina._refinar.pressed.emit()
	await quadros()
	verificar("refino consome exatamente uma pedra e atualiza nivel",Varas.nivel(jogador)==2 and Varas.pedras(jogador)==12 and oficina._mensagem.contains("NIVEL 2"))
	current_scene.get_node("Iluminacao").definir_hora(18)
	oficina._ao_refinar()
	verificar("horario fechado impede consumo",Varas.nivel(jogador)==2 and Varas.pedras(jogador)==12 and oficina._refinar.disabled)
	current_scene.get_node("Iluminacao").definir_hora(12)
	for i in 3: oficina._ao_refinar()
	await quadros()
	verificar("nivel maximo impede nova cobranca",Varas.nivel(jogador)==5 and oficina._refinar.disabled and oficina._refinar.text.contains("MAXIMO"))
	await foto("oficina_vara_maximo_mobile")
	ui._fechar_tela("oficina_vara")
	root.get_node("Saves").trocar("coop")
	root.get_node("Fazenda").varas_pesca = {"p1":1,"p2":1}
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(30)
	current_scene.get_node("Iluminacao").set_process(false)
	current_scene.get_node("Iluminacao").definir_hora(12)
	var p2 = root.get_node("Cooperativo").jogador2()
	var inv2 = root.get_node("InventarioJogador2")
	inv2.limpar()
	inv2.criar_itens_iniciais()
	inv2.adicionar_coletavel("material","pedra_vara",1)
	var ui2 = root.get_node("Cooperativo").interface_p2()
	ui2._abrir_tela("oficina_vara")
	await quadros()
	var oficina2 = ui2._telas["oficina_vara"]
	oficina2._refinar.pressed.emit()
	verificar("refinar P2 preserva progresso do P1",Varas.nivel(p2)==2 and Varas.nivel(current_scene.get_node("Jogador"))==1 and Varas.pedras(p2)==0)
	await foto("oficina_vara_coop")
	root.get_node("Cooperativo").sair()
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Oficina vara: %d falhas" % falhas)
	quit(1 if falhas else 0)
