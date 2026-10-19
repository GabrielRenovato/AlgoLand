extends "res://testes/teste_rolagem_mural.gd"

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	root.get_node("InventarioJogador").criar_itens_iniciais()
	Input.emulate_touch_from_mouse = true
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(25)
	var ui: Node = root.get_node("EventosJogo").interface_p1()
	var mapa: Control = ui._telas["mapa_mundi"]
	var botao: Button = get_first_node_in_group("hud").get_node("CantoDireito/BotaoMapaMundi")
	botao.pressed.emit()
	await quadros(20)
	verificar("botao do HUD abre mapa", mapa.visible and "mapa_mundi" in ui._telas_abertas)
	var tamanho_logico := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(mapa)
	verificar("primeira abertura cabe sem redimensionar a janela", Rect2(Vector2.ZERO,tamanho_logico).encloses(mapa.painel.get_global_rect()))
	verificar("primeira abertura mostra a imagem inteira", mapa._rolagem.get_global_rect().encloses(mapa._imagem.get_global_rect()))
	verificar("local atual e fazenda", mapa.regiao_atual()=="fazenda" and mapa._atores["p1"].visible)
	verificar("servicos nas casas e retratos dos oito moradores",mapa._servicos.size()==9 and mapa._atores.size()==9)
	verificar("pictogramas usam texturas do jogo",mapa._servicos["forja"].get_child(0).texture!=null)
	verificar("cabecalho seguido diretamente pelo mapa",mapa._rolagem.get_index()==1)
	var grafico := DisplayServer.get_name() != "headless"
	var pasta := "/tmp/algoland-mapa-mundi"
	if grafico: DirAccess.make_dir_recursive_absolute(pasta)
	if grafico:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"/primeira_abertura.png")
	for tamanho in [Vector2i(720,405), Vector2i(576,324), Vector2i(288,216)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(20)
		verificar("painel cabe na tela %s" % tamanho, Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(mapa.painel.get_global_rect()))
		verificar("icones comerciais pequenos %s" % tamanho,mapa._servicos["forja"].size.x<=14)
		verificar("mapa legivel sem deformacao %s" % tamanho, is_equal_approx(mapa._imagem.size.x/mapa._imagem.size.y,1.5) or absf(mapa._imagem.size.x/mapa._imagem.size.y-1.5)<0.02)
		verificar("detalhes e fechar ficam dentro do painel %s" % tamanho, mapa.painel.get_global_rect().encloses(mapa._detalhe.get_global_rect()) and mapa.painel.get_global_rect().encloses(mapa._fechar.get_global_rect()))
		if grafico:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(pasta+"/mapa_%dx%d.png" % [tamanho.x,tamanho.y])
	mapa._alterar_zoom("+")
	mapa._alterar_zoom("+")
	await quadros(20)
	var rolagem: ScrollContainer = mapa._rolagem
	rolagem.scroll_vertical = 0
	rolagem.scroll_horizontal = 0
	await quadros()
	var area := rolagem.get_global_rect()
	await arrastar(area.get_center(), Vector2(-35,-35))
	verificar("mapa ampliado arrasta com o dedo",rolagem.scroll_vertical>10 or rolagem.scroll_horizontal>10)
	mapa._fechar.pressed.emit()
	await quadros()
	verificar("fechar libera a interface",not mapa.visible and ui._telas_abertas.is_empty())
	root.get_node("Controle").usando_toque = false
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_M
	tecla.pressed = true
	root.push_input(tecla,true)
	await quadros()
	verificar("tecla M abre mapa",mapa.visible)
	verificar("reabrir restaura zoom e mostra a imagem inteira",mapa._zoom==1.0 and mapa._rolagem.get_global_rect().encloses(mapa._imagem.get_global_rect()))
	tecla.pressed = false
	root.push_input(tecla,true)
	mapa._fechar.pressed.emit()
	ui._abrir_tela("pausa")
	ui._telas["pausa"].get_node("%Menu/BotaoMapaMundi").pressed.emit()
	await quadros()
	verificar("controle acessa mapa pela pausa",mapa.visible and not paused)
	ui._fechar_tela("mapa_mundi")
	# Atalho direto no controle sem acionar a ficha de atributos.
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_STICK
	joy.pressed = true
	root.push_input(joy,true)
	await quadros()
	verificar("R3 curto nao abre mapa",not mapa.visible)
	await create_timer(0.5).timeout
	await quadros()
	verificar("segurar R3 abre mapa",mapa.visible and not joy.is_action_pressed("show_stats"))
	joy.pressed = false
	root.push_input(joy,true)
	ui._fechar_tela("mapa_mundi")
	# Mesma carta em locais diferentes; a indicacao acompanha o dono do painel.
	for caminho in ["res://cenas/cidade.tscn", "res://cenas/praia.tscn", "res://cenas/palafita.tscn"]:
		change_scene_to_file(caminho)
		await quadros(25)
		ui = root.get_node("EventosJogo").interface_p1()
		mapa = ui._telas["mapa_mundi"]
		ui._abrir_tela("mapa_mundi")
		await quadros()
		verificar("indica regiao correta em "+caminho, mapa.regiao_atual()==caminho.get_file().get_basename())
		verificar("mapa sem seletor de regioes em "+caminho,mapa._rolagem.get_index()==1)
		verificar("desktop nao tem botao sob relogio",get_first_node_in_group("hud").get_node_or_null("CantoDireito/BotaoMapaMundi")==null)
		if caminho.ends_with("cidade.tscn"):
			root.content_scale_size = Vector2i(576,324)
			root.size = Vector2i(1152,648)
			var npc: Node2D
			for morador in get_nodes_in_group("moradores_cidade"):
				if morador.id=="bento": npc=morador
			npc.visible = true
			npc.position = Vector2(200,300)
			mapa._atualizar_atores()
			var antes: Vector2 = mapa._atores["npc_bento"].get_meta("ponto_carta")
			npc.position += Vector2(50,20)
			mapa._atualizar_atores()
			verificar("retrato segue a caminhada real do NPC",mapa._atores["npc_bento"].get_meta("ponto_carta")!=antes)
			var jogador: Node2D = root.get_node("Cooperativo")._jogador1()
			antes = mapa._atores["p1"].get_meta("ponto_carta")
			jogador.position += Vector2(30,20)
			mapa._atualizar_atores()
			verificar("icone acompanha posicao do jogador",mapa._atores["p1"].get_meta("ponto_carta")!=antes)
			mapa._servicos["forja"].pressed.emit()
			verificar("icone explica o servico da casa","FORJA DO IVO" in mapa._detalhe.text)
			await quadros(20)
			if grafico:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta+"/mapa_desktop_icones.png")
				ui._fechar_tela("mapa_mundi")
				await quadros()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta+"/hud_desktop_compacto.png")
				ui._abrir_tela("inventario")
				await quadros(20)
				var mochila: Control = ui._telas["inventario"]
				verificar("detalhe do item tem espaco proprio",mochila._info_item.get_parent() == mochila._rolagem.get_parent().get_parent())
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta+"/inventario_desktop_compacto.png")
				ui._fechar_tela("inventario")
				ui._abrir_tela("pausa")
				await quadros(20)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta+"/pausa_desktop_compacta.png")
				ui._fechar_tela("pausa")
		ui._fechar_tela("mapa_mundi")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(25)
	var coop := root.get_node("Cooperativo")
	await coop.viajar_local(coop.jogador2(),"res://cenas/casa.tscn","")
	var ui2: Node = coop.interface_p2()
	var mapa2: Control = ui2._telas["mapa_mundi"]
	ui2._abrir_tela("mapa_mundi")
	await quadros()
	verificar("coop mostra dois jogadores em ambientes diferentes",mapa2._atores["p1"].visible and mapa2._atores["p2"].visible and mapa2.regiao_atual()=="fazenda")
	var pos2: Vector2 = mapa2._atores["p2"].get_meta("ponto_carta")
	verificar("jogador 2 dentro da casa fica no ponto da fazenda",pos2.x<.4)
	ui2._fechar_tela("mapa_mundi")
	current_scene.queue_free()
	await quadros()
	print("Mapa mundi: %d falhas" % falhas)
	quit(1 if falhas else 0)
