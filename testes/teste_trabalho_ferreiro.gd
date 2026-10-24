extends SceneTree
var falhas := 0
var Dados: GDScript
var capturar := false
var fotos_prontas := {}

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1

func quadros(n := 5) -> void:
	for i in n:
		await physics_frame
		await process_frame

func foto(nome: String) -> void:
	if not capturar: return
	if fotos_prontas.has(nome): return
	fotos_prontas[nome] = true
	if nome.begins_with("encomenda_"):
		await create_timer(0.25).timeout
	var oficina: Node = current_scene.get_node("Bigorna/TrabalhoFerreiro")
	oficina.set_physics_process(false)
	var ivo: Node2D = current_scene.moradores["ferreiro"]
	if nome == "forja_martelo_erguido": ivo.sprite.frame = 3
	if nome == "forja_impacto": ivo.sprite.frame = 4
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/npcs_base/"+nome+".png")
	oficina.set_physics_process(true)

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	for estacao in 4:
		for hora in [8.0,10.0,12.0,15.0,17.99]:
			verificar("expediente na forja %d / %s" % [estacao,hora],Dados.agenda("ferreiro",hora,estacao,0,0)["local"] == "forja")
	verificar("janta na pousada",Dados.agenda("ferreiro",19.5,0,0,0)["local"] == "pousada")
	verificar("volta para casa antes de dormir",Dados.agenda("ferreiro",21.5,0,0,0)["local"] == "forja")
	verificar("dorme na cama",Dados.agenda("ferreiro",23,0,0,0).get("dormindo",false))
	verificar("quarta de folga",Dados.servico_fechado("ferreiro",12,2) == "FOLGA HOJE" and Dados.agenda("ferreiro",12,0,0,2)["local"] != "forja")
	verificar("festa continua na agenda",Dados.agenda("ferreiro",19,0,0,5).get("festa",false))
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.get_node("Progresso").apagar()
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	var luz: Node = current_scene.get_node("Iluminacao")
	luz.set_process(false)
	luz.definir_hora(12)
	var oficina: Node = current_scene.get_node("Bigorna/TrabalhoFerreiro")
	var ivo: Node2D = current_scene.moradores["ferreiro"]
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(430,140)
	jogador.camera.zoom = Vector2(1.6,1.6)
	jogador.camera.offset = Vector2(0,-45)
	jogador.camera.position_smoothing_enabled = false
	# Interiores usam câmera fixa independente do jogador.
	jogador.camera.global_position = Vector2(420,100)
	jogador.camera.offset = Vector2(0,-20)
	jogador.camera.force_update_scroll()
	if capturar:
		DirAccess.make_dir_recursive_absolute("res://arte/previas/npcs_base")
		for hud in get_nodes_in_group("hud"): hud.visible = false
	var inv: Node = root.get_node("InventarioJogador")
	var prog: Node = root.get_node("Progresso")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar_coletavel("receita","espada_gemea")
	prog.aprender_receita("espada_gemea",inv)
	prog.adicionar_materiais_forja(load("res://codigo/dados/forja_armas.gd").RECEITAS["espada_gemea"],inv)
	verificar("receita do teste pertence ao catalogo ativo",load("res://codigo/dados/forja_armas.gd").receitas_ativas().has("espada_gemea"))
	var combustao: Node = current_scene.get_node("Interior/Fornalha/DetalheAmbiente")
	var fuma: Node = current_scene.get_node("Interior/Fornalha/FumacaChamine")
	verificar("fornalha comeca com brasas fracas",combustao.vigor < 0.15 and not fuma.emitting)
	var antes: Array = inv.fotografar_mochila()
	var ui: Node = current_scene.get_node("Interface")
	ui._abrir_tela("forja")
	await quadros()
	var tela: Control = ui._telas["forja"]
	tela._selecionar("espada_gemea")
	verificar("servico aberto com Ivo presente",not tela._fabricar.disabled)
	ivo.visible = false
	tela._atualizar()
	verificar("sem Ivo na oficina nao fabrica",tela._fabricar.disabled and Dados.atendimento_forja(current_scene,0) == "AGUARDE IVO CHEGAR A OFICINA")
	ivo.visible = true
	tela._ao_fabricar()
	verificar("pedido recebe materiais mas nao entrega antecipadamente",oficina.ocupado() and ivo.ocupado_na_forja and not prog.arma_liberada("espada_gemea") and inv.quantidade_tipo("material:ferro") == 0 and inv.fotografar_mochila() != antes)
	verificar("espada de duas maos tem prazo de dois dias corridos",int(prog.encomenda_forja.get("dia_pronto",0)) == 3)
	verificar("interface libera a visao do trabalho",not tela.visible)
	verificar("segundo jogador nao inicia pedido paralelo",oficina.iniciar("espada_gemea",root.get_node("InventarioJogador2")) == "IVO JA ESTA TRABALHANDO EM UM PEDIDO")
	verificar("tarugo tem volume e contorno",oficina._peca.texture.get_image().get_used_rect().size.y >= 5)
	var etapas := {}
	var quadros_animados := {}
	var limite := Time.get_ticks_msec()+65000
	var numero_foto := 0
	var intervalo_foto := 0
	var pressoes := {}
	var corpo_inteiro := true
	var maior_fogo := 0.0
	var fumaca_ao_soprar := false
	var contorno_fole := true
	var aqueceu_pela_direita := false
	while oficina.ocupado() and Time.get_ticks_msec()<limite:
		await physics_frame
		var etapa: String = oficina.etapa
		maior_fogo = maxf(maior_fogo,combustao.vigor)
		if etapa == "acionando_fole" and fuma.emitting and combustao.impulso > 0.2: fumaca_ao_soprar = true
		if etapa == "indo_fornalha":
			for ponto in ivo.caminho:
				if ponto.x > 370 and ponto.x < 400 and ponto.y < 88: contorno_fole = false
		if not etapas.has(etapa):
			print("ETAPA ",etapa," pos=",ivo.position," caminho=",ivo.caminho)
			etapas[etapa] = true
			await foto("forja_"+etapa)
		if etapa == "acionando_fole":
			pressoes[int(oficina._fole.pressao*10)] = true
			corpo_inteiro = corpo_inteiro and ivo.sprite.material == null and ivo.sprite.hframes == 9 and ivo.sprite.texture.get_height() == 64
			if capturar:
				for alvo in [0.0,0.3,0.6,0.9]:
					if absf(oficina._tempo-alvo) < 0.03: await foto("fole_%s" % alvo)
		if etapa == "aquecendo":
			aqueceu_pela_direita = ivo.position.x > 476 and ivo.sprite.flip_h
			if oficina._tempo > 0.9: await foto("forja_ferro_quente")
		if etapa in ["aquecendo","martelando"]:
			quadros_animados[etapa+str(ivo.sprite.frame)] = true
			if capturar and etapa == "martelando" and numero_foto < 16:
				intervalo_foto += 1
				if intervalo_foto%3 == 0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().get_region(Rect2i(430,60,1100,470)).save_png("res://arte/previas/npcs_base/forja_anim_%02d.png" % numero_foto)
					numero_foto += 1
			if etapa == "martelando" and ivo.sprite.frame == 3:
				await foto("forja_martelo_erguido")
			if etapa == "martelando" and ivo.sprite.frame == 4:
				await foto("forja_impacto")
	verificar("sopradas aumentam o fogo e emitem fumaca",maior_fogo > 0.65 and fumaca_ao_soprar)
	verificar("ferreiro contorna o fole sem cruzar o objeto",contorno_fole)
	verificar("aquecimento ocorre pela direita da fornalha",aqueceu_pela_direita)
	verificar("trabalho termina sem caminho bloqueado",oficina.resultado.is_empty() and not oficina.ocupado())
	if not oficina.resultado.is_empty(): print("MOTIVO: ",oficina.resultado)
	verificar("fole usa poses completas sem recorte do corpo",corpo_inteiro)
	verificar("Ivo aciona o fole antes de aquecer", etapas.has("acionando_fole") and pressoes.size() >= 3)
	verificar("metal passa pela fornalha e pela bigorna",etapas.has("aquecendo") and etapas.has("martelando"))
	verificar("animacoes usam varios quadros",quadros_animados.size() >= 8)
	verificar("animacao nao antecipa o prazo do calendario",not oficina.ocupado() and not prog.arma_liberada("espada_gemea") and inv.buscar_por_tipo("espada_gemea") == null)
	verificar("ciclo visual nao cobra os materiais novamente",inv.quantidade_tipo("material:ferro") == 0 and inv.quantidade_tipo("material:madeira") == 0)
	verificar("restaura corpo e rotina depois do trabalho",not ivo.ocupado_na_forja and ivo.sprite.hframes == 7 and ivo.sprite.vframes == 4)
	ui._abrir_tela("forja")
	await quadros()
	await foto("encomenda_andamento")
	luz.definir_hora(18)
	await create_timer(0.35).timeout
	verificar("fechamento atualiza a tela aberta",tela._fabricar.disabled and tela._situacao.text.contains("FECHOU"))
	verificar("pedido existente impede encomenda paralela mesmo fora da forja",oficina.iniciar("espada_gemea",inv) == "IVO JA ESTA TRABALHANDO EM UM PEDIDO")
	root.get_node("Calendario").dia = 3
	luz.definir_hora(12)
	await create_timer(0.35).timeout
	verificar("folga atualiza a tela aberta",tela._fabricar.disabled and tela._situacao.text.contains("FOLGA HOJE"))
	tela._ao_fabricar()
	verificar("na folga nao retira encomenda pronta",prog.encomenda_forja_pronta() and not prog.arma_liberada("espada_gemea"))
	ui._fechar_tela("forja")
	# Na quinta a encomenda pronta é retirada sem cobrar de novo.
	root.get_node("Calendario").dia = 4
	luz.definir_hora(12)
	root.get_node("Cidade").trajetos_moradores.erase("ferreiro")
	ivo._saindo = false
	ivo.atualizar_rotina(true)
	ui._abrir_tela("forja")
	await quadros()
	tela._atualizar()
	verificar("botao libera retirada apos o prazo",tela._fabricar.text == "RETIRAR ENCOMENDA" and not tela._fabricar.disabled)
	await foto("encomenda_pronta")
	tela._ao_fabricar()
	verificar("retirada libera e entrega sem nova cobranca",prog.encomenda_forja.is_empty() and prog.arma_liberada("espada_gemea") and inv.buscar_por_tipo("espada_gemea") != null and inv.quantidade_tipo("material:ferro") == 0)
	var copias: int = inv.quantidade_tipo("espada_gemea")
	tela._ao_fabricar()
	verificar("repetir retirada nao duplica equipamento",inv.quantidade_tipo("espada_gemea") == copias)
	ui._fechar_tela("forja")
	var inv2: Node = root.get_node("InventarioJogador2")
	inv2.limpar()
	inv2.criar_itens_iniciais()
	inv2.adicionar_coletavel("receita","arco_curto")
	prog.aprender_receita("arco_curto",inv2)
	prog.adicionar_materiais_forja(load("res://codigo/dados/forja_armas.gd").RECEITAS["arco_curto"],inv2)
	var madeira_p1: int = inv.quantidade_tipo("material:madeira")
	verificar("aceita pedido seguinte do segundo jogador",oficina.iniciar("arco_curto",inv2) == "" and int(prog.encomenda_forja.get("jogador",0)) == 2)
	verificar("so cobra a mochila do solicitante",inv2.quantidade_tipo("material:madeira") == 0 and inv.quantidade_tipo("material:madeira") == madeira_p1)
	var dia_pronto: int = prog.encomenda_forja["dia_pronto"]
	luz.definir_hora(18)
	await quadros(3)
	verificar("encerra trabalho visual ao fechar sem cancelar encomenda",not oficina.ocupado() and not ivo.ocupado_na_forja and int(prog.encomenda_forja.get("dia_pronto",0)) == dia_pronto)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(15)
	verificar("sair conserva encomenda sem antecipar entrega",not prog.arma_liberada("arco_curto") and int(prog.encomenda_forja.get("dia_pronto",0)) == dia_pronto)
	prog.carregar()
	verificar("recarregar conserva prazo e materiais entregues",str(prog.encomenda_forja.get("tipo","")) == "arco_curto" and int(prog.encomenda_forja.get("dia_pronto",0)) == dia_pronto and inv2.quantidade_tipo("material:madeira") == 0)
	print("TRABALHO FERREIRO: ",falhas," falhas")
	quit(falhas)
