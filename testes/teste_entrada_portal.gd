extends SceneTree

var falhas := 0

func _initialize() -> void:
	rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n: await process_frame

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	var transicao: Node = root.get_node("Transicao")
	transicao.limpar()
	var cena: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(15)
	var jogador: Node = cena.get_node("Jogador")
	var interface: Node = cena.get_node("Interface")
	var tela: Control = interface._telas["desafio_arena"]
	root.get_node("EventosJogo").abrir_tela.emit("desafio_arena")
	for selecao in ["espada", "lanca", "arco", "escudo", "machadinha", "vara_pesca", "sem_item"]:
		jogador.usando_espada = selecao == "espada"
		jogador.usando_lanca = selecao == "lanca"
		jogador.usando_arco = selecao == "arco"
		jogador.usando_escudo = selecao == "escudo"
		jogador.modo_fazenda = selecao == "machadinha"
		tela._atualizar()
		verificar("portal permite entrar: "+selecao, not tela._entrada_portal.disabled)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		var saida := ProjectSettings.globalize_path("res://arte/previas/portal_sem_arma")
		DirAccess.make_dir_recursive_absolute(saida)
		for tamanho in [Vector2i(576,324), Vector2i(288,512), Vector2i(320,324)]:
			root.content_scale_size = tamanho
			root.size = tamanho*2
			await quadros()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida+"/%dx%d.png" % [tamanho.x,tamanho.y])
	# Valida também a ação do botão: uma seleção sem arma atravessa o portal.
	jogador.modo_fazenda = true
	verificar("reprodução sem arma ativa", not jogador.usando_espada and not jogador.usando_lanca and not jogador.usando_arco)
	tela._entrada_portal.pressed.emit()
	var limite := Time.get_ticks_msec() + 15000
	while (transicao.ocupada or current_scene == cena) and Time.get_ticks_msec() < limite:
		await process_frame
	verificar("botão entra no andar com ferramenta selecionada", current_scene != cena and current_scene != null and current_scene.scene_file_path.contains("andar"))
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
