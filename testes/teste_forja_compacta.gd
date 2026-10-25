extends SceneTree
var falhas := 0
func _initialize() -> void:
	rodar.call_deferred()
func esperar() -> void:
	for i in 20: await process_frame
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",mensagem)
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await esperar()
	var ui = current_scene.get_node("Interface")
	ui._abrir_tela("forja")
	var tela = ui._telas["forja"]
	var progresso = root.get_node("Progresso")
	progresso.encomenda_forja = {}
	progresso.armas_fabricadas.erase("arco_curto")
	progresso.armas_liberadas.erase("arco_curto")
	tela._selecionar("arco_curto")
	await esperar()
	var desenho: TextureRect = tela._botoes["arco_curto"].find_child("Icone",true,false)
	conferir(desenho.self_modulate == Color.BLACK and tela._icone_previa.self_modulate == Color.BLACK,"receita bloqueada tem silhueta preta no catálogo e detalhe")
	var bloqueio: Label = tela._botoes["arco_curto"].find_child("Bloqueio",true,false)
	conferir(bloqueio.visible and bloqueio.text == "BLOQUEADO","catalogo indica bloqueio sem depender de cor ou tooltip")
	conferir(tela._fabricar.disabled and tela._fabricar.text == "SEM RECEITA","acao informa receita ausente")
	progresso.armas_liberadas["arco_curto"] = true
	progresso.armas_liberadas_alteradas.emit()
	await esperar()
	conferir(desenho.self_modulate == Color.WHITE and tela._icone_previa.self_modulate == Color.WHITE,"aprender receita restaura cores sem reabrir bigorna")
	conferir(not bloqueio.visible and tela._fabricar.text != "SEM RECEITA","aprender receita remove indicacoes de bloqueio imediatamente")
	progresso.armas_liberadas.erase("arco_curto")
	progresso.armas_liberadas_alteradas.emit()
	for medida in [Vector2i(576,324),Vector2i(288,216),Vector2i(288,512)]:
		root.content_scale_size = medida
		root.size = medida * 2
		await esperar()
		tela._mostrar_detalhes(false)
		await esperar()
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()),"painel cabe %s" % medida)
		for categoria in [false,true]:
			tela._mudar_categoria(categoria)
			await esperar()
			var vistos := []
			for pagina in range(ceili(float(tela._tipos_catalogo().size())/tela._por_pagina)):
				tela._pagina = pagina
				tela._atualizar_pagina()
				await esperar()
				for tipo in tela._botoes:
					var botao: Button = tela._botoes[tipo]
					if not botao.visible: continue
					vistos.append(tipo)
					conferir(tela._catalogo.get_global_rect().encloses(botao.get_global_rect()),"receita cabe %s %s" % [tipo,medida])
					conferir(botao.size.y <= 50,"cartao compacto")
					var icone: TextureRect = botao.find_child("Icone",true,false)
					conferir(icone.size.y <= 16 and icone.size.x <= 16,"icone pequeno")
					var nome: Label = botao.find_child("Nome",true,false)
					conferir(botao.get_global_rect().grow(-4).encloses(nome.get_global_rect()),"nome dentro da moldura: "+tipo)
					var aviso: Label = botao.find_child("Bloqueio",true,false)
					if aviso.visible:
						conferir(botao.get_global_rect().grow(-4).encloses(aviso.get_global_rect()),"aviso dentro da moldura: "+tipo)
						conferir(not nome.get_global_rect().intersects(aviso.get_global_rect()),"aviso separado do nome: "+tipo)
			conferir(vistos.size()==tela._tipos_catalogo().size(),"todas as receitas acessiveis")
		tela._mudar_categoria(false)
		await esperar()
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()),"painel cabe apos trocar categorias")
		var altura_livre: float = tela._catalogo.size.y - tela._grade_receitas.size.y - (tela._paginacao.size.y + 8 if tela._paginacao.visible else 0)
		conferir(altura_livre < 52 or not tela._paginacao.visible,"pagina aproveita a altura disponivel")
		conferir(tela._receitas_coluna.find_children("*","ScrollContainer",true,false).is_empty(),"catalogo sem rolagem")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-forja-%dx%d.png" % [medida.x,medida.y])
		for tipo in ["arco_curto","peitoral_cavaleiro_rubro","peitoral_soberano_astral","elmo_sentinela"]:
			tela._selecionar(tipo)
			tela._mostrar_detalhes(true)
			await esperar()
			conferir(tela._papel.get_global_rect().grow(-6).encloses(tela._custos.get_global_rect()),"todos os materiais visiveis: %s %s papel %s custos %s" % [tipo,medida,tela._papel.get_global_rect(),tela._custos.get_global_rect()])
			if DisplayServer.get_name() != "headless" and tipo == "peitoral_soberano_astral":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-forja-astral-%dx%d.png" % [medida.x,medida.y])
		tela._selecionar("arco_curto")
		await esperar()
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela._fabricar.get_global_rect()),"fabricar visivel")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-forja-detalhes-%dx%d.png" % [medida.x,medida.y])
		# Quatro materiais nas ferramentas também precisam caber no celular.
		tela._mudar_categoria(true)
		tela._selecionar("enxada")
		tela._mostrar_detalhes(true)
		await esperar()
		conferir(tela._icone_previa.self_modulate == Color.WHITE,"ferramenta mantém cor após consultar receita bloqueada")
		conferir(tela._custos.get_child_count()==4,"quatro materiais presentes na melhoria")
		conferir(tela._papel.get_global_rect().grow(-6).encloses(tela._custos.get_global_rect()),"custos da ferramenta cabem: %s" % medida)
		for linha in tela._custos.get_children():
			for filho in linha.get_children():
				conferir(linha.get_global_rect().encloses(filho.get_global_rect()),"material da ferramenta sem corte")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-ferramentas-%dx%d.png" % [medida.x,medida.y])
	print("FORJA COMPACTA: ",falhas," falhas")
	quit(1 if falhas else 0)
