extends "res://testes/teste_rolagem_mural.gd"

## Usa o mesmo gesto nativo em telas reais, inclusive começando sobre itens e receitas.
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	Input.emulate_touch_from_mouse = true
	root.get_node("Controle").usando_toque = true
	root.get_node("Introducao").pular_prologo()
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(25)
	var ui: Node = current_scene.get_node("Interface")
	var verificadas := 0
	for nome in ["inventario","mercante","forja","mural_cidade","guia_pesca"]:
		ui._abrir_tela(nome)
		await quadros(20)
		var tela: Control = ui._telas[nome]
		for rolagem in tela.find_children("*","ScrollContainer",true,false):
			if not rolagem.is_visible_in_tree() or rolagem.get_v_scroll_bar().max_value <= rolagem.get_v_scroll_bar().page+20: continue
			rolagem.scroll_vertical = 0
			await quadros()
			var area: Rect2 = rolagem.get_global_rect()
			await arrastar(area.position+Vector2(area.size.x/2,area.size.y-8),Vector2(0,-40))
			verificar("arrasto no mobile: "+nome+"/"+rolagem.name,rolagem.scroll_vertical>10)
			verificadas += 1
		if nome == "inventario":
			var item_slot: Control
			for slot in tela._slots_mochila:
				if slot.item_atual != null and not slot.item_ui().em_uso:
					item_slot = slot
					break
			verificar("ha item para testar o gesto sobre a mochila",item_slot!=null)
			if item_slot != null:
				tela._rolagem.ensure_control_visible(item_slot)
				await quadros()
				var antes: int = tela._rolagem.scroll_vertical
				var fotografia: Array = root.get_node("InventarioJogador").fotografar_mochila()
				await arrastar(item_slot.get_global_rect().get_center(),Vector2(0,35 if antes>25 else -35))
				verificar("deslize vertical sobre item rola a mochila",absi(tela._rolagem.scroll_vertical-antes)>10)
				verificar("gesto de rolagem preserva os itens",root.get_node("InventarioJogador").fotografar_mochila()==fotografia)
		for aberta in ui._telas_abertas.duplicate(): ui._fechar_tela(aberta)
		await quadros()
	verificar("cobertura de varias janelas rolaveis",verificadas>=3)
	current_scene.queue_free()
	await quadros()
	print("Rolagem mobile: %d falhas" % falhas)
	quit(1 if falhas else 0)
