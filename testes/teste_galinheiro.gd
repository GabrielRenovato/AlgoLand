extends SceneTree

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
var falhas := 0
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await quadros(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-galinheiro-"+nome+".png")
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	var fazenda = root.get_node("Fazenda")
	var inv = root.get_node("InventarioJogador")
	var calendario = root.get_node("Calendario")
	fazenda.apagar()
	inv.limpar()
	inv.criar_itens_iniciais()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(35)
	var jogador = current_scene.get_node("Jogador")
	verificar("save novo conserva fazenda sem construção",fazenda.galinheiro == Criacao.inicial())
	verificar("obra exige materiais reais",Criacao.executar(fazenda,jogador,"construir") != "")
	for material in ["madeira","pedra","ferro","fibra"]: inv.adicionar_coletavel("material",material,10000)
	verificar("encomenda leva quatro dias e consome materiais",Criacao.executar(fazenda,jogador,"construir") == "" and inv.quantidade_tipo("material:madeira") == 10000-Criacao.CUSTOS[1].madeira)
	verificar("obra não cobra duas vezes",Criacao.executar(fazenda,jogador,"construir") != "" and inv.quantidade_tipo("material:madeira") == 10000-Criacao.CUSTOS[1].madeira)
	calendario.dia += 1
	fazenda.avancar_dia(0)
	verificar("obra continua após a primeira noite",fazenda.galinheiro.nivel == 0 and fazenda.galinheiro.obra == 1)
	for noite in range(1,Criacao.PRAZOS[1]):
		calendario.dia += 1
		fazenda.avancar_dia(0)
	verificar("abrigo entrega duas galinhas e um galo sem feno automático",fazenda.galinheiro.aves.size() == 3 and Criacao.tem_galo(fazenda.galinheiro,calendario.dia) and fazenda.galinheiro.racao == 0)
	verificar("preparar feno produz item e não enche comedouro",Criacao.executar(fazenda,jogador,"preparar_feno") == "" and inv.quantidade_tipo("produto:feno") == 14 and fazenda.galinheiro.racao == 0)
	verificar("feno é selecionável na barra",fazenda.ferramentas().has("produto:feno"))
	for i in 6: Criacao.executar(fazenda,jogador,"lancar_feno")
	verificar("jogar feno transfere porções da mochila",fazenda.galinheiro.racao == 6 and inv.quantidade_tipo("produto:feno") == 8)
	calendario.dia += 1
	fazenda.avancar_dia(0)
	verificar("galo come mas não bota ovos",Criacao.total_ovos(fazenda) == 2 and fazenda.galinheiro.racao == 3 and fazenda.galinheiro.aves[2].ovos == 0)
	var galo: Dictionary = fazenda.galinheiro.aves.pop_back()
	verificar("sem galo não se pode incubar",Criacao.executar(fazenda,jogador,"incubar") != "")
	fazenda.galinheiro.aves.append(galo)
	verificar("galo adulto permite incubar um ovo",Criacao.executar(fazenda,jogador,"incubar") == "" and fazenda.galinheiro.incubacao == calendario.dia+3 and Criacao.total_ovos(fazenda) == 1)
	verificar("vaga do pintinho fica reservada",Criacao.executar(fazenda,jogador,"comprar") != "")
	for i in 3:
		calendario.dia += 1
		fazenda.avancar_dia(0)
	verificar("pintinho nasce em três dias e não bota ovos",fazenda.galinheiro.aves.size() == 4 and not Criacao.adulta(fazenda.galinheiro.aves[3],calendario.dia) and fazenda.galinheiro.aves[3].ovos == 0)
	var antes: Dictionary = fazenda.galinheiro.duplicate(true)
	fazenda.salvar(); fazenda.carregar()
	verificar("save conserva sexo, idade, incubação e feno",fazenda.galinheiro == antes)
	verificar("carinho usa limite diário e preserva vínculo",Criacao.executar(fazenda,jogador,"carinho",0) == "" and Criacao.executar(fazenda,jogador,"carinho",0) != "")
	var bando = fazenda.bando
	bando.set_process(false)
	bando.reiniciar()
	bando.avancar(0,8,0)
	var max_na_porta := 0
	for i in 1800:
		bando.avancar(1.0/60,8,0)
		var na_porta := 0
		for a in bando.aves:
			if a.estado in ["saindo","entrando"]: na_porta += 1
		max_na_porta = maxi(max_na_porta,na_porta)
	verificar("aves saem em fila, uma por vez",max_na_porta == 1 and bando.aves.all(func(a): return a.estado == "fora"))
	var atividades := {}
	for i in 600:
		bando.avancar(1.0/60,8,0)
		for a in bando.aves: atividades[a.atividade] = true
	verificar("rotina alterna caminhada e bicadas/repouso",atividades.has("caminhar") and (atividades.has("bicar") or atividades.has("descansar")))
	Criacao.executar(fazenda,jogador,"portinha")
	verificar("porta aguarda retorno das aves",bando.portinha_aberta())
	for i in 9000: bando.avancar(1.0/60,18,2)
	verificar("chuva/noite recolhem e fecham o bando sem prender fora",bando.aves.all(func(a): return a.estado == "dentro") and not bando.portinha_aberta())
	jogador.global_position = Vector2(240,180)
	jogador.camera.zoom = Vector2.ONE
	for nivel in [1,2,3]:
		if nivel > 1:
			inv.limpar()
			var incompleto: Dictionary = Criacao.CUSTOS[nivel].duplicate()
			incompleto.fibra -= 1
			inv.receber_materiais(incompleto)
			var mochila_antes: Array = inv.fotografar_mochila()
			verificar("ampliação %d sem material não cobra parcialmente" % nivel,Criacao.executar(fazenda,jogador,"construir") != "" and inv.fotografar_mochila()==mochila_antes and fazenda.galinheiro.obra==0)
			inv.adicionar_coletavel("material","fibra",1)
			verificar("ampliação %d cabe na mochila e inicia" % nivel,Criacao.executar(fazenda,jogador,"construir") == "")
			for material in Criacao.CUSTOS[nivel]:
				verificar("ampliação %d cobra quantidade exata de %s" % [nivel,material],inv.quantidade_tipo("material:"+material)==0)
			verificar("ampliação %d usa prazo correto e não cobra de novo" % nivel,fazenda.galinheiro.pronto_dia==calendario.dia+Criacao.PRAZOS[nivel] and Criacao.executar(fazenda,jogador,"construir")!="")
			for dia in Criacao.PRAZOS[nivel]:
				calendario.dia += 1
				fazenda.avancar_dia(0)
		for estacao in 4:
			current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
			await verificar_cobertura_externa(nivel,estacao,current_scene.get_node("Galinheiro"))
			await foto("nivel-%d-estacao-%d" % [nivel,estacao])
	inv.adicionar_coletavel("produto","feno",20)
	bando.avancar(0,6,0)
	bando.set_process(true)
	change_scene_to_file("res://cenas/galinheiro.tscn")
	await quadros(35)
	jogador = current_scene.get_node("Jogador")
	verificar("menu do galinheiro foi removido",not current_scene.get_node("Interface")._telas.has("galinheiro"))
	for nivel in [1,2,3]:
		fazenda.galinheiro.nivel = nivel
		fazenda.galinheiro_alterado.emit()
		await quadros()
		var origem := Vector2(current_scene.largura/2,current_scene.altura-48)
		jogador.position = origem
		var colisao = jogador.move_and_collide(Vector2(0,200))
		verificar("entrada bloqueia sair ao fundo preto no nível %d" % nivel,colisao != null and jogador.position.y < current_scene.altura)
		verificar("comedouro bloqueia corpo sem prender acesso no nível %d" % nivel,jogador.test_move(Transform2D(0,Vector2(62,70)),Vector2(0,-40)) and not jogador.test_move(Transform2D(0,origem),Vector2(62,70)-origem))
		verificar("depósito tem colisão na base no nível %d" % nivel,jogador.test_move(Transform2D(0,Vector2(current_scene.largura-32,90)),Vector2(0,-40)))
		jogador.position = Vector2(62,70)
		fazenda.galinheiro.racao = 0
		fazenda.galinheiro_alterado.emit()
		await quadros()
		verificar("comedouro inicia vazio",not current_scene._feno.visible)
		var qtd: int = inv.quantidade_tipo("produto:feno")
		jogador.set_meta("item_uso","produto:feno")
		verificar("clique com feno selecionado é tratado como arremesso",load("res://codigo/fazenda/acao_galinheiro.gd").tentar_usar_feno(jogador))
		await create_timer(0.5).timeout
		verificar("arremesso coloca feno físico no comedouro",fazenda.galinheiro.racao == 1 and inv.quantidade_tipo("produto:feno") == qtd-1 and current_scene._feno.visible)
		jogador.position = Vector2(current_scene.largura-28,current_scene.altura-40)
		current_scene.jogar_feno(jogador)
		verificar("fora do comedouro não gasta feno",inv.quantidade_tipo("produto:feno") == qtd-1)
		jogador.set_meta("item_uso","")
		jogador.position = Vector2(62,70)
		await foto("cuidados-diretos-%d" % nivel)
	var ave = current_scene.get_node("Interior/Galinha0")
	ave.position = jogador.position+Vector2(22,8)
	ave.set_physics_process(false)
	fazenda.galinheiro.aves[0].carinho_dia = -1
	ave.acariciar(jogador)
	verificar("carinho reutiliza ícone real do HUD",ave._coracao.texture.resource_path.ends_with("/4 Bars/13.png"))
	await foto("carinho")
	jogador.position = Vector2(current_scene.largura-34,81)
	await quadros()
	var deposito = current_scene.get_node("Interior/DepositoFeno")
	verificar("depósito descreve o cuidado no cenário",deposito._descricao.visible and deposito._descricao.text.contains("2 FIBRAS"))
	await foto("deposito-feno")
	var criacao_antes_compra: Dictionary = fazenda.galinheiro.duplicate(true)
	# Compra cara respeita saldo insuficiente, débito exato e capacidade; incubar continua alternativa.
	fazenda.galinheiro = Criacao.inicial()
	fazenda.galinheiro.nivel = 1
	var progresso = root.get_node("Progresso")
	progresso.brasas = Criacao.PRECO_GALINHA-1
	verificar("ave exige o preço completo sem consumir saldo",Criacao.executar(fazenda,jogador,"comprar")!="" and progresso.brasas==Criacao.PRECO_GALINHA-1 and fazenda.galinheiro.aves.is_empty())
	for acao in ["comprar","comprar_galo"]:
		progresso.brasas = Criacao.PRECO_GALINHA
		var quantidade: int = fazenda.galinheiro.aves.size()
		verificar("compra %s cobra preço exato" % acao,Criacao.executar(fazenda,jogador,acao)=="" and progresso.brasas==0 and fazenda.galinheiro.aves.size()==quantidade+1)
	verificar("compra distingue galinha e galo",fazenda.galinheiro.aves[0].sexo=="galinha" and fazenda.galinheiro.aves[1].sexo=="galo")
	fazenda.galinheiro = criacao_antes_compra
	await testar_familia()
	await testar_cooperativo()
	print("FALHAS: ",falhas)
	quit(falhas)

func testar_cooperativo() -> void:
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	var fazenda = root.get_node("Fazenda")
	fazenda.galinheiro = Criacao.inicial()
	fazenda.galinheiro.nivel = 1
	fazenda.galinheiro.aves = [Criacao.nova_ave(0),Criacao.nova_ave(1),Criacao.nova_ave(2,"galo")]
	for nome in ["InventarioJogador","InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
		root.get_node(nome).adicionar_coletavel("produto","feno",5)
	root.get_node("Transicao").hora_salva = 6
	change_scene_to_file("res://cenas/galinheiro.tscn")
	await quadros(40)
	var coop = root.get_node("Cooperativo")
	var p2 = coop.jogador2()
	var p1 = coop._jogador1()
	verificar("galinheiro recebe os dois jogadores e barra de ferramentas",p2 != null and p1.modo_fazenda and p2.modo_fazenda)
	var hud = get_first_node_in_group("hud_p2")
	var barra = hud.barra_armas
	var celula := -1
	for i in p2.inventario.capacidade():
		var item = p2.inventario.item_na_celula(i)
		if item != null and item.tipo == "produto:feno": celula = i; break
	barra._fileira = celula/8
	barra._atualizar()
	verificar("P2 seleciona feno pela barra real",celula >= 0 and barra.escolher(celula%8))
	p1.position = Vector2(45,86)
	p2.position = Vector2(62,70)
	p2._pedido_ataque = true
	p2.logica_combo_ataque()
	await create_timer(0.5).timeout
	verificar("ataque de P2 joga somente o feno da própria mochila",p2.inventario.quantidade_tipo("produto:feno") == 4 and p1.inventario.quantidade_tipo("produto:feno") == 5 and fazenda.galinheiro.racao == 1)
	await foto("cuidados-coop")
	coop.viajar_local(p2,"res://cenas/cidade/carpintaria.tscn","entrada")
	await quadros(40)
	verificar("P2 visita oficina e P1 permanece com as aves",coop.cena_de(p2).scene_file_path.ends_with("carpintaria.tscn") and coop.cena_de(p1).scene_file_path.ends_with("galinheiro.tscn"))
	var hud2 = get_first_node_in_group("hud_p2")
	hud2.barra_armas.escolher(0)
	verificar("feno selecionado na fazenda não bloqueia arma em outro mapa",not load("res://codigo/fazenda/acao_galinheiro.gd").tentar_usar_feno(p2))

func testar_familia() -> void:
	var transicao = root.get_node("Transicao")
	transicao.hora_salva = 9
	change_scene_to_file("res://cenas/cidade/carpintaria.tscn")
	await quadros(40)
	var dados = load("res://codigo/cidade/dados_cidade.gd")
	var familia = load("res://codigo/cidade/familia_carpinteiro.gd")
	for id in ["osvaldo","helena","clara"]:
		var npc = current_scene.moradores[id]
		verificar("familiar presente na oficina às 9h: "+id,npc.visible and not npc.sprite.texture.get_image().is_empty())
		verificar("animação e quatro direções de "+id,npc.sprite.hframes == 7 and npc.sprite.vframes == 4)
	verificar("idades e ELA preservadas",dados.MORADORES.osvaldo.idade == 65 and dados.MORADORES.helena.idade == 55 and dados.MORADORES.clara.idade == 30 and dados.MORADORES.helena.condicao == "ELA")
	verificar("Helena usa cadeira sem animação de ficar em pé",dados.MORADORES.helena.cadeira_de_rodas and not current_scene.moradores.helena.dormindo)
	verificar("filha acompanha passeio da mãe",familia.agenda("helena",10,0,0).local == "cidade" and familia.agenda("clara",10,0,0).local == "cidade")
	verificar("família procura abrigo na chuva",familia.agenda("helena",10,0,2).local == "carpintaria")
	var helena = current_scene.moradores.helena
	var caminho: PackedVector2Array = current_scene.caminho_morador(helena.position,Vector2(264,510),"helena")
	verificar("circulação acessível entre cadeira e entrada",caminho.size() > 1)
	var livre := true
	var mascara: int = helena.collision_mask
	helena.collision_mask = 64
	var anterior: Vector2 = helena.position
	for ponto in caminho:
		if helena.test_move(Transform2D(0,anterior),ponto-anterior): livre = false
		anterior = ponto
	helena.collision_mask = mascara
	verificar("rota comporta colisão real da cadeira de rodas",livre)
	await foto("familia-oficina")
	var jogador = current_scene.get_node("Jogador")
	jogador.position = current_scene.moradores.osvaldo.position+Vector2(0,28)
	current_scene.get_node("Interior/Atendimento").abrir_tela()
	await quadros()
	var interface = current_scene.get_node("Interface")
	verificar("bancada oferece construção",interface._telas_abertas.has("carpintaria") and interface._telas.carpintaria._botoes.has("galinheiro_1"))
	interface._fechar_tela("carpintaria")
	root.get_node("Cidade").atender("osvaldo","carpintaria",jogador)
	await quadros()
	var tela = interface._telas.conversa_cidade
	await foto("carpinteiro-dialogo")
	verificar("diálogo de construção continua compacto",tela.painel.size.y <= 156)
	validar_respostas(tela,"computador")
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros()
	verificar("diálogo do carpinteiro cabe no celular",Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()))
	validar_respostas(tela,"celular")
	await foto("carpinteiro-mobile")
	tela._descer_respostas.pressed.emit()
	await quadros()
	validar_respostas(tela,"celular após rolar")
	tela._fechar()
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(35)
	verificar("casa da família tem entrada exterior própria",current_scene.has_node("Porta_carpintaria"))
	jogador = current_scene.get_node("Jogador")
	jogador.position = current_scene.get_node("Chegada_carpintaria").position
	await quadros()
	await foto("casa-carpinteiro")
	current_scene.get_node("Porta_carpintaria")._atravessar(jogador)
	await create_timer(1.0).timeout
	verificar("porta exterior leva à casa e oficina",current_scene.scene_file_path.ends_with("carpintaria.tscn"))

func validar_respostas(tela: Control, nome: String) -> void:
	var area: Rect2 = tela._rolagem.get_global_rect().grow(0.5)
	var completas := true
	for botao in tela._botoes:
		var retangulo: Rect2 = botao.get_global_rect()
		if area.intersects(retangulo) and not area.encloses(retangulo): completas = false
	verificar("respostas visíveis preservam texto e molduras: "+nome,completas)
# Regressão por pixels: cobre o vão medido sem pintar a moldura nem a rampa.
func verificar_cobertura_externa(modelo: int, estacao: int, fonte: Node) -> void:
	if DisplayServer.get_name() == "headless": return
	var vaos_medidos := [Rect2i(133,117,10,11),Rect2i(133,117,10,11),Rect2i(134,116,10,11)]
	var vao: Rect2i = vaos_medidos[modelo-1]
	var vista := SubViewport.new()
	vista.size = Vector2i(224,160)
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var suporte := Node2D.new()
	suporte.position = Vector2(112,144)
	vista.add_child(suporte)
	suporte.add_child(fonte.imagem.duplicate())
	var prova = load("res://codigo/fazenda/portinha_galinhas.gd").new()
	prova.position = fonte.portinha.position
	suporte.add_child(prova)
	prova.usar_folha_externa()
	prova.set_process(false)
	prova.visible = false
	for quadro in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	var base := vista.get_texture().get_image()
	prova.visible = true
	prova._abertura = 0.0
	prova._folha.visible = true
	prova._folha.abertura = 0.0
	prova._folha.modulate = Color.BLACK
	prova._folha.queue_redraw()
	prova.queue_redraw()
	for quadro in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	var fechada := vista.get_texture().get_image()
	var frestas := 0
	var invasoes := 0
	for y in 160:
		for x in 224:
			var pixel := fechada.get_pixel(x,y)
			if vao.has_point(Vector2i(x,y)):
				if pixel.r > 0.001 or pixel.g > 0.001 or pixel.b > 0.001: frestas += 1
			elif pixel != base.get_pixel(x,y): invasoes += 1
	verificar("tampa externa %d/%d cobre todo o vão: %d frestas, %d invasões" % [modelo,estacao,frestas,invasoes],frestas == 0 and invasoes == 0)
	if frestas > 0 or invasoes > 0: fechada.save_png("/tmp/algoland-fresta-%d-%d.png" % [modelo,estacao])
	vista.queue_free()
	await process_frame
