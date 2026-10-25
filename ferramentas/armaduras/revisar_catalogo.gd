extends "res://testes/teste_acoes_fazenda_raven.gd"
## Capturas pelo compositor real; somente projeto e save isolados.
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const SAIDA_CATALOGO := "res://arte/previas/armaduras/catalogo/"

func _initialize(): revisar.call_deferred()

func copiar(fonte: Sprite2D) -> Sprite2D:
	var novo := Sprite2D.new()
	for prop in ["texture","material","centered","offset","hframes","vframes","frame","modulate","self_modulate","visible","z_index","position","rotation","scale","flip_h","flip_v"]:
		novo.set(prop, fonte.get(prop))
	novo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for filho in fonte.get_children():
		if filho is Sprite2D: novo.add_child(copiar(filho))
	return novo

func revisar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var jogador = current_scene.get_node("Jogador")
	var visual = jogador.get_node("HeroiRaven")
	jogador.inventario.equipados.arma = null
	jogador.inventario.equipados.escudo = null
	jogador.usando_espada = false; jogador.usando_lanca = false; jogador.usando_arco = false
	DirAccess.make_dir_recursive_absolute(SAIDA_CATALOGO)
	var vp := SubViewport.new()
	vp.size = Vector2i(1400,660)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new(); fundo.size = vp.size; fundo.color = Color("435047"); vp.add_child(fundo)
	var titulos := []
	for c in Conjuntos.CONJUNTOS.size():
		var conjunto = Conjuntos.CONJUNTOS[c]
		var titulo := Label.new()
		titulo.position = Vector2(c*140+10,12)
		titulo.size = Vector2(120,65)
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.text = conjunto.NOME+"\n"+conjunto.RARIDADE.to_upper()
		titulo.add_theme_font_size_override("font_size",12)
		vp.add_child(titulo); titulos.append(titulo)
	var acoes := ["parado","correr","espada","lanca","arco","esquiva","ferido","colher","plantar","picareta","enxada","regar","machado","forjar","sentado","morrer"]
	for acao in acoes:
		var quadros := 6 if acao == "correr" else 4
		for q in quadros:
			var copias := []
			for c in Conjuntos.CONJUNTOS.size():
				var conjunto = Conjuntos.CONJUNTOS[c]
				jogador.aparencia_raven = {"pele":0,"roupa":8,"cabelo":28,"cor":[1,1,1,1]}
				for tipo in conjunto.TIPOS:
					var item = Receitas.criar_item(tipo)
					jogador.inventario.equipados[item.categoria] = item
				for d in 4:
					visual._porte_arma = ""; visual._escudo_ativo = false
					visual._arma_costas.visible = false
					visual._direcao = d; visual._aplicar_aparencia(acao)
					var copia := copiar(visual)
					var sprites := [copia]
					for filho in copia.get_children():
						if filho is Sprite2D: sprites.append(filho)
					for sprite in sprites:
						sprite.frame = 0; sprite.hframes = quadros; sprite.vframes = 4; sprite.frame = d*quadros+q
					copia.position = Vector2(c*140+70,d*140+200)
					copia.scale = Vector2(3,3)
					vp.add_child(copia); copias.append(copia)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(SAIDA_CATALOGO+"%s_%d.png" % [acao,q])
			for copia in copias: copia.queue_free()
			await process_frame
	# Reprodução real de dois ciclos de corrida em cada direção, usando o controlador original.
	for conjunto in Conjuntos.CONJUNTOS.slice(3):
		for tipo in conjunto.TIPOS:
			var item = Receitas.criar_item(tipo)
			jogador.inventario.equipados[item.categoria] = item
		for d in 4:
			jogador._direcao_ataque = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
			jogador.velocity = jogador._direcao_ataque*80
			for instante in 12:
				visual._process(0.1)
				await RenderingServer.frame_post_draw
			assert(visual._animacao == "correr")
		print("REPRODUCAO REAL: ", conjunto.ID, " corrida nas quatro direções, 2 ciclos de 0,6s")
	jogador.velocity = Vector2.ZERO; visual._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA_CATALOGO+"no_jogo.png")
	print("CATALOGO VISUAL: dez conjuntos, quatro direções, dezesseis ações e corrida pelo controlador real")
	vp.queue_free(); current_scene.queue_free(); current_scene = null
	await esperar(3)
	quit()
