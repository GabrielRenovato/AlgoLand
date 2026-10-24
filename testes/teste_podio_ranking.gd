extends SceneTree
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Personagem := preload("res://codigo/jogador/personagem_ranking.gd")
const Item := preload("res://codigo/modelos/dados_item.gd")
var falhas := 0
var pasta := "res://arte/previas/cidade/podio_ranking"
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n: await process_frame
func conferir(ok: bool, texto: String) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta.path_join(nome+".png"))
func fixture() -> Array:
	return [
		{"apelido":"CampeaDaVila","andar":93,"arma_mais_usada":"espada_basica","aparencia":{"versao":1,"pele":1,"cabelo":12,"roupa":8,"cor":[0.8,0.5,0.3,1]}},
		{"apelido":"WWWWWWWWWWWWWWWW","andar":81,"arma_mais_usada":"lanca_basica","aparencia":{"versao":1,"pele":0,"cabelo":28,"roupa":3,"cor":[0.3,0.6,1,1]}},
		{"apelido":"TerceiroLugar","andar":73,"arma_mais_usada":"arco_curvo","aparencia":{"versao":1,"pele":2,"cabelo":4,"roupa":5,"cor":[1,0.3,0.4,1],"equipamentos":{"corpo":"peitoral_carrasco","botas":"botas_carrasco"}}}
	]
