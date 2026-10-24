extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n: await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-pausa-%s.png" % nome)
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	root.get_node("Transicao").limpar()
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("pausa")
	await quadros()
	var tela = ui._telas["pausa"]
	for tamanho in [Vector2i(576,324),Vector2i(480,270),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(20)
		for vista in [tela.Vista.MENU,tela.Vista.OPCOES]:
			tela._mostrar(vista)
			await quadros(20)
			verificar("pausa cabe %s vista%d" % [tamanho,vista],Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela.get_node("Centro/Painel").get_global_rect()))
			if vista == tela.Vista.MENU:
				verificar("menu inteiro visivel",tela.get_node("Centro/Painel/Linhas/Rolagem").get_global_rect().grow(1).encloses(tela._menu.get_global_rect()))
			await foto("%dx%d-vista%d" % [tamanho.x,tamanho.y,vista])
		for pedido in ["menu","sair"]:
			tela._pedir(pedido)
			await quadros()
			verificar("confirmacao cabe "+pedido,Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela.get_node("Centro/Painel").get_global_rect()))
			if tamanho == Vector2i(576,324) or tamanho == Vector2i(288,216): await foto("%dx%d-confirmar-%s" % [tamanho.x,tamanho.y,pedido])
		tela._mostrar(tela.Vista.OPCOES)
		var controles = load("res://codigo/ui/tela_controles.gd").new()
		controles.abrir(tela)
		await quadros(20)
		verificar("remapeamento cabe "+str(tamanho),Rect2(Vector2.ZERO,controles._raiz.size).grow(-10).encloses(controles._painel.get_global_rect()))
		await foto("%dx%d-controles" % [tamanho.x,tamanho.y])
		controles._capturar("attack")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		controles._input(esc)
		verificar("captura cancela sem fechar pausa",controles._capturando == "" and tela.visible and paused)
		controles._fechar()
		await quadros()
		tela._continuar()
		await quadros()
		ui._abrir_tela("mapa_mundi")
		await quadros(20)
		var mapa = ui._telas["mapa_mundi"]
		verificar("mapa cabe "+str(tamanho),Rect2(Vector2.ZERO,mapa.size).grow(-6).encloses(mapa.painel.get_global_rect()))
		if tamanho == Vector2i(576,324) or tamanho == Vector2i(288,216): await foto("%dx%d-mapa" % [tamanho.x,tamanho.y])
		ui._fechar_tela("mapa_mundi")
		ui._abrir_tela("pausa")
		await quadros()
	tela._continuar()
	verificar("continuar retoma jogo",not paused)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("PAUSA DETALHADA: ",falhas," falhas")
	quit(1 if falhas else 0)
