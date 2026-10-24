extends "res://testes/teste_acoes_fazenda_raven.gd"
## Prévia reproduz os controladores reais em passos20ms, sem escrever no save.
func _initialize():previa.call_deferred()
func previa():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(25)
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	var jogador=current_scene.get_node("Jogador")
	var visual=jogador.get_node("HeroiRaven")
	var vp=SubViewport.new()
	vp.size=Vector2i(640,360)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("515e47");vp.add_child(fundo)
	for linha in 2:
		var texto=Label.new();texto.text=["PLANTAR","COLHER"][linha];texto.position=Vector2(16,14+linha*180);texto.add_theme_font_size_override("font_size",13);vp.add_child(texto)
	var configuracoes=[
		{"pele":0,"cabelo":1,"roupa":1,"itens":[]},
		{"pele":1,"cabelo":28,"roupa":8,"itens":[]},
		{"pele":2,"cabelo":14,"roupa":8,"itens":["elmo_cavaleiro_rubro","peitoral_carrasco","luvas_cavalheiro","botas_cavaleiro_rubro"]}]
	DirAccess.make_dir_recursive_absolute(SAIDA+"motor")
	var numero=0
	for d in 4:
		for instante in 86:
			var copias=[]
			for linha in 2:
				var acao=["plantar","colher"][linha]
				for c in configuracoes.size():
					var config=configuracoes[c]
					jogador.aparencia_raven={"pele":config.pele,"cabelo":config.cabelo,"roupa":config.roupa,"cor":[1,1,1,1]}
					for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
					for tipo in config.itens:
						var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
					jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
					jogador.esta_em_acao_fazenda=true
					jogador.no_fazenda.tocar(acao,jogador._direcao_ataque)
					# Após a ação completa o mesmo controlador sinaliza o retorno ao repouso.
					jogador.no_fazenda._process(instante*0.02)
					visual._process(0)
					var copia=copiar(visual)
					copia.scale=Vector2(3,3)
					copia.position=Vector2(c*195+110,linha*180+155)
					vp.add_child(copia);copias.append(copia)
					jogador.cancelar_acao_fazenda()
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(SAIDA+"motor/%03d.png"%numero)
			numero+=1
			for copia in copias:copia.queue_free()
			await process_frame
	print("OK prévia: ",numero," quadros,20ms, roupas/capa/mistura real, quatro direções e retorno ao repouso")
	vp.queue_free();current_scene.queue_free();current_scene=null
	await esperar(3)
	quit()
