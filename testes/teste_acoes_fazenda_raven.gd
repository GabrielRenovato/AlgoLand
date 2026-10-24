extends SceneTree
## Cena e save isolados: cobre o roteamento modular, tempos/impactos e combinações.
const Raven=preload("res://codigo/dados/aparencia_raven.gd")
const Tempos=preload("res://codigo/jogador/fazenda_jogador.gd")
const Receitas=preload("res://codigo/dados/forja_armas.gd")
const SAIDA="res://arte/previas/personagens/acoes_fazenda_raven/revisao_20261023/"
var falhas=0
var verificacoes=0
var impactos: Array[String]=[]
func _initialize():rodar.call_deferred()
func conferir(ok: bool, mensagem: String):
	verificacoes+=1
	if not ok:falhas+=1;push_error(mensagem)
func esperar(n: int):
	for i in n:await process_frame
func copiar(fonte: Sprite2D) -> Sprite2D:
	var novo=Sprite2D.new()
	for prop in ["texture","material","centered","offset","hframes","vframes","frame","modulate","self_modulate","visible","z_index"]:novo.set(prop,fonte.get(prop))
	novo.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for filho in fonte.get_children():
		if filho is Sprite2D:novo.add_child(copiar(filho))
	return novo
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva=12
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	root.get_node("Transicao").limpar()
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	var jogador=current_scene.get_node("Jogador")
	var visual= jogador.get_node("HeroiRaven")
	var antigo=Raven.folha("corpo_0","parado")
	for acao in ["plantar","colher"]:
		for nome in ["corpo_0","corpo_1","corpo_2","calca_marrom","calca_jeans","camisa_azul","camisa_verde","botas","luvas","capa","aljava","vazio","ferramentas","escudo_tras","escudo_frente"]:
			conferir(Raven.folha(nome,acao).get_size()==Vector2(320,320),"Folha nova: "+acao+nome)
		for cabelo in range(1,29):
			var imagem=Raven.folha("cabelo_%d"%cabelo,acao).get_image()
			for d in 4:
				for q in 4:
					var r=imagem.get_region(Rect2i(q*80,d*80,80,80)).get_used_rect()
					conferir(r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<80 and r.end.y<80,"Cabelo íntegro na célula: %s/%d/%d/%d"%[acao,cabelo,d,q])
		for conjunto in ["carrasco","cavaleiro_rubro","cavalheiro"]:
			var imagens=[]
			for peca in ["elmo","peitoral","luvas","botas"]:
				imagens.append(Raven.folha_arquivo("res://assets/personagens/conjuntos/"+conjunto+"/raven_"+peca+".png",acao).get_image())
			var sobrepostos=0
			for y in 320:
				for x in 320:
					var n=0
					for im in imagens: if im.get_pixel(x,y).a>0.5:n+=1
					if n>1:sobrepostos+=1
			conferir(sobrepostos==0,"Peças independentes sem sobreposição: "+conjunto+acao)
	conferir(Raven.folha("corpo_0","parado")==antigo,"Demais ações preservam textura original")
	# Usa a ação real do jogador, sem substituir o controlador de impactos.
	jogador.acao_fazenda_impacto.connect(func(acao,_ponto):impactos.append(acao))
	for acao in ["plantar","colher"]:
		var esperados=[0.30,0.10,0.10,0.10] if acao=="plantar" else [0.40,0.24,0.18,0.30]
		for q in 4:conferir(is_equal_approx(Tempos.ACOES[acao].quadros[q][1],esperados[q]),"Tempo da referência Mana Seed: "+acao+str(q))
		jogador.movimento_habilitado=true
		jogador.estaMorto=false
		jogador.esta_em_dash=false
		jogador._esta_atacando=false
		conferir(jogador.acao_fazenda(acao),"Ação real inicia: "+acao)
		for q in 4:
			visual._process(0)
			conferir(impactos.count(acao)==(1 if q >= (1 if acao=="plantar" else 2) else 0),"Impacto no quadro correto: "+acao+str(q))
			conferir(visual._animacao==acao and visual.frame%4==q,"Estado e quadro reais: "+acao+str(q))
			conferir(visual.texture==Raven.folha("corpo_0",acao),"Corpo modular ativo: "+acao)
			var dt=Tempos.ACOES[acao].quadros[q][1]
			jogador.no_fazenda._process(dt)
		conferir(not jogador.esta_em_acao_fazenda,"Fim libera jogador: "+acao)
		visual._process(0)
		conferir(visual._animacao=="parado","Retorno ao repouso real: "+acao)
	conferir(impactos==["plantar","colher"],"Um impacto por ação e na ordem correta")
	var vp=SubViewport.new()
	vp.size=Vector2i(640,640)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("515e47");vp.add_child(fundo)
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var configs=[
		{"nome":"comum","pele":0,"cabelo":1,"roupa":1,"pecas":[]},
		{"nome":"capa","pele":1,"cabelo":28,"roupa":8,"pecas":[]},
		{"nome":"verde","pele":2,"cabelo":14,"roupa":4,"pecas":[]},
		{"nome":"carrasco","pele":0,"cabelo":7,"roupa":5,"pecas":["elmo_carrasco","peitoral_carrasco","luvas_carrasco","botas_carrasco"]},
		{"nome":"rubro","pele":1,"cabelo":10,"roupa":6,"pecas":["elmo_cavaleiro_rubro","peitoral_cavaleiro_rubro","luvas_cavaleiro_rubro","botas_cavaleiro_rubro"]},
		{"nome":"mordomo","pele":2,"cabelo":28,"roupa":8,"pecas":["elmo_cavalheiro","peitoral_cavalheiro","luvas_cavalheiro","botas_cavalheiro"]},
		{"nome":"misturado","pele":2,"cabelo":15,"roupa":8,"pecas":["elmo_cavaleiro_rubro","peitoral_carrasco","luvas_cavalheiro","botas_cavaleiro_rubro"]},
		{"nome":"peitoral_isolado","pele":0,"cabelo":4,"roupa":8,"pecas":["peitoral_carrasco"]}]
	for config in configs:
		jogador.aparencia_raven={"pele":config.pele,"cabelo":config.cabelo,"roupa":config.roupa,"cor":[0.75,0.8,1.0,1.0]}
		for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
		for tipo in config.pecas:
			var item=Receitas.criar_item(tipo)
			conferir(item!=null,"Equipamento real: "+tipo)
			jogador.inventario.equipados[item.categoria]=item
		for acao in ["plantar","colher"]:
			var copias=[]
			for d in 4:
				jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
				jogador.esta_em_acao_fazenda=true
				jogador.no_fazenda.tocar(acao,jogador._direcao_ataque)
				for q in 4:
					jogador.no_fazenda._indice=q
					visual._process(0)
					var copia=copiar(visual)
					copia.scale=Vector2(3,3)
					copia.position=Vector2(q*160+80,d*160+140)
					vp.add_child(copia);copias.append(copia)
			jogador.cancelar_acao_fazenda()
			conferir(visual._camadas[4].z_index==0 if config.roupa>=5 and config.pecas.is_empty() else true,"Capa mantém o dorso coberto; braços são recortados na folha")
			await esperar(2)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(SAIDA+config.nome+"-"+acao+".png")
			if config.nome=="capa":
				var com_capa=vp.get_texture().get_image()
				for copia in copias:copia.get_child(4).hide()
				await RenderingServer.frame_post_draw
				var sem_capa=vp.get_texture().get_image()
				for d in 4:
					for q in [2,3]:
						var visiveis=0
						for y in range(d*160,(d+1)*160):
							for x in range(q*160,(q+1)*160):
								if com_capa.get_pixel(x,y)!=sem_capa.get_pixel(x,y):visiveis+=1
						print("CAPA VISIVEL ",acao,"/",d,"/",q,": ",visiveis/9.0," pixels nativos")
						conferir(visiveis>=40*9,"Capa preserva tecido visível com braços erguidos: %s/%d/%d"%[acao,d,q])
			for copia in copias:copia.queue_free()
			await esperar(1)
	print("ACOES FAZENDA RAVEN: ",verificacoes," verificações; ",falhas," falhas")
	vp.queue_free();current_scene.queue_free();current_scene=null
	await esperar(3)
	quit(1 if falhas else 0)
