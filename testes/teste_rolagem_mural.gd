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
func arrastar(inicio: Vector2, deslocamento: Vector2) -> void:
	var apertar := InputEventMouseButton.new()
	apertar.button_index = MOUSE_BUTTON_LEFT
	apertar.position = inicio
	apertar.pressed = true
	root.push_input(apertar, true)
	for passo in range(1,9):
		var mover := InputEventMouseMotion.new()
		mover.position = inicio + deslocamento * passo / 8.0
		mover.relative = deslocamento / 8.0
		mover.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mover, true)
		await quadros(1)
	apertar = apertar.duplicate()
	apertar.position = inicio + deslocamento
	apertar.pressed = false
	root.push_input(apertar, true)
	await quadros()
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	Input.emulate_touch_from_mouse = true
	root.get_node("Controle").usando_toque = true
	root.get_node("Introducao").pular_prologo()
	root.get_node("Cidade").missoes.clear()
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(25)
	var ui: Node = current_scene.get_node("Interface")
	ui._abrir_tela("mural_cidade")
	await quadros(20)
	var mural: Control = ui._telas["mural_cidade"]
	var area: Rect2 = mural._rolagem.get_global_rect()
	var aceitas: int = root.get_node("Cidade").missoes.size()
	await arrastar(area.position+Vector2(area.size.x/2,area.size.y-12),Vector2(0,-55))
	verificar("dedo arrasta lista de pedidos",mural._rolagem.scroll_vertical>20)
	verificar("arrastar nao aceita pedidos",root.get_node("Cidade").missoes.size()==aceitas)
	mural._rolagem.ensure_control_visible(mural._botoes[0])
	await quadros()
	await arrastar(mural._botoes[0].get_global_rect().get_center(), Vector2(0,-40))
	verificar("arrastar sobre botao nao aceita pedido",root.get_node("Cidade").missoes.size()==aceitas)
	mural._rolagem.ensure_control_visible(mural._botoes[0])
	await quadros()
	await arrastar(mural._botoes[0].get_global_rect().get_center(), Vector2.ZERO)
	verificar("toque simples ainda aceita pedido",root.get_node("Cidade").missoes.size()==aceitas+1)
	mural._abas_mural[1].pressed.emit()
	await quadros(15)
	area = mural._rolagem.get_global_rect()
	await arrastar(area.position+Vector2(area.size.x/2,area.size.y-12),Vector2(0,-55))
	verificar("dedo arrasta agenda da vila",mural._rolagem.scroll_vertical>20)
	if DisplayServer.get_name() != "headless" and "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-mural-toque.png")
	current_scene.queue_free()
	await quadros()
	print("Rolagem mural: %d falhas" % falhas)
	quit(1 if falhas else 0)
