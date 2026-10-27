extends SceneTree
const Visual := preload("res://codigo/dados/visual_ranking.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 8) -> void:
	for i in n: await process_frame
func conferir(ok: bool, texto: String) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/migracao-3d-"+nome+".png")
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var dados := {"versao":1,"escudo":true,"pele":2,"olhos":3,"cor":[.5,.3,.8,1],"roupas_3d":{"cabelo":"cabelo_cacheado","camisa":"blusa_bufante","calca":"saia_campo","calcado":"sapatilhas_vinho"}}
	var malicioso := Visual.normalizar({"versao":1,"roupa":{},"roupas_3d":{"cabelo":"res://segredo","camisa":[]},"olhos":99})
	conferir(malicioso.roupas_3d.cabelo=="cabelo_curto" and malicioso.olhos==5,"Aparência remota aceita apenas catálogo local")
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(30)
	var jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = dados.duplicate(true)
	var heroi = jogador.get_node("HeroiBase3D")
	heroi.definir_roupas_3d(dados.roupas_3d)
	await esperar()
	conferir(Visual.do_jogador(jogador).roupas_3d==dados.roupas_3d,"Retrato público inclui roupas e cabelo atuais")
	var sequencia = load("res://codigo/introducao/sequencia_introducao.gd").new()
	sequencia.jogador = jogador
	heroi.set_process(false)
	for quadro in [6,2,1,0]:
		sequencia._quadro_da_queda(quadro)
		await esperar(3)
		conferir(heroi._player.assigned_animation.begins_with("Jump_"),"Introdução usa queda e aterrissagem do rig 3D")
	sequencia.free()
	heroi.set_process(true)
	await esperar()
	var cama = get_first_node_in_group("cama")
	cama.deitar(jogador)
	await esperar()
	var cabeca = cama.get_node("Cabeca")
	conferir(cabeca.rosto!=null and cabeca.rosto.texture.get_image().get_used_rect().has_area(),"Cama recorta a cabeça 3D")
	conferir(cabeca.previa.heroi._modelo.find_child("CorpoBase",true,false).material_override.get_shader_parameter("olhos_fechados"),"Sono fecha os olhos no material independente")
	conferir(not bool(heroi._modelo.find_child("CorpoBase",true,false).material_override.get_shader_parameter("olhos_fechados")),"Cama preserva os olhos do jogador")
	await foto("cama")
	cabeca.previa.heroi._vp.get_texture().get_image().save_png("/tmp/migracao-3d-cabeca-inteira.png")
	cabeca.rosto.texture.get_image().save_png("/tmp/migracao-3d-rosto.png")
	cama.levantar()
	await esperar()
	jogador.aplicar_petrificacao(2.0)
	conferir(not heroi.is_processing() and not heroi._player.active,"Petrificação congela o modelo e a animação 3D")
	await foto("pedra")
	jogador.petrificacao.liberar()
	conferir(heroi.is_processing() and heroi._player.active,"Fim da petrificação restaura o modelo 3D")
	jogador.petrificacao.aplicar(.05,true)
	jogador.petrificacao.atualizar(.1)
	conferir(not heroi.visible,"Petrificação fatal oculta o modelo 3D ao esfarelar")
	jogador.petrificacao.limpar()
	conferir(heroi.visible and heroi.is_processing() and heroi._player.active,"Limpeza da petrificação fatal restaura o modelo")
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await esperar()
	var tela = ui._telas["inventario"]
	heroi.set_process(false)
	heroi._player.active = false
	var instante: float = heroi._player.current_animation_position
	tela._atualizar_boneco()
	await esperar()
	conferir(tela._previa.heroi.roupas_3d==heroi.roupas_3d and tela._previa.aparencia_raven.olhos==3,"Mochila acompanha o visual 3D atual")
	conferir(heroi._player.current_animation_position==instante,"Mochila usa animação independente")
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await esperar()
		var previa: Node2D = tela._previa
		var desenho: Rect2 = previa.global_transform*previa.retangulo_aparente()
		for slot in tela._slots_equipamento.values():
			conferir(not desenho.grow(2).intersects(slot.get_global_rect()),"Mochila: margem dos slots "+str(tamanho))
		await foto("inventario-%dx%d"%[tamanho.x,tamanho.y])
	change_scene_to_file("res://cenas/cidade/enfermaria.tscn")
	await esperar(30)
	jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = dados.duplicate(true)
	jogador.get_node("HeroiBase3D").definir_roupas_3d(dados.roupas_3d)
	var paciente = current_scene._deitar_no_leito(jogador)
	await esperar(12)
	conferir(paciente!=null and paciente.get_node("Cabeca").rosto!=null,"Enfermaria mostra o mesmo rosto 3D sob o cobertor")
	await foto("enfermaria")
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(30)
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(432,280)
	var podio = current_scene.get_node("PodioRanking")
	var linhas: Array = []
	for i in 3:
		linhas.append({"apelido":"WWWWWWWWWWWWWWWW","arma_mais_usada":["espada_basica","machado","arco_curvo"][i],"aparencia":dados,"andar":20-i})
	podio._atualizar_lista(linhas)
	await esperar(12)
	for ator in podio.ocupantes.get_children():
		var personagem = ator.get_node("Personagem")
		var nome: Label = ator.get_node("Nickname")
		conferir(personagem.heroi.roupas_3d==dados.roupas_3d,"Pódio usa a aparência 3D publicada")
		conferir(is_zero_approx(nome.position.x+nome.size.x/2) and nome.position.y+nome.size.y<personagem.topo_aparente(),"Pódio: nome centralizado acima da cabeça")
	await foto("podio")
	var remoto = load("res://codigo/cidade/jogador_lobby.gd").new()
	current_scene.add_child(remoto)
	remoto.set_process(false)
	remoto.atualizar({"id":"teste","apelido":"Avatar 3D","direcao":0,"x":425,"y":290},Visual.normalizar(dados),true)
	for arma in ["espada_basica","espada_gemea","lanca_basica","machado","maca","arco_curvo"]:
		dados.arma_mais_usada = arma
		remoto.atualizar({"id":"teste","apelido":"Avatar 3D","direcao":0,"x":425,"y":290},Visual.normalizar(dados))
		if arma=="espada_basica":
			conferir(remoto.corpo.heroi._escudo.visible,"Lobby preserva o escudo publicado")
		for direcao in 4:
			remoto.corpo.pose(true,direcao,.15)
			await esperar(2)
			for acao in [("arco" if arma=="arco_curvo" else remoto.corpo.nome_do_golpe(2)),"esquiva"]:
				for progresso in [.0,.3,.7,.99]:
					remoto.corpo.pose_acao(acao,int(progresso*4),direcao,progresso)
					await esperar(2)
					if direcao==0 and acao!="esquiva":
						await RenderingServer.frame_post_draw
						remoto.corpo.heroi._vp.get_texture().get_image().save_png("/tmp/migracao-3d-acao-%s-%02d.png"%[arma,int(progresso*100)])
			if arma=="arco_curvo":
				for p in [.1,.399,.401,.5,.8,.99]:
					remoto.corpo.pose_acao("arco",int(p*4),direcao,p)
					conferir(is_equal_approx(remoto.corpo.heroi.progresso_arco(),p),"Disparo remoto preserva o relógio da animação")
					await esperar(2)
			remoto.corpo.pose_pesca(3,direcao)
			await esperar(2)
		conferir(remoto.corpo.heroi._vp.get_texture().get_image().get_used_rect().has_area(),"Lobby renderiza ações em quatro direções: "+arma)
		await foto("lobby-"+arma)
	var arquivo := FileAccess.open("user://configuracao_jogador.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"aparencia_raven":dados,"roupas_3d":dados.roupas_3d}))
	arquivo.close()
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await esperar(30)
	conferir(current_scene.personagem.has_node("Previa3D") and not current_scene.sprite_corpo.visible,"Menu inicial substitui o retrato antigo")
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await esperar()
		await foto("inicio-%dx%d"%[tamanho.x,tamanho.y])
	var carregador = root.get_node("Transicao")._carregador
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho*2
		carregador.iniciar("res://cenas/casa.tscn","VILA DAS FLORES")
		carregador.atualizar(.5)
		await esperar(12)
		var avatar: Node2D = carregador._avatar
		var desenho: Rect2 = avatar.global_transform*avatar.retangulo_aparente()
		conferir(avatar.heroi.roupas_3d==dados.roupas_3d,"Carregamento preserva roupas e cabelo salvos")
		conferir(carregador._via.get_global_rect().encloses(desenho),"Personagem dentro da faixa de carregamento "+str(tamanho))
		await foto("carregamento-%dx%d"%[tamanho.x,tamanho.y])
		carregador.hide()
	print("MIGRACAO VISUAL 3D: ",falhas," falhas")
	quit(1 if falhas else 0)
