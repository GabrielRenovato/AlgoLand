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
func mover(jogador: Node2D, ponto: Vector2, escala: float) -> void:
	jogador.global_position = jogador.get_canvas_transform().affine_inverse() * (ponto * escala)
func conferir(hud: Node, jogador: Node2D, nome: String) -> void:
	var barra: Control = hud.barra_armas
	var escala := preload("res://codigo/ui/escala_interface.gd").fator(hud)
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(hud)
	mover(jogador,Vector2(30,70),escala)
	await quadros()
	var base: Vector2 = barra._coluna.position
	verificar("barra começa embaixo: " + nome, not barra._no_topo)
	# Mostrar e esconder o nome não pode deixar espaço vazio abaixo dos itens.
	barra._mostrar_nome("MACHADINHA",Color.WHITE)
	await quadros()
	var fundo_esperado: float = barra.get_global_rect().end.y - 5 - root.get_node("Controle").margens_seguras().w
	verificar("nome aparece sem levantar os itens: " + nome, absf(barra._painel.get_global_rect().end.y-fundo_esperado)<1)
	await create_timer(2.4).timeout
	await quadros()
	verificar("nome some sem deixar barra levantada: " + nome, not barra._nome.visible and absf(barra._painel.get_global_rect().end.y-fundo_esperado)<1)
	verificar("jogador distante não muda posição automática: " + nome, not barra._no_topo)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-barra-base-"+nome+".png")
	base = barra._coluna.position
	hud.anunciar("POMBO-CORREIO!","CARTA DE LIA",30)
	await quadros()
	verificar("aviso não cruza barra inferior: " + nome, not hud.faixa_banner.get_global_rect().intersects(barra._painel.get_global_rect()))
	mover(jogador,Vector2(base.x + barra._coluna.size.x * 0.5, tela.y - 12),escala)
	await quadros()
	verificar("aproximação leva barra ao topo: " + nome, barra._no_topo and barra._coluna.position.y < base.y)
	var dentro := Rect2(Vector2.ZERO,tela).encloses(barra._painel.get_global_rect())
	var sem_cruzar := true
	for bloco_nome in ["Status","CantoDireito","ObjetivoPrincipal","PainelChefe"]:
		var bloco: Control = hud.get_node(bloco_nome)
		if bloco.is_visible_in_tree(): sem_cruzar = sem_cruzar and not bloco.get_global_rect().intersects(barra._painel.get_global_rect())
	verificar("topo cabe e respeita outros painéis: " + nome, dentro and sem_cruzar)
	verificar("aviso separado também com barra no topo: " + nome, not hud.faixa_banner.get_global_rect().intersects(barra._painel.get_global_rect()))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-barra-topo-"+nome+".png")
	# Pequeno recuo não faz a barra oscilar.
	mover(jogador,Vector2(base.x + barra._coluna.size.x * 0.5, base.y - 28),escala)
	await quadros()
	verificar("folga mantém topo sem oscilação: " + nome,barra._no_topo)
	mover(jogador,Vector2(30,70),escala)
	await quadros()
	verificar("afastar devolve barra à base: " + nome,not barra._no_topo and barra._coluna.position.is_equal_approx(base))
	hud.faixa_banner.hide()
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("GDConsole").hide()
	root.get_node("GDConsole").set_process_input(false)
	root.mode = Window.MODE_WINDOWED
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Controle").usando_toque = true
	root.get_node("Transicao").retornando = true
	root.get_node("Transicao").estado = {"onda_atual":3}
	root.get_node("Transicao").iniciar_onda_ao_chegar = false
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(30)
	root.get_node("Transicao").retornando = false
	var jogador := current_scene.get_node("Jogador") as Node2D
	jogador.set_physics_process(false)
	var camera: Camera2D = jogador.get_node("Camera2D")
	var camera_global := camera.global_transform
	camera.top_level = true
	camera.global_transform = camera_global
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	var hud := get_first_node_in_group("hud_p1")
	for tamanho in [Vector2i(576,324),Vector2i(390,540),Vector2i(288,216)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros()
		await conferir(hud,jogador,"toque_%dx%d" % [tamanho.x,tamanho.y])
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Transicao").retornando = true
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(30)
	root.get_node("Transicao").retornando = false
	jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	camera = jogador.get_node("Camera2D")
	camera_global = camera.global_transform
	camera.top_level = true
	camera.global_transform = camera_global
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	hud = get_first_node_in_group("hud_p1")
	await conferir(hud,jogador,"pc")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Barra desvia jogador: %d falhas" % falhas)
	quit(1 if falhas else 0)
