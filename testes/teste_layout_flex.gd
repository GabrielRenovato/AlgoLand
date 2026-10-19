extends SceneTree

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
	root.get_node("Cidade").aceitar("boas_vindas")
	root.get_node("Progresso").recorde_onda = 25
	root.get_node("Transicao").estado["onda_atual"] = 21
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var ui = root.get_node("EventosJogo").interface_p1()
	var mochila = ui._telas["inventario"]
	var hud = get_first_node_in_group("hud_p1")
	for tamanho in [Vector2i(576,324),Vector2i(288,216)]:
		root.get_node("Controle").usando_toque = tamanho.x == 288
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(15)
		var sufixo := "_pc" if tamanho.x == 576 else "_mobile"
		hud.anunciar("POMBO-CORREIO!","CARTA DE LIA",30)
		await quadros(10)
		var interior: Rect2 = hud.faixa_banner.get_global_rect().grow(-10)
		verificar("carta preserva espaco acima e abaixo "+sufixo,interior.encloses(hud.rotulo_banner.get_global_rect()) and interior.encloses(hud.subtitulo_banner.get_global_rect()))
		verificar("carta separa titulo do texto "+sufixo,hud.subtitulo_banner.get_global_rect().end.y+4 <= hud.rotulo_banner.get_global_rect().position.y)
		await foto("carta_alinhada"+sufixo)
		hud.faixa_banner.hide()
		ui._abrir_tela("forja")
		await quadros(15)
		var forja = ui._telas["forja"]
		forja._mostrar_detalhes(false)
		await quadros(10)
		for botao in forja._botoes.values():
			if not botao.is_visible_in_tree():
				continue
			var conteudo: Control = botao.get_node("Conteudo").get_child(0)
			var area: Rect2 = botao.get_global_rect().grow(-7)
			for filho in conteudo.get_children(): verificar("icone e nome da receita preservam respiro "+sufixo,area.encloses(filho.get_global_rect()))
		await foto("receitas_alinhadas"+sufixo)
		ui._fechar_tela("forja")
		ui._abrir_tela("inventario")
		for aba in [1,2,3]:
			mochila.selecionar_pagina(aba)
			await quadros(15)
			if aba == 1:
				var cartao = mochila._missoes._lista.get_child(0)
				verificar("missao usa cartao compartilhado do mural "+sufixo,cartao.has_node("Conteudo") and cartao.find_children("*","TextureRect",true,false).size() == 1)
			else:
				var pagina = mochila._desafios if aba == 2 else mochila._pesca
				var grade: GridContainer = pagina._grade_catalogo
				var primeiro: Button = grade.get_child(0)
				var ultimo: Button = grade.get_child(grade.columns-1)
				verificar("grade distribui espacos simetricos "+str(aba)+sufixo,absf(primeiro.position.x-(grade.size.x-ultimo.get_rect().end.x)) <= 2)
				verificar("grade preserva colunas uniformes "+str(aba)+sufixo,primeiro.size == Vector2(32,32) and ultimo.size == Vector2(32,32))
				var slot: Button = grade.get_child(0)
				pagina._mostrar_dica(slot.name,slot)
				await quadros(10)
				if not mochila.get_node("Sidebar").get_global_rect().grow(-8).encloses(pagina._dica.get_global_rect()): print("RETANGULOS DICA ",mochila.get_node("Sidebar").get_global_rect()," / ",pagina._dica.get_global_rect())
				verificar("tooltip fica dentro da interface "+str(aba)+sufixo,mochila.get_node("Sidebar").get_global_rect().grow(-8).encloses(pagina._dica.get_global_rect()))
				verificar("tooltip preserva margem interna "+str(aba)+sufixo,pagina._dica.get_global_rect().grow(-8).encloses(pagina._rolagem_dica.get_global_rect()))
				await foto("tooltip_"+str(aba)+sufixo)
				pagina._fechar_dica()
			await foto(["","missao","catalogo_armas","catalogo_pesca"][aba]+"_alinhado"+sufixo)
		ui._fechar_tela("inventario")
		ui._abrir_tela("desafio_arena")
		await quadros(15)
		var portal = ui._telas["desafio_arena"]
		var mapa = portal._lista.find_child("MapaJornada",true,false)
		verificar("mapa abre no trecho do recorde "+sufixo,mapa.recorde == 25 and mapa._marcos.has(25))
		verificar("mapa distingue entrada alcançada e futura "+sufixo,mapa._marcos[21].tooltip_text.contains("SUA ENTRADA") and mapa._marcos[25].tooltip_text.contains("ALCANCADA") and mapa._marcos[26].tooltip_text.contains("AINDA NAO"))
		var previa = mapa._marcos[21].find_child("Inimigos",true,false)
		verificar("ondas futuras mostram silhueta sem nome "+sufixo,mapa._marcos[26].find_child("Inimigos",true,false).self_modulate==Color.BLACK and mapa._marcos[30].find_child("Inimigos",true,false).self_modulate==Color.BLACK and not mapa._marcos[30].tooltip_text.contains("GOBLIN"))
		verificar("ondas alcancadas mostram sprite descoberto "+sufixo,previa.self_modulate==Color.WHITE)
		verificar("ondas futuras mostram silhueta sem nome "+sufixo,mapa._marcos[26].find_child("Inimigos",true,false).self_modulate==Color.BLACK and mapa._marcos[30].find_child("Inimigos",true,false).self_modulate==Color.BLACK and not mapa._marcos[30].tooltip_text.contains("GOBLIN"))
		verificar("ondas alcancadas mostram sprite descoberto "+sufixo,previa.self_modulate==Color.WHITE)
		var antes: int = previa.quadro
		previa._process(0.15)
		verificar("miniatura anima sem instanciar inimigos "+sufixo,previa.quadro != antes and get_nodes_in_group("enemy").is_empty())
		verificar("andares mostram o guardiao real do prototipo "+sufixo,mapa.modo_andares and mapa._marcos[30].find_child("Inimigos",true,false).especies == ["goblin_maromba"])
		await foto("portal_jornada"+sufixo)
		var entrada: int = portal._onda_do_portal()
		mapa._mudar_pagina(-1)
		mapa._marcos[20].pressed.emit()
		verificar("consulta de andar preserva miniatura pequena "+sufixo,mapa._marcos[17].find_child("Inimigos",true,false).custom_minimum_size == Vector2(16,16))
		verificar("consulta de chefe nao altera entrada "+sufixo,mapa._detalhe.text.contains("GUARDIAO") and portal._onda_do_portal() == entrada)
		verificar("botao de entrar fica dentro da moldura "+sufixo,portal.painel.get_global_rect().grow(-8).encloses(portal._entrada_portal.get_global_rect()))
		ui._fechar_tela("desafio_arena")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Layout flex: %d falhas" % falhas)
	quit(1 if falhas else 0)
