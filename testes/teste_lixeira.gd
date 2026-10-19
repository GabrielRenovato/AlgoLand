extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if DisplayServer.get_name() != "headless" and "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-lixeira-"+nome+".png")
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar_coletavel("material","madeira",5)
	var ui: Node = current_scene.get_node("Interface")
	ui._abrir_tela("inventario")
	await quadros(20)
	var mochila: Control = ui._telas["inventario"]
	var lixo: Button = mochila.lixeira
	var item = inv.buscar_por_tipo("material:madeira")
	verificar("lixeira recebe pilha da propria mochila",lixo._can_drop_data(Vector2.ZERO,{"item":item}))
	lixo._drop_data(Vector2.ZERO,{"item":item})
	await quadros()
	verificar("arrasto pede confirmacao sem apagar",lixo.pendente==item and inv.quantidade_tipo("material:madeira")==5)
	await foto("confirmacao_mobile")
	lixo.cancelar()
	verificar("cancelar conserva pilha",inv.quantidade_tipo("material:madeira")==5)
	lixo.solicitar(item)
	lixo.confirmar()
	verificar("confirmar exclui pilha inteira",inv.quantidade_tipo("material:madeira")==0)
	inv.carregar()
	verificar("exclusao persiste ao recarregar",inv.quantidade_tipo("material:madeira")==0)
	inv.adicionar_coletavel("receita","lanca_basica",1)
	item = inv.buscar_por_tipo("receita:lanca_basica")
	await quadros()
	ui.definir_carregado(item)
	lixo._ao_pressionar()
	verificar("controle leva item carregado a lixeira",lixo.pendente==item)
	lixo.confirmar()
	verificar("excluir limpa item carregado",ui.item_carregado==null and inv.quantidade_tipo("receita:lanca_basica")==0)
	inv.adicionar_coletavel("material","pedra",3)
	await quadros()
	item = inv.buscar_por_tipo("material:pedra")
	lixo.button_pressed = true
	lixo._ao_pressionar()
	var slot: Control = mochila._slots_mochila[inv.indice_de(item)]
	var toque := InputEventMouseButton.new()
	toque.button_index = MOUSE_BUTTON_LEFT
	toque.pressed = true
	slot.item_ui()._ao_entrada(toque)
	toque.pressed = false
	slot.item_ui()._ao_entrada(toque)
	verificar("modo toque escolhe item para excluir",lixo.pendente==item)
	lixo.cancelar()
	var caminho: String = inv.caminho_save
	inv.caminho_save = "user://pasta_inexistente/nao_salvar.json"
	verificar("falha ao salvar conserva a mesma pilha",not inv.excluir_item(item) and inv.buscar_por_tipo("material:pedra")==item and item.quantidade==3)
	inv.caminho_save = caminho
	var inv2 := root.get_node("InventarioJogador2")
	inv2.limpar()
	inv2.adicionar_coletavel("material","fibra",2)
	verificar("lixeira nao aceita item do parceiro",not lixo._can_drop_data(Vector2.ZERO,{"item":inv2.buscar_por_tipo("material:fibra")}))
	verificar("equipado nao e apagado pela lixeira",not inv.excluir_item(inv.equipados.arma))
	verificar("lixeira fixa cabe na mochila mobile",mochila.get_node("Sidebar").get_global_rect().encloses(lixo.get_global_rect()))
	await quadros()
	await foto("mobile")
	ui._fechar_tela("inventario")
	verificar("fechar mochila cancela modo excluir",not lixo.selecionando and lixo.pendente==null)
	current_scene.queue_free()
	await quadros()
	print("Lixeira: %d falhas" % falhas)
	quit(1 if falhas else 0)
