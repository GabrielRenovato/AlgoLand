extends SceneTree
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
var cena:Node2D
var falhas:=0
const CAPTURAS:="res://capturas-moradores-primeira-raiz"
func _initialize() -> void:rodar.call_deferred()
func conferir(texto: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok:falhas+=1
func quadros(n:=8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	conferir("captura "+nome,root.get_texture().get_image().save_png(CAPTURAS.path_join(nome+".png"))==OK)
func fechar() -> void:
	var dialogo: Node=cena.interface._telas.introducao
	# Rosa e Tomás terminam num menu de serviços: a saída é a última opção.
	if not dialogo._opcoes.is_empty():
		dialogo._texto.visible_ratio=1.0
		dialogo._espera=0.0
		dialogo._escolher(dialogo._opcoes.size()-1)
		await quadros(3)
	if dialogo.visible:dialogo._fechar_fala()
	await quadros(3)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(CAPTURAS)
	root.get_node("Ranking").conexao_habilitada=false
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	var dados:=Elenco.dados()
	conferir("elenco fechado: oito centrais e sete de apoio",dados.size()==15 and dados.values().filter(func(p):return p.importante).size()==8 and not dados.has("bento"))
	for id in dados:
		var f:=Elenco.ficha(id)
		conferir("identidade e conversas completas "+id,f==Elenco.ficha(id) and f.nome==dados[id].nome and not Elenco.conversa(id,0).is_empty() and Elenco.conversa(id,1)!=Elenco.conversa(id,2))
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(45)
	cena=current_scene
	# Preparação exclusiva deste save de teste; sem mudar a campanha de produção.
	conferir("libera vila isolada",cena.controlador.progresso.confirmar_conclusao("sobreviver_queda")==OK and cena.controlador.progresso.confirmar_conclusao("estrada_interrompida")==OK)
	conferir("abre cidade",cena.abrir_regiao("vila")==OK)
	await quadros(20)
	# Este teste confere a vila em si: a cena de chegada da primeira visita fica fora.
	if cena.cinema_cidade_ativa(): cena.cinema_cidade.cancelar()
	cena.jogador.desabilitar_todas_acoes(false)
	# A vila abre à noite no save novo; passeio e conversas são conferidos de dia.
	cena.hora_da_cidade=10
	for npc in cena.moradores.values(): npc.atualizar_rotina(10,true)
	conferir("quinze moradores instanciados",cena.moradores.size()==15)
	var inicio:Dictionary={}
	var mapa:=cena.get_world_2d().navigation_map
	for id in cena.moradores:
		var npc:Node=cena.moradores[id]
		inicio[id]=npc.position
		conferir("NPC único e interativo "+id,cena.alvos[id].no==npc and is_instance_valid(cena.alvos[id].rotulo) and npc.visual.heroi.acabamento_pixel_art)
		var navegavel:=true
		for destino in npc.rota:
			var caminho:=NavigationServer2D.map_get_path(mapa,npc.position,destino,true)
			navegavel=navegavel and cena.terreno.ponto_seguro(destino) and not caminho.is_empty() and caminho[-1].distance_to(destino)<2
		conferir("rota conectada e livre "+id,navegavel)
	await quadros(200)
	for id in inicio:
		conferir("morador passeia "+id,cena.moradores[id].distancia_andada>4)
		conferir("permanece fora de obstáculos "+id,cena.terreno.ponto_seguro(cena.moradores[id].position))
	for id in cena.moradores:
		var npc:Node=cena.moradores[id]
		cena.jogador.position=npc.position+Vector2(0,12)
		cena.jogador.velocity=Vector2.ZERO
		await quadros(2)
		var anterior:Dictionary=cena.controlador.progresso.retrato()
		anterior.erase("retorno")
		# A memória das conversas (visitas e reações ouvidas) não é avanço de missão.
		anterior.erase("conversas")
		conferir("conversa disponível "+id,cena.interagir_proximo()==OK)
		await quadros(2)
		conferir("fala identificada e NPC parado "+id,cena.interface._telas.introducao.visible and npc.conversando and npc.velocity==Vector2.ZERO)
		if id!="dara":
			var depois:Dictionary=cena.controlador.progresso.retrato()
			depois.erase("retorno")
			depois.erase("conversas")
			conferir("conversa não antecipa campanha "+id,depois==anterior)
		await fechar()
		conferir("fechar libera rotina "+id,not npc.conversando)
	await conferir_criancas()
	await conferir_familias()
	var ivo:Node=cena.moradores.ivo
	ivo.set_physics_process(false)
	cena.jogador.position=ivo.position+Vector2(0,48)
	cena.jogador.get_node("Camera2D").reset_smoothing()
	await quadros(5)
	var duracao:float=ivo.visual.heroi._player.get_animation("Walk_Loop").length
	for direcao in 4:
		for fase in 8:
			ivo.visual.pose_caminhada(true,direcao,duracao*fase/8.0)
			await quadros(2)
			conferir("caminhada real %d/%d" % [direcao,fase],ivo.visual.heroi._player.assigned_animation=="Walk_Loop")
			await RenderingServer.frame_post_draw
			ivo.visual.heroi._vp.get_texture().get_image().save_png(CAPTURAS.path_join("andar_%d_%02d.png" % [direcao,fase]))
	ivo.set_physics_process(true)
	# Diálogo longo nas três proporções; usa paginação e moldura já existentes.
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		# Conferência de layout: Estela de dia, fora de casa.
		cena.hora_da_cidade=10
		cena.moradores.estela.atualizar_rotina(10,true)
		cena.jogador.position=cena.moradores.estela.position+Vector2(0,12)
		cena.jogador.get_node("Camera2D").reset_smoothing()
		await quadros(3)
		conferir("abre fala em %s" % tamanho,cena.interagir_proximo()==OK)
		var dialogo:Node=cena.interface._telas.introducao
		dialogo._texto.visible_ratio=1
		await quadros(18)
		var moldura:Rect2=dialogo.painel.get_global_rect()
		conferir("texto e botões cabem na conversa %s" % tamanho,moldura.encloses(dialogo._titulo.get_global_rect()) and moldura.encloses(dialogo._texto.get_global_rect()) and moldura.encloses(dialogo._avancar.get_global_rect()) and not dialogo._texto.get_global_rect().intersects(dialogo._avancar.get_global_rect()))
		await foto("dialogo_%dx%d" % [tamanho.x,tamanho.y])
		await fechar()
	root.content_scale_size=Vector2i(1536,1024)
	root.size=Vector2i(1536,1024)
	cena.jogador.position=Vector2.ZERO
	cena.jogador.get_node("Camera2D").zoom=Vector2.ONE
	cena.jogador.get_node("Camera2D").reset_smoothing()
	await quadros(4)
	await foto("cidade_15_moradores")
	conferir("trocar de região funciona",cena.abrir_regiao("chegada")==OK)
	await quadros(3)
	conferir("elenco removido ao sair",cena.moradores.is_empty())
	conferir("retornar à vila",cena.abrir_regiao("vila")==OK)
	await quadros(10)
	conferir("retorno não duplica população",cena.moradores.size()==15 and cena.get_children().filter(func(n):return n.get_script()!=null and n.get_script().resource_path=="res://codigo/npcs/npc_gerado.gd").size()==15)
	print("FALHAS: ",falhas)
	quit(falhas)

func conferir_criancas() -> void:
	var mapa:=cena.get_world_2d().navigation_map
	for id in ["teo","bia","nina"]:
		var npc:Node=cena.moradores[id]
		var f:=Elenco.ficha(id)
		conferir("corpo e roupas infantis " + id,npc.visual.get_script().resource_path.ends_with("manequim_infantil_3d.gd") and npc.visual.traje_infantil==f.traje_infantil and npc.visual.cabelo_infantil==f.cabelo_infantil)
		conferir("ficha infantil sobrevive normalização " + id,load("res://codigo/dados/gerador_npcs.gd").normalizar(f)==f)
		for periodo in npc.rotina:
			var livre:=true
			for ponto in periodo.rota:
				var caminho:=NavigationServer2D.map_get_path(mapa,npc.position,ponto,true)
				livre=livre and cena.terreno.ponto_seguro(ponto) and not caminho.is_empty() and caminho[-1].distance_to(ponto)<2
			conferir("trajeto da atividade " + id + "/" + periodo.id,livre)
		cena.hora_da_cidade=14
		npc.atualizar_rotina(14)
		conferir("tarde de brincadeira "+id,npc.atividade_atual=="brincadeira" and npc.visible)
		npc.iniciar_conversa(npc.position+Vector2.DOWN*12)
		npc.atualizar_rotina(20)
		conferir("conversa segura mudança de agenda "+id,npc.atividade_atual=="brincadeira" and npc.conversando)
		npc.encerrar_conversa()
		conferir("fim da conversa retoma horário pendente "+id,npc.atividade_atual=="casa")
		cena.hora_da_cidade=20
		npc.position=npc.rota[0]
		await quadros(3)
		conferir("recolhe à noite sem alvo invisível "+id,not npc.visible)
		cena.hora_da_cidade=7
		npc.atualizar_rotina(7)
		conferir("acorda para ajudar família "+id,npc.visible and npc.atividade_atual=="ajuda")
		cena.hora_da_cidade=10
		npc.atualizar_rotina(10)
		# Mesmos quadros e duração do clipe realmente reproduzido na cidade.
		npc.set_physics_process(false)
		var duracao:float=npc.visual.duracao_caminhada()
		for direcao in 4:
			for fase in 12:
				npc.visual.pose_caminhada(true,direcao,duracao*fase/12.0)
				await quadros(2)
				await RenderingServer.frame_post_draw
				npc.visual.heroi._vp.get_texture().get_image().save_png(CAPTURAS.path_join("infantil_%s_%d_%02d.png" % [id,direcao,fase]))
		conferir("caminhada infantil externa "+id,npc.visual.heroi._player.assigned_animation=="infantis/Caminhada_Infantil")
		npc.set_physics_process(true)
	# Diálogo infantil contextual e moldura nos três formatos suportados.
	var bia:Node=cena.moradores.bia
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		cena.hora_da_cidade=14
		bia.atualizar_rotina(14)
		cena.jogador.position=bia.position+Vector2(0,12)
		cena.jogador.get_node("Camera2D").reset_smoothing()
		cena._visitas_moradores.bia=1
		# As reações ao progresso já foram ouvidas: aqui interessa a fala da rotina.
		cena._reacoes_moradores.bia=cena.MARCOS_REACAO+cena.PEDIDOS_REACAO
		conferir("fala ligada à brincadeira",cena._conversar_morador("bia")==OK)
		var dialogo:Node=cena.interface._telas.introducao
		dialogo._texto.visible_ratio=1
		await quadros(12)
		conferir("fala contextual na tela",dialogo._texto.text.contains("Nina"))
		var moldura:Rect2=dialogo.painel.get_global_rect()
		conferir("diálogo infantil cabe "+str(tamanho),moldura.encloses(dialogo._titulo.get_global_rect()) and moldura.encloses(dialogo._texto.get_global_rect()) and not dialogo._texto.get_global_rect().intersects(dialogo._avancar.get_global_rect()))
		await foto("crianca_dialogo_%dx%d" % [tamanho.x,tamanho.y])
		await fechar()
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	cena.hora_da_cidade=10

func conferir_familias() -> void:
	var dados:=Elenco.dados()
	for par in [["mara","teo"],["cora","bia"],["rosa","nina"]]:
		var adulto:Node=cena.moradores[par[0]]
		var crianca:Node=cena.moradores[par[1]]
		conferir("vínculo familiar recíproco "+par[0],dados[par[0]].criancas==[par[1]] and dados[par[1]].responsavel==par[0])
		var mapa:=cena.get_world_2d().navigation_map
		for periodo in adulto.rotina:
			var livre:=true
			for ponto in periodo.rota:
				var caminho:=NavigationServer2D.map_get_path(mapa,adulto.position,ponto,true)
				livre=livre and cena.terreno.ponto_seguro(ponto) and not caminho.is_empty() and caminho[-1].distance_to(ponto)<2
			conferir("caminho familiar "+par[0]+"/"+periodo.id,livre)
		cena.hora_da_cidade=16
		var inicio:Vector2=adulto.position
		adulto.atualizar_rotina(16)
		conferir("responsável vai buscar sem teleporte "+par[0],adulto.atividade_atual=="buscar" and adulto.position==inicio and adulto.visible and adulto.velocidade==12)
		await quadros(40)
		conferir("busca caminha pela cidade "+par[0],adulto.position.distance_to(inicio)>2)
		conferir("preocupação menciona a criança "+par[0],str(adulto.falas_atividade).contains(dados[par[1]].nome))
		adulto.iniciar_conversa(cena.jogador.position)
		adulto.atualizar_rotina(18)
		conferir("conversa preserva busca até fechar "+par[0],adulto.atividade_atual=="buscar")
		adulto.encerrar_conversa()
		conferir("retoma volta para casa "+par[0],adulto.atividade_atual=="volta_familia")
	# Carregar às 7h coloca cada família junta no local correto.
	cena.hora_da_cidade=7
	conferir("sai para conferir manhã",cena.abrir_regiao("chegada")==OK)
	await quadros(3)
	conferir("volta na hora da família",cena.abrir_regiao("vila")==OK)
	await quadros(20)
	for par in [["mara","teo"],["cora","bia"],["rosa","nina"]]:
		var adulto:Node=cena.moradores[par[0]]
		var crianca:Node=cena.moradores[par[1]]
		conferir("família junta pela manhã "+par[0],adulto.atividade_atual=="familia" and crianca.atividade_atual=="ajuda" and adulto.position.distance_to(crianca.position)>10 and adulto.position.distance_to(crianca.position)<40)
		cena.jogador.position=adulto.position+Vector2(0,32)
		cena.jogador.get_node("Camera2D").reset_smoothing()
		await quadros(4)
		await foto("familia_"+par[0])
	# Rosa continua disponível para objetivos; o diálogo familiar usa a moldura existente.
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		cena.hora_da_cidade=16
		cena.moradores.rosa.atualizar_rotina(16)
		cena.jogador.position=cena.moradores.rosa.position+Vector2(0,12)
		cena.jogador.get_node("Camera2D").reset_smoothing()
		cena._visitas_moradores.rosa=1
		conferir("conversa com responsável",cena._conversar_morador("rosa")==OK)
		var dialogo:Node=cena.interface._telas.introducao
		dialogo._texto.visible_ratio=1
		await quadros(12)
		conferir("responsável procura sobrinha no diálogo",dialogo._texto.text.contains("Nina"))
		var moldura:Rect2=dialogo.painel.get_global_rect()
		conferir("fala familiar cabe "+str(tamanho),moldura.encloses(dialogo._texto.get_global_rect()) and moldura.encloses(dialogo._titulo.get_global_rect()) and not dialogo._texto.get_global_rect().intersects(dialogo._avancar.get_global_rect()))
		await foto("familia_dialogo_%dx%d" % [tamanho.x,tamanho.y])
		await fechar()
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	cena.hora_da_cidade=10
	for morador in cena.moradores.values():morador.atualizar_rotina(10)
	conferir("famílias mantêm limite da população",cena.moradores.size()==15)
