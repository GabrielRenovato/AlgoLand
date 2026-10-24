extends SceneTree

const Icones := preload("res://codigo/ui/icones_itens.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-inventario-%s.png" % nome)
func conferir(tela: Control, nome: String) -> void:
	var painel: Control = tela.get_node("Sidebar")
	verificar("margens do inventario "+nome,Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(painel.get_global_rect()))
	var margem: Control = painel.get_node("MargemSegura")
	verificar("conteudo dentro da madeira "+nome,painel.get_global_rect().grow(-8).encloses(margem.get_child(0).get_global_rect()))
	for slot: Control in tela._slots_mochila + tela._slots_equipamento.values():
		var item = slot.item_atual
		var icone: TextureRect = slot.item_ui().icone
		verificar("icone continua pixelado "+nome,icone.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		if item != null:
			var esperado: Texture2D = Icones.obter(item,self)
			verificar("sprite original preservado "+nome,icone.texture.get_image().get_data() == esperado.get_image().get_data())
			verificar("icone afastado da moldura "+nome,Rect2(Vector2.ZERO,slot.size).grow(-3).encloses(icone.get_rect()))
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var inv = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.definir_linhas_extras(2)
	inv.adicionar_sementes("cenoura",42)
	inv.adicionar_coletavel("material","nucleo",7)
	inv.adicionar_coletavel("peixe","sardinha",3)
	inv.adicionar_arma_nova("espada_gemea")
	var arma = inv.buscar_por_tipo("espada_gemea")
	arma.raridade = "epico"
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await quadros(15)
	var tela = ui._telas["inventario"]
	verificar("raridade preservada na moldura",tela._slots_mochila[inv.indice_de(arma)].item_ui().moldura.get_theme_stylebox("panel").border_color.is_equal_approx(arma.cor_raridade().lightened(0.12)))
	for tamanho in [Vector2i(576,324),Vector2i(480,270),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(12)
		tela.selecionar_pagina(0)
		await quadros()
		conferir(tela,str(tamanho))
		await foto("%dx%d" % [tamanho.x,tamanho.y])
		for aba in [1,2,3]:
			tela._botoes_abas[aba].pressed.emit()
			await quadros()
			verificar("aba abre %d %s" % [aba,str(tamanho)],tela._aba_atual == aba)
			if tamanho == Vector2i(576,324): await foto("aba-%d" % aba)
			verificar("aba cabe na moldura %d" % aba,tela.get_node("Sidebar").get_global_rect().grow(-8).encloses([tela._missoes,tela._desafios,tela._pesca][aba-1].get_global_rect()))
	# A troca usa os mesmos dados e a moldura acompanha a raridade na nova casa.
	tela.selecionar_pagina(0)
	var antiga: int = inv.indice_de(arma)
	var destino: int = inv.capacidade()-1
	tela._slots_mochila[destino]._drop_data(Vector2.ZERO,{"item":arma})
	await quadros()
	verificar("mover item preserva dados e raridade",inv.indice_de(arma) == destino and tela._slots_mochila[destino].item_atual == arma and arma.raridade == "epico")
	verificar("casa de origem atualiza",tela._slots_mochila[antiga].item_atual != arma)
	# Coop: o acabamento e os dados pertencem ao painel de cada jogador.
	ui._fechar_tela("inventario")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	var inv2 = root.get_node("InventarioJogador2")
	inv2.criar_itens_iniciais()
	inv2.adicionar_sementes("morango",12)
	var ui2 = root.get_node("Cooperativo").interface_p2()
	ui2._abrir_tela("inventario")
	await quadros(15)
	var tela2 = ui2._telas["inventario"]
	conferir(tela2,"coop P2")
	verificar("P2 usa inventario proprio",tela2._slots_mochila[inv2.indice_de(inv2.buscar_por_tipo("semente:morango"))].item_atual.quantidade == 12)
	await foto("coop-p2")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("INVENTARIO DETALHADO: ",falhas," falhas")
	quit(1 if falhas else 0)