func conferir_tela(tela: Control, contexto: String) -> void:
	var painel: Rect2 = tela.painel.get_global_rect()
	conferir(Rect2(Vector2.ZERO,tela.size).encloses(painel),contexto+": painel dentro da tela")
	for botao: Button in [tela._fechar,tela._atualizar]:
		conferir(painel.grow(-8).encloses(botao.get_global_rect()),contexto+": botão com margem")
	for caixa in tela._lista.get_children():
		var apelido: Label = caixa.get_child(1)
		var fonte := apelido.get_theme_font("font")
		var largura := fonte.get_string_size(apelido.text,HORIZONTAL_ALIGNMENT_LEFT,-1,apelido.get_theme_font_size("font_size")).x
		conferir(largura <= apelido.size.x,contexto+": nickname completo na consulta")
		conferir(not apelido.get_global_rect().intersects(caixa.get_child(2).get_global_rect()),contexto+": nickname separado do andar")
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode = Window.MODE_WINDOWED
	capturar = "--capturar" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var vila: Node = current_scene
	var jogador: Node2D = vila.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(392,320)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = Vector2(432,280)
	var podio: Node = vila.get_node("PodioRanking")
	conferir(podio.imagem.scale.is_equal_approx(Vector2.ONE/6),"construção compacta de128×48; jogadores mantêm escala nativa")
	for par in [[1,Vector2(444,268)],[2,Vector2(200,300)],[3,Vector2(694,312)]]:
		var numero: Sprite2D = podio.get_node("Lugar%d" % par[0])
		var tinta := numero.texture.get_image().get_used_rect()
		var centro := Vector2((par[1].x-10)*768.0/868.0/6.0-64,(par[1].y-64)*288.0/326.0/6.0-48)
		conferir(numero.position.distance_to(centro)<0.6 and numero.centered,"número %d no centro do medalhão" % par[0])
		conferir(Vector2(tinta.position).is_equal_approx(Vector2.ZERO) and tinta.size==Vector2i(numero.texture.get_size()),"número %d centralizado pelo contorno visível" % par[0])
	conferir(Visual.normalizar({}).is_empty(),"registro antigo não inventa aparência")
	var malicioso := Visual.normalizar({"versao":1,"pele":{},"cabelo":"res://invalido","roupa":1e100,"equipamentos":{"cabeca":"res://secreto","corpo":"elmo_carrasco"},"cor":[{},2,-1,0]})
	conferir(malicioso.cabelo==0 and malicioso.equipamentos.is_empty() and is_equal_approx(malicioso.cor[0],1) and is_equal_approx(malicioso.cor[1],1) and is_equal_approx(malicioso.cor[2],0) and is_equal_approx(malicioso.cor[3],1),"dados remotos inválidos são limitados a ids e cores válidos")
	# Compara com o compositor real, incluindo peças básicas, mistas e prévia cosmética.
	for configuracao in [{},{"cabeca":"elmo_carrasco","corpo":"peitoral_carrasco"},{"cabeca":"cabeca_basica","luvas":"luvas_basicas","botas":"botas_basicas"},{"corpo":"peitoral_carrasco","luvas":"luvas_carrasco","botas":"botas_carrasco"},{"cosmetico":43}]:
		jogador.aparencia_raven = {"pele":1,"cabelo":28,"roupa":8,"cor":[0.3,0.6,1,1]}
		jogador.roupa_atual = int(configuracao.get("cosmetico",0))
		for slot in Visual.BASICOS: jogador.inventario.equipados[slot] = null
		for slot: String in configuracao:
			if slot=="cosmetico": continue
			var item := Item.new()
			item.tipo = configuracao[slot]
			item.categoria = slot
			jogador.inventario.equipados[slot] = item
		await quadros(2)
		var real: Sprite2D = jogador.get_node("HeroiRaven").criar_previa()
		var remoto := Personagem.new()
		remoto.dados = Visual.do_jogador(jogador)
		vila.add_child(remoto)
		var iguais := remoto.texture == real.texture
		for i in 15:
			var copia: Sprite2D = remoto._camadas[i]
			var original: Sprite2D = real.get_node("Camada%d" % i)
			iguais = iguais and copia.texture == original.texture and copia.material == original.material and copia.modulate == original.modulate
		conferir(iguais,"corpo, roupa, cabelo e peças iguais ao jogador: "+str(configuracao))
		real.free()
		remoto.queue_free()
	# Cada id reutiliza a mesma pose Raven e mantém arma visível na mão.
	var indice_arma := 0
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1536,864)
	var cartela := CanvasLayer.new()
	cartela.layer = 100
	root.add_child(cartela)
	var fundo := ColorRect.new()
	fundo.color = Color("293444")
	fundo.size = Vector2(576,324)
	cartela.add_child(fundo)
	var amostras := Node2D.new()
	amostras.position = Vector2(128,100)
	cartela.add_child(amostras)
	for arma: String in preload("res://codigo/dados/armas_ranking.gd").ARMAS:
		var remoto := Personagem.new()
		remoto.dados = Visual.normalizar({"versao":1,"cabelo":12,"roupa":8,"arma_mais_usada":arma})
		remoto.position = Vector2((indice_arma%4)*104,(indice_arma/4)*116)
		amostras.add_child(remoto)
		var etiqueta := Label.new()
		etiqueta.text = arma.replace("_","\n")
		etiqueta.add_theme_font_size_override("font_size",7)
		etiqueta.position = remoto.position+Vector2(-44,12)
		etiqueta.size.x = 88
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amostras.add_child(etiqueta)
		conferir(remoto._pose_ranking!="parado" and remoto._camadas[5].texture.get_image().get_region(Rect2i(0,0,80,80)).get_used_rect().has_area(),"pose de guarda com arma: "+arma)
		indice_arma += 1
	await quadros()
	await foto("armas")
	cartela.queue_free()
	var linhas := fixture()
	root.get_node("Ranking").lista_cache = linhas
	podio._atualizar_lista(linhas)
	await quadros()
	conferir(podio.ocupantes.get_child_count()==3,"três colocados em2/1/3")
	var nomes: Array[Rect2] = []
	for ator in podio.ocupantes.get_children():
		var nome: Label = ator.get_node("Nickname")
		var personagem: Node = ator.get_node("Personagem")
		conferir(personagem.scale==Vector2.ONE,"personagem na escala do jogador")
		conferir(nome.position.y+nome.size.y<=personagem.topo_aparente()-4,"nome acima do cabelo/armadura")
		conferir(nome.get_line_count()==nome.get_visible_line_count(),"nickname longo aparece inteiro")
		var retangulo := Rect2(ator.position+nome.position,nome.size)
		conferir(not nomes.any(func(outro: Rect2) -> bool: return outro.intersects(retangulo)),"nicknames sem sobreposição")
		nomes.append(retangulo)
	var demonstracao := linhas.duplicate(true)
	demonstracao[1].apelido = "Explorador"
	podio._atualizar_lista(demonstracao)
	await quadros()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1536,864)
	var luz: Node = vila.get_node("Iluminacao")
	luz.set_process(false)
	luz.definir_hora(12.0)
	for estacao in 4:
		root.get_node("Calendario").dia = 1+estacao*30
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
		vila._ao_estacao(estacao)
		podio._atualizar_estacao()
		await quadros(20)
		conferir(podio._estacao==estacao,"monumento integrado à estação %d" % estacao)
		await foto("estacao_%d" % estacao)
	for quadro in 4:
		for ator in podio.ocupantes.get_children():
			var personagem: Node = ator.get_node("Personagem")
			personagem.set_process(false)
			personagem._tempo = quadro*0.2
			personagem._process(0)
		await quadros(2)
		await foto("repouso_%d" % quadro)
	for i in range(3,15):
		linhas.append({"apelido":"AVENTUREIRO_%02d" % i,"andar":70-i,"aparencia":{}})
	root.get_node("Ranking").lista_cache = linhas
	var interface: Node = vila.get_node("Interface")
	var tela: Control = interface._telas.ranking
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(288,216),Vector2i(320,324)]:
		root.get_node("Controle").usando_toque = tamanho.x<=288
		root.content_scale_size = tamanho
		root.size = tamanho*2
		interface._abrir_tela("ranking")
		await quadros(12)
		conferir_tela(tela,str(tamanho))
		await foto("consulta_%dx%d" % [tamanho.x,tamanho.y])
		interface._fechar_tela("ranking")
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(640,324)
	root.size = Vector2i(1280,648)
	root.get_node("Cooperativo").entrar(1)
	await quadros(25)
	var p2: Node = root.get_node("Cooperativo").jogador2()
	conferir(p2!=null,"segundo jogador criado")
	if p2 != null:
		var ui2: Node = root.get_node("Cooperativo").interface_p2()
		ui2._abrir_tela("ranking")
		await quadros(12)
		conferir(ui2._telas.ranking.visible and not root.get_node("EventosJogo").interface_p1()._telas.ranking.visible,"consulta abre só na metade de quem interagiu")
		conferir_tela(ui2._telas.ranking,"cooperativo")
		await foto("consulta_coop")
		ui2._fechar_tela("ranking")
	root.get_node("Cooperativo").sair()
	# Nenhum participante ou visual fictício é enviado ao banco.
	podio._atualizar_lista(linhas.slice(0,1))
	conferir(podio.ocupantes.get_child_count()==1,"ranking parcial não duplica jogadores")
	podio._atualizar_lista([])
	conferir(podio.ocupantes.get_child_count()==0,"ranking vazio mantém lugares desocupados")
	await quadros(5)
	jogador = root.get_node("Cooperativo")._jogador1()
	root.get_node("Ranking").capturar_jogador(jogador)
	var antes: Dictionary = root.get_node("Ranking").visual_pendente.duplicate(true)
	root.get_node("Progresso").partida_ativa = true
	root.get_node("Progresso").encerrar_partida()
	conferir(root.get_node("Ranking").visual_pendente==antes,"encerramento captura o visual antes do reset de equipamento")
	current_scene = null
	vila.queue_free()
	await quadros()
	print("PODIO: ",falhas," falhas")
	quit(1 if falhas else 0)
