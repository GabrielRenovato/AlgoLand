extends "res://testes/teste_acoes_fazenda_raven.gd"
## Renderizador real e itens reais, em projeto/save isolados.
const SAIDA_ALINHAMENTO = "res://arte/previas/armaduras/alinhamento_raven/"

func _initialize(): revisar.call_deferred()

func revisar():
	var mordomo="--mordomo" in OS.get_cmdline_user_args()
	var saida=SAIDA_ALINHAMENTO+("mordomo/" if mordomo else "")
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	var jogador=current_scene.get_node("Jogador")
	var visual=jogador.get_node("HeroiRaven")
	var vp=SubViewport.new();vp.size=Vector2i(800,790)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("485044");vp.add_child(fundo)
	var fonte=preload("res://assets/ui/Planes_ValMore.ttf")
	for c in 4:
		var titulo=Label.new();titulo.text=["CARRASCO","RUBRO","MISTURADO","SO CAPACETE"][c]
		if mordomo:titulo.text=["MORDOMO","SO CARTOLA","MISTURADO","SEM CARTOLA"][c]
		titulo.position=Vector2(c*200+12,12);titulo.add_theme_font_override("font",fonte)
		titulo.add_theme_font_size_override("font_size",13);vp.add_child(titulo)
	DirAccess.make_dir_recursive_absolute(saida)
	jogador.usando_espada=false;jogador.usando_lanca=false;jogador.usando_arco=false
	for acao in ["parado","correr","espada","enxada"]:
		var colunas=6 if acao=="correr" else 4
		for q in colunas:
			var copias=[]
			for d in 4:
				for c in 4:
					jogador.aparencia_raven={"pele":0,"roupa":8,"cabelo":1,"cor":[1,1,1,1]}
					for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
					for peca in ["elmo","peitoral","luvas","botas"]:
						if not mordomo and c==3 and peca!="elmo":continue
						if mordomo and ((c==1 and peca!="elmo") or (c==3 and peca=="elmo")):continue
						var conjunto="cavaleiro_rubro" if c==1 or (c==2 and peca in ["elmo","botas"]) else "carrasco"
						if mordomo:conjunto="carrasco" if c==2 and peca!="elmo" else "cavalheiro"
						var item=Receitas.criar_item(peca+"_"+conjunto)
						assert(item!=null)
						jogador.inventario.equipados[item.categoria]=item
					jogador.inventario.equipados.arma=null
					jogador.inventario.equipados.escudo=null
					visual._porte_arma="";visual._escudo_ativo=false
					visual._direcao=d;visual._aplicar_aparencia(acao)
					var copia=copiar(visual)
					var sprites=[copia]
					for filho in copia.get_children():
						if filho is Sprite2D:sprites.append(filho)
					for sprite in sprites:
						sprite.frame=0;sprite.hframes=colunas;sprite.vframes=4;sprite.frame=d*colunas+q
					copia.position=Vector2(c*200+100,d*170+220);copia.scale=Vector2(4,4)
					vp.add_child(copia);copias.append(copia)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(saida+"%s_%d.png"%[acao,q])
			await create_timer(0.1).timeout
			for copia in copias:copia.queue_free()
			await process_frame
	print("ALINHAMENTO: compositor real, quatro direções, conjuntos completos, mistos e elmo isolado; repouso, corrida, espada e enxada")
	vp.queue_free();current_scene.queue_free();current_scene=null
	await esperar(3)
	quit()
